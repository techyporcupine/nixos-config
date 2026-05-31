#!/bin/sh
set -euo pipefail

echo "=== Optimizing NVIDIA RTX 3080 Ti ==="
# Enable persistence mode so settings stick
nvidia-smi -pm 1
# Limit power draw to 250W (Strategy A)
echo "Setting RTX 3080 Ti power limit to 250W..."
nvidia-smi -pl 250

echo "=== Optimizing AMD Instinct MI50 ==="
GPU_CLK=1850
MEM_CLK=1150
TDP=225
TDC=190

if ! command -v lspci &> /dev/null; then
  echo "Error: lspci command not found. Please ensure pciutils is in the service path." >&2
  exit 1
fi

mapfile -t AMDGPU_DEVICES < <(
  lspci -D | grep -i 'Vega 20' | awk '{print $1}'
)

if [ "${#AMDGPU_DEVICES[@]}" -eq 0 ]; then
  echo "No Vega 20 / MI50 GPUs found. Skipping AMD optimization."
  exit 0
fi

for dev in "${AMDGPU_DEVICES[@]}"; do
  pp="/sys/bus/pci/devices/$dev/pp_table"

  if [ ! -e "$pp" ]; then
    echo "Skipping $dev: pp_table not found at $pp" >&2
    continue
  fi

  echo "Applying PowerPlay settings to Vega 20 / MI50 GPU ($dev)..."

  # Executed directly as root by the systemd service, so no 'sudo' is required.
  upp -p "$pp" set --write \
    SmallPowerLimit1="$TDP" \
    SmallPowerLimit2="$TDP" \
    BoostPowerLimit="$TDP" \
    PowerSavingClockTable/PowerSavingClockMax/0="$GPU_CLK" \
    smcPPTable/SocketPowerLimitAc0="$TDP" \
    smcPPTable/SocketPowerLimitDc="$TDP" \
    smcPPTable/TdcLimitGfx="$TDC" \
    smcPPTable/FreqTableGfx/8="$GPU_CLK" \
    smcPPTable/FreqTableUclk/2="$MEM_CLK" \
    smcPPTable/FreqTableUclk/3="$MEM_CLK" \
    smcPPTable/DcModeMaxFreq/0="$GPU_CLK"
done
