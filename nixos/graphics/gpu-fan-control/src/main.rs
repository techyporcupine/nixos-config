use std::env;
use std::fs;
use std::io::{self, ErrorKind};
use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;

#[derive(Debug, Clone)]
struct Config {
    temp_chip: Option<String>,
    temp_pci: Option<String>,
    temp_label: Option<String>,
    temp_sensor: Option<String>,
    temp_path: Option<PathBuf>,

    pwm_chip: Option<String>,
    pwm_channel: Option<u32>,
    pwm_path: Option<PathBuf>,
    pwm_enable_path: Option<PathBuf>,

    min_temp: f32,
    max_temp: f32,
    min_pwm: i32,
    max_pwm: i32,
    interval: u64,
    hysteresis_pwm: i32,
}

impl Config {
    fn load_from_file<P: AsRef<Path>>(path: P) -> Result<Self, io::Error> {
        let content = fs::read_to_string(path)?;
        let mut temp_chip = None;
        let mut temp_pci = None;
        let mut temp_label = None;
        let mut temp_sensor = None;
        let mut temp_path = None;

        let mut pwm_chip = None;
        let mut pwm_channel = None;
        let mut pwm_path = None;
        let mut pwm_enable_path = None;

        let mut min_temp = None;
        let mut max_temp = None;
        let mut min_pwm = None;
        let mut max_pwm = None;
        let mut interval = None;
        let mut hysteresis_pwm = None;

        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            let parts: Vec<&str> = trimmed.splitn(2, '=').collect();
            if parts.len() != 2 {
                continue;
            }

            let key = parts[0].trim();
            let value = parts[1].trim().trim_matches('"').trim_matches('\'');

            match key {
                "temp_chip" => temp_chip = Some(value.to_string()),
                "temp_pci" => temp_pci = Some(value.to_string()),
                "temp_label" => temp_label = Some(value.to_string()),
                "temp_sensor" => temp_sensor = Some(value.to_string()),
                "temp_path" => temp_path = Some(PathBuf::from(value)),

                "pwm_chip" => pwm_chip = Some(value.to_string()),
                "pwm_channel" => pwm_channel = value.parse::<u32>().ok(),
                "pwm_path" => pwm_path = Some(PathBuf::from(value)),
                "pwm_enable_path" => pwm_enable_path = Some(PathBuf::from(value)),

                "min_temp" => min_temp = value.parse::<f32>().ok(),
                "max_temp" => max_temp = value.parse::<f32>().ok(),
                "min_pwm" => min_pwm = value.parse::<i32>().ok(),
                "max_pwm" => max_pwm = value.parse::<i32>().ok(),
                "interval" => interval = value.parse::<u64>().ok(),
                "hysteresis_pwm" => hysteresis_pwm = value.parse::<i32>().ok(),
                _ => {}
            }
        }

        let min_temp = min_temp.unwrap_or(45.0);
        let max_temp = max_temp.unwrap_or(105.0);
        let min_pwm = min_pwm.unwrap_or(80).clamp(0, 255);
        let max_pwm = max_pwm.unwrap_or(255).clamp(0, 255);
        let interval = interval.unwrap_or(3).max(1);
        let hysteresis_pwm = hysteresis_pwm.unwrap_or(2).max(0);

        if min_temp >= max_temp {
            return Err(io::Error::new(
                ErrorKind::InvalidData,
                "min_temp must be less than max_temp",
            ));
        }
        if min_pwm > max_pwm {
            return Err(io::Error::new(
                ErrorKind::InvalidData,
                "min_pwm cannot exceed max_pwm",
            ));
        }

        if temp_chip.is_none() && temp_pci.is_none() && temp_path.is_none() {
            return Err(io::Error::new(
                ErrorKind::InvalidData,
                "Must configure at least one of temp_chip, temp_pci, or temp_path",
            ));
        }
        if pwm_chip.is_none() && pwm_path.is_none() {
            return Err(io::Error::new(
                ErrorKind::InvalidData,
                "Must configure at least one of pwm_chip (with pwm_channel) or pwm_path",
            ));
        }

        Ok(Config {
            temp_chip,
            temp_pci,
            temp_label,
            temp_sensor,
            temp_path,
            pwm_chip,
            pwm_channel,
            pwm_path,
            pwm_enable_path,
            min_temp,
            max_temp,
            min_pwm,
            max_pwm,
            interval,
            hysteresis_pwm,
        })
    }
}

#[derive(Debug, Clone)]
struct ResolvedPaths {
    temp_input: PathBuf,
    pwm: PathBuf,
    pwm_enable: PathBuf,
}

fn find_hwmon_by_pci(pci_addr: &str) -> Option<PathBuf> {
    let base = Path::new("/sys/bus/pci/devices").join(pci_addr).join("hwmon");
    if let Ok(entries) = fs::read_dir(&base) {
        let mut dirs: Vec<PathBuf> = entries
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.is_dir())
            .collect();
        dirs.sort();
        return dirs.into_iter().next();
    }
    None
}

