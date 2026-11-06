#!/bin/bash
# pclm10-fps-live.sh -- 真机 60 fps 验收（先等界面起来，再提示滑动）
#
#   bash tools/pclm10-fps-live.sh [滑动秒数=60] [启动等待=150]
#
# 判据：输出里 "share <= 16667 us (60fps)" 即滑动期间达到 60 fps 的占比。
set -uo pipefail
cd /root/hakios 2>/dev/null || exit 1

RUN=${1:-60}
BOOT=${2:-150}
TOTAL=$((BOOT + RUN + 30))
out=/mnt/s/opencode/hakios/logs/fps-live-$(date +%Y%m%d-%H%M%S)
mkdir -p "$out"
{
  echo "fps live: run ${RUN}s after boot wait ${BOOT}s"
  sha256sum hakios-kernel userland/root.apfs userland/system.apfs
} > "$out/start.txt"

./xl reboot 2>&1 | tail -1
for i in $(seq 1 60); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
sleep 5
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"

gpu="adreno=22 adreno_skip=0x1cc0 adreno_no_oob=1 adreno_gpucc_restore=1 adreno_vendor_rptr=1 adreno_vendor_nc=1 adreno_halt_observe=1 adreno_walk=1 adreno_keep=1"
base="cpus=8 bootcpu=7 cpufreq=1 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=0 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss_hw=1 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800"
metal="gpu=1 metal=1 metal_fps=1 touch_lat=1 ca_metallib=/redwood/share/ca-share/QuartzCore-default.metallib"

xnuloader/mkpayload.py -o /tmp/fpslive.bin kernel=hakios-kernel ramdisk=userland/root.apfs \
  --cmdline "loader_return_after=$TOTAL epoch=$(date +%s) sb_delay=8 $base $gpu $metal" \
  | tail -1 | tee -a "$out/start.txt"

timeout 30 fastboot stage /tmp/fpslive.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1

echo ">>> 启动中，等待 ${BOOT} 秒 <<<"
sleep "$BOOT"
echo ">>> 现在请在手机上连续滑动 ${RUN} 秒 <<<"

start=$(date +%s)
while :; do
  sleep 5
  now=$(date +%s); [ $((now - start)) -gt $((RUN + 60)) ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done

timeout 120 fastboot get_staged /tmp/fpslive.log >/dev/null 2>&1 || true
cp -f /tmp/fpslive.log "$out/run.log" 2>/dev/null || true

python3 - "$out/run.log" <<'PY'
import re, sys, statistics
ready = []
with open(sys.argv[1], 'rb') as f:
    for line in f:
        m = re.search(rb'tl: v \d+ ready (\d+)', line)
        if m:
            ready.append(int(m.group(1)))
if len(ready) < 2:
    print("frames: insufficient (%d); was the UI up and did anything draw?" % len(ready))
    raise SystemExit(0)
d = [b - a for a, b in zip(ready, ready[1:]) if 0 < b - a < 2_000_000]
d.sort()
n = len(d)
print("frames: %d, intervals: %d" % (len(ready), n))
print("mean %.0f us  median %.0f us  p90 %d us" % (statistics.mean(d), statistics.median(d), d[int(0.9*(n-1))]))
print("share <= 16667 us (60fps): %.1f%%" % (100.0*sum(1 for x in d if x <= 16667)/n))
PY
echo "log: $out/run.log"
