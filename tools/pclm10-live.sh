#!/bin/bash
# pclm10-live.sh -- 起一个长时间运行（不自动返回）的会话，便于在手机上实际操作与随时截屏
#
#   bash tools/pclm10-live.sh [秒数，默认 600]
#
# 启动后本脚本立刻返回；内核会在后台继续运行 <秒数> 秒。
# 期间可用 tools/pclm10-shot.sh 截屏。
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SECS=${1:-600}
out=/mnt/s/opencode/hakios/logs/live-$(date +%Y%m%d-%H%M%S)
mkdir -p "$out"
{
  echo "live session $(date -Is), ${SECS}s"
  sha256sum hakios-kernel userland/root.apfs userland/system.apfs
} > "$out/start.txt"

./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"

gpu="adreno=22 adreno_skip=0x1cc0 adreno_no_oob=1 adreno_gpucc_restore=1 adreno_vendor_rptr=1 adreno_vendor_nc=1 adreno_halt_observe=1 adreno_walk=1 adreno_keep=1"
base="cpus=8 bootcpu=7 cpufreq=1 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=60 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss_hw=1 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800"
metal="gpu=1 metal=1 metal_fps=1 touch_lat=1 ca_metallib=/redwood/share/ca-share/QuartzCore-default.metallib"

xnuloader/mkpayload.py -o /tmp/live.bin kernel=hakios-kernel ramdisk=userland/root.apfs \
  --cmdline "loader_return_after=${SECS} epoch=$(date +%s) sb_delay=8 $base $gpu $metal" \
  | tail -1 | tee -a "$out/start.txt"

timeout 30 fastboot stage /tmp/live.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
echo "session started for ${SECS}s; log dir: $out"
echo "$out" > /tmp/pclm10-live-dir