fn find_hwmon_by_name(chip_pattern: &str) -> Option<PathBuf> {
    let hwmon_base = Path::new("/sys/class/hwmon");
    let entries = fs::read_dir(hwmon_base).ok()?;
    let mut matching_dirs = Vec::new();

    for entry in entries.flatten() {
        let path = entry.path();
        let name_file = path.join("name");
        if let Ok(name_content) = fs::read_to_string(name_file) {
            let name = name_content.trim();
            if name.eq_ignore_ascii_case(chip_pattern)
                || name
                    .to_ascii_lowercase()
                    .starts_with(&chip_pattern.to_ascii_lowercase())
                || name
                    .to_ascii_lowercase()
                    .contains(&chip_pattern.to_ascii_lowercase())
            {
                matching_dirs.push(path);
            }
        }
    }

    matching_dirs.sort();
    matching_dirs.into_iter().next()
}

fn find_temp_input(
    hwmon_dir: &Path,
    label: Option<&str>,
    sensor: Option<&str>,
) -> Option<PathBuf> {
    if let Some(s) = sensor {
        let p = hwmon_dir.join(s);
        if p.exists() {
            return Some(p);
        }
    }

    if let Some(lbl) = label {
        for i in 1..=16 {
            let label_file = hwmon_dir.join(format!("temp{}_label", i));
            if let Ok(content) = fs::read_to_string(label_file) {
                if content.trim().eq_ignore_ascii_case(lbl) {
                    let input_file = hwmon_dir.join(format!("temp{}_input", i));
                    if input_file.exists() {
                        return Some(input_file);
                    }
                }
            }
        }
    }

    for fallback in &["temp2_input", "temp1_input", "temp3_input"] {
        let p = hwmon_dir.join(fallback);
        if p.exists() {
            return Some(p);
        }
    }

    None
}

fn resolve_paths(config: &Config) -> Result<ResolvedPaths, String> {
    // 1. Resolve Temperature Input Path
    let temp_hwmon = if let Some(ref pci) = config.temp_pci {
        find_hwmon_by_pci(pci)
            .ok_or_else(|| format!("Could not find hwmon for PCI device {}", pci))?
    } else if let Some(ref chip) = config.temp_chip {
        find_hwmon_by_name(chip)
            .ok_or_else(|| format!("Could not find hwmon for temperature chip {}", chip))?
    } else if let Some(ref path) = config.temp_path {
        if path.exists() {
            path.parent()
                .map(|p| p.to_path_buf())
                .unwrap_or_else(|| PathBuf::from("/sys/class/hwmon"))
        } else {
            // Path does not exist (likely hwmon renumbering), try finding amdgpu or similar
            find_hwmon_by_name("amdgpu")
                .or_else(|| find_hwmon_by_name("k10temp"))
                .or_else(|| find_hwmon_by_name("coretemp"))
                .ok_or_else(|| format!("Configured temp_path '{}' does not exist and auto-discovery failed", path.display()))?
        }
    } else {
        return Err("No temperature sensor specification provided".to_string());
    };

    let temp_input = find_temp_input(
        &temp_hwmon,
        config.temp_label.as_deref(),
        config.temp_sensor.as_deref(),
    )
    .or_else(|| {
        if let Some(ref path) = config.temp_path {
            if path.exists() {
                return Some(path.clone());
            }
            if let Some(file_name) = path.file_name() {
                let candidate = temp_hwmon.join(file_name);
                if candidate.exists() {
                    return Some(candidate);
                }
            }
        }
        None
    })
    .ok_or_else(|| {
        format!(
            "Could not locate temperature input file under hwmon directory {}",
            temp_hwmon.display()
        )
    })?;

    // 2. Resolve PWM Output Paths
    let (pwm, pwm_enable) = if let Some(ref chip) = config.pwm_chip {
        let channel = config.pwm_channel.unwrap_or(1);
        let pwm_hwmon = find_hwmon_by_name(chip)
            .ok_or_else(|| format!("Could not find hwmon for PWM chip {}", chip))?;
        (
            pwm_hwmon.join(format!("pwm{}", channel)),
            pwm_hwmon.join(format!("pwm{}_enable", channel)),
        )
    } else if let (Some(ref p_path), Some(ref pe_path)) =
        (&config.pwm_path, &config.pwm_enable_path)
    {
        if p_path.exists() && pe_path.exists() {
            (p_path.clone(), pe_path.clone())
        } else {
            // Attempt auto-discovery with common superio chip names like nct6791/nct6775
            let pwm_hwmon = find_hwmon_by_name("nct")
                .or_else(|| find_hwmon_by_name("it87"))
                .ok_or_else(|| {
                    format!(
                        "Configured pwm_path '{}' does not exist and superio search failed",
                        p_path.display()
                    )
                })?;
            let channel = p_path
                .file_name()
                .and_then(|n| n.to_str())
                .and_then(|s| s.strip_prefix("pwm"))
                .and_then(|s| s.parse::<u32>().ok())
                .unwrap_or(1);
            (
                pwm_hwmon.join(format!("pwm{}", channel)),
                pwm_hwmon.join(format!("pwm{}_enable", channel)),
            )
        }
    } else {
        return Err("No PWM configuration specified".to_string());
    };

    if !pwm.exists() {
        return Err(format!("PWM control path {} does not exist", pwm.display()));
    }
    if !pwm_enable.exists() {
        return Err(format!(
            "PWM enable path {} does not exist",
            pwm_enable.display()
        ));
    }

    Ok(ResolvedPaths {
        temp_input,
        pwm,
        pwm_enable,
    })
}

