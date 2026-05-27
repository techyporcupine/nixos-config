use std::env;
use std::fs;
use std::io::{self, ErrorKind};
use std::path::Path;
use std::thread;
use std::time::Duration;

struct Config {
    temp_path: String,
    pwm_path: String,
    pwm_enable_path: String,
    min_temp: f32,
    max_temp: f32,
    min_pwm: i32,
    max_pwm: i32,
    interval: u64,
}

impl Config {
    fn load_from_file<P: AsRef<Path>>(path: P) -> Result<Self, io::Error> {
        let content = fs::read_to_string(path)?;
        let mut temp_path = None;
        let mut pwm_path = None;
        let mut pwm_enable_path = None;
        let mut min_temp = None;
        let mut max_temp = None;
        let mut min_pwm = None;
        let mut max_pwm = None;
        let mut interval = None;

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
            let value = parts[1].trim();

            match key {
                "temp_path" => temp_path = Some(value.to_string()),
                "pwm_path" => pwm_path = Some(value.to_string()),
                "pwm_enable_path" => pwm_enable_path = Some(value.to_string()),
                "min_temp" => min_temp = value.parse::<f32>().ok(),
                "max_temp" => max_temp = value.parse::<f32>().ok(),
                "min_pwm" => min_pwm = value.parse::<i32>().ok(),
                "max_pwm" => max_pwm = value.parse::<i32>().ok(),
                "interval" => interval = value.parse::<u64>().ok(),
                _ => {}
            }
        }

        Ok(Config {
            temp_path: temp_path
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing temp_path"))?,
            pwm_path: pwm_path
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing pwm_path"))?,
            pwm_enable_path: pwm_enable_path
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing pwm_enable_path"))?,
            min_temp: min_temp
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing min_temp"))?,
            max_temp: max_temp
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing max_temp"))?,
            min_pwm: min_pwm
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing min_pwm"))?,
            max_pwm: max_pwm
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing max_pwm"))?,
            interval: interval
                .ok_or_else(|| io::Error::new(ErrorKind::InvalidData, "Missing interval"))?,
        })
    }
}

fn read_temp(path: &str) -> io::Result<f32> {
    let content = fs::read_to_string(path)?;
    let millidegrees: i32 = content
        .trim()
        .parse()
        .map_err(|e| io::Error::new(ErrorKind::InvalidData, e))?;
    Ok(millidegrees as f32 / 1000.0)
}

fn write_pwm(path: &str, value: i32) -> io::Result<()> {
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
        "GPU Fan Control started: temp={}, pwm={}, interval={}s",
        config.temp_path, config.pwm_path, config.interval
    );

    if let Err(e) = fs::write(&config.pwm_enable_path, "1") {
        eprintln!("Failed to enable manual PWM control: {}", e);
        std::process::exit(1);
    }
    println!("PWM manual mode enabled");

    loop {
        match read_temp(&config.temp_path) {
            Ok(temp) => {
                let pwm = calculate_pwm(temp, &config);
                if let Err(e) = write_pwm(&config.pwm_path, pwm) {
                    eprintln!("Failed to write PWM ({}), setting max: {}", pwm, e);
                    let _ = write_pwm(&config.pwm_path, config.max_pwm);
                } else {
                    println!("Temp: {:.1}C -> PWM: {}", temp, pwm);
                }
            }
            Err(e) => {
                eprintln!("Failed to read temp, setting max PWM: {}", e);
                let _ = write_pwm(&config.pwm_path, config.max_pwm);
            }
        }

        thread::sleep(Duration::from_secs(config.interval));
    }
}
