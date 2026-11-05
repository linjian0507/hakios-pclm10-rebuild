#!/bin/bash
# pclm10-fps-live.sh -- 真机 60 fps 验收测量
#
# 用法（需要用户在场并在手机上滑动）：
#   bash tools/pclm10-fps-live.sh [秒数，默认 60]
#
# 它做的事：
#   1. 以 touch_lat=1 启动，保持设备运行 <秒数>（默认 60 秒）；
#   2. 期间请在屏幕上连续滑动（列表滚动、左右翻页都行）；
#   3. 结束后自动取回日志，并给出帧间隔的分布（均值/中位数/P90/占比）。
#
# 注意：这是用户在场的手动验收，不会自动解除 configs/interactive-hold.txt。
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SECONDS_TO_RUN=${1:-60}
out=/mnt/s/opencode/hakios/logs/fps-live-$(date +%Y%m%d-%H%M%S)
mkdir -p "$out"
{
  echo "fps live acceptance $(date -Is), running ${SECONDS_TO_RUN}s"
  sha256sum hakios-kernel userland/root.apfs userland/system.apfs
} > "$out/start.txt"

./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"

gpu="adreno=22 adreno_skip=0x1cc0 adreno_no_oob=1 adreno_gpucc_restore=1 adreno_vendor_rptr=1 adreno_vendor_nc=1 adreno_halt_observe=1 adreno_walk=1 adreno_keep=1"
base="cpus=8 bootcpu=7 cpufreq=1 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=60 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss_hw=1 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800"
metal="gpu=1 metal=1 metal_fps=1 touch_lat=1 ca_metallib=/redwood/share/ca-share/QuartzCore-default.metallib"

xnuloader/mkpayload.py -o /tmp/fpslive.bin kernel=hakios-kernel ramdisk=userland/root.apfs \
  --cmdline "loader_return_after=${SECONDS_TO_RUN} epoch=$(date +%s) sb_delay=8 $base $gpu $metal" \
  | tail -1 | tee -a "$out/start.txt"

timeout 30 fastboot stage /tmp/fpslive.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1

echo ">>> 现在请在手机上连续滑动，持续 ${SECONDS_TO_RUN} 秒 <<<"
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt $((SECONDS_TO_RUN + 40)) ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 120 fastboot get_staged /tmp/fpslive.log >/dev/null 2>&1
cp -f /tmp/fpslive.log "$out/run.log"

python3 - "$out/run.log" <<'PY'
import re, sys, statistics
path = sys.argv[1]
ready = []
with open(path, 'rb') as f:
    for line in f:
        m = re.search(rb'tl: v \d+ ready (\d+)', line)
        if m:
            ready.append(int(m.group(1)))
if len(ready) < 2:
    print("no touch_lat frames found; is touch_lat=1 set and did anything draw?")
    raise SystemExit(0)
d = [b - a for a, b in zip(ready, ready[1:]) if 0 < b - a < 2_000_000]
d.sort()
n = len(d)
def pct(p):
    return d[min(n - 1, int(n * p))]
print(f"frames: {n+1}, intervals: {n}")
print(f"mean {statistics.mean(d):.0f} us  median {statistics.median(d):.0f} us  p90 {pct(0.9)} us")
print(f"share <= 16667 us (60fps): {100.0*sum(1 for x in d if x <= 16667)/n:.1f}%")
print(f"share <= 20000 us (50fps): {100.0*sum(1 for x in d if x <= 20000)/n:.1f}%")
PY

echo "log: $out/run.log"