fn read_temp(path: &Path) -> io::Result<f32> {
    let content = fs::read_to_string(path)?;
    let millidegrees: i32 = content
        .trim()
        .parse()
        .map_err(|e| io::Error::new(ErrorKind::InvalidData, e))?;
    Ok(millidegrees as f32 / 1000.0)
}

fn write_pwm(path: &Path, value: i32) -> io::Result<()> {
    fs::write(path, value.to_string())
}

fn calculate_pwm(temp: f32, config: &Config) -> i32 {
    if temp <= config.min_temp {
        return config.min_pwm;
    }
    if temp >= config.max_temp {
        return config.max_pwm;
    }

    let temp_range = config.max_temp - config.min_temp;
    let pwm_range = config.max_pwm - config.min_pwm;
    let ratio = (temp - config.min_temp) / temp_range;

    config.min_pwm + (ratio * pwm_range as f32) as i32
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <config-file>", args[0]);
        std::process::exit(1);
    }

    let config = match Config::load_from_file(&args[1]) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Failed to load config: {}", e);
            std::process::exit(1);
        }
    };

    println!(
        "GPU Fan Control daemon starting with interval={}s, temp_range=[{:.1}C, {:.1}C], pwm_range=[{}, {}]",
        config.interval, config.min_temp, config.max_temp, config.min_pwm, config.max_pwm
    );

    // Initial resolution with retry loop (for slow hardware / module probing at boot)
    let mut resolved = loop {
        match resolve_paths(&config) {
            Ok(paths) => {
                println!(
                    "Resolved paths: temp={}, pwm={}, pwm_enable={}",
                    paths.temp_input.display(),
                    paths.pwm.display(),
                    paths.pwm_enable.display()
                );
                break paths;
            }
            Err(e) => {
                eprintln!(
                    "Hardware path resolution failed ({}); retrying in 2s...",
                    e
                );
                thread::sleep(Duration::from_secs(2));
            }
        }
    };

    if let Err(e) = fs::write(&resolved.pwm_enable, "1") {
        eprintln!(
            "Warning: Failed to write '1' to {}: {}",
            resolved.pwm_enable.display(),
            e
        );
    } else {
        println!("PWM manual control enabled on {}", resolved.pwm_enable.display());
    }

    let mut last_pwm: Option<i32> = None;

    loop {
        match read_temp(&resolved.temp_input) {
            Ok(temp) => {
                let target_pwm = calculate_pwm(temp, &config);
                let should_write = match last_pwm {
                    Some(lp) => (target_pwm - lp).abs() >= config.hysteresis_pwm,
                    None => true,
                };

                if should_write {
                    if let Err(e) = write_pwm(&resolved.pwm, target_pwm) {
                        eprintln!(
                            "Failed to write PWM ({}) to {}: {}",
                            target_pwm,
                            resolved.pwm.display(),
                            e
                        );
                        // Try re-resolving paths in case hwmon shifted
                        if let Ok(new_paths) = resolve_paths(&config) {
                            resolved = new_paths;
                            let _ = fs::write(&resolved.pwm_enable, "1");
                            let _ = write_pwm(&resolved.pwm, config.max_pwm);
                        }
                    } else {
                        last_pwm = Some(target_pwm);
                        println!("Temp: {:.1}C -> PWM: {}", temp, target_pwm);
                    }
                }
            }
            Err(e) => {
                eprintln!(
                    "Failed to read temp from {}: {}. Attempting re-resolution...",
                    resolved.temp_input.display(),
                    e
                );
                if let Ok(new_paths) = resolve_paths(&config) {
                    resolved = new_paths;
                    let _ = fs::write(&resolved.pwm_enable, "1");
                }
                let _ = write_pwm(&resolved.pwm, config.max_pwm);
            }
        }

        thread::sleep(Duration::from_secs(config.interval));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_pwm() {
        let config = Config {
            temp_chip: Some("amdgpu".into()),
            temp_pci: None,
            temp_label: Some("junction".into()),
            temp_sensor: None,
            temp_path: None,
            pwm_chip: Some("nct6791".into()),
            pwm_channel: Some(3),
            pwm_path: None,
            pwm_enable_path: None,
            min_temp: 40.0,
            max_temp: 100.0,
            min_pwm: 80,
            max_pwm: 200,
            interval: 3,
            hysteresis_pwm: 2,
        };

        assert_eq!(calculate_pwm(30.0, &config), 80);
        assert_eq!(calculate_pwm(40.0, &config), 80);
        assert_eq!(calculate_pwm(70.0, &config), 140);
        assert_eq!(calculate_pwm(100.0, &config), 200);
        assert_eq!(calculate_pwm(110.0, &config), 200);
    }
}
