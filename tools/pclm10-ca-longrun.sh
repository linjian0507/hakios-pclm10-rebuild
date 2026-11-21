#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/ca-longrun-2026-11-06
mkdir -p "$out"
{
  echo "CA 240s long run $(date -Is)"
  sha256sum hakios-kernel userland/root.apfs userland/system.apfs
} > "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
gpu="adreno=22 adreno_skip=0x1cc0 adreno_no_oob=1 adreno_gpucc_restore=1 adreno_vendor_rptr=1 adreno_vendor_nc=1 adreno_halt_observe=1 adreno_walk=1 adreno_keep=1"
base="cpus=8 bootcpu=7 cpufreq=1 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=80 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss_hw=1 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800"
metal="gpu=1 metal=1 metal_fps=1 touch_lat=1 ca_metallib=/redwood/share/ca-share/QuartzCore-default.metallib"
args="$base $gpu $metal"
xnuloader/mkpayload.py -o /tmp/mcalong.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=240 epoch=$(date +%s) sb_delay=8 $args" | tail -1 | tee -a "$out/start.txt"
timeout 30 fastboot stage /tmp/mcalong.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 280 ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 90 fastboot get_staged /tmp/mcalong.log >/dev/null 2>&1
cp -f /tmp/mcalong.log "$out/run.log"
ls -l "$out/run.log" >> "$out/start.txt"
grep -a "frames in" "$out/run.log" | tail -3 >> "$out/start.txt"
python3 - <<'PY' >> "$out/start.txt" 2>&1
import re
p='/mnt/s/opencode/hakios/logs/ca-longrun-2026-11-06/run.log'
t=[]
for line in open(p, errors='replace'):
    m=re.search(r'tl: v \d+ ready (\d+) shown (\d+) done (\d+)', line)
    if m: t.append((int(m.group(1)), int(m.group(2)), int(m.group(3))))
# take frames after the 100s mark (first 100s = boot/load), last 100 frames
if len(t) > 120:
    tail = t[-100:]
    gaps = [(tail[i+1][0]-tail[i][0])/1000.0 for i in range(len(tail)-1)]
    gaps = [g for g in gaps if 0 < g < 200]
    if gaps:
        gaps.sort()
        print('tail frames', len(tail), 'median gap ms', round(gaps[len(gaps)//2],2), 'min', round(gaps[0],2), 'max', round(gaps[-1],2))
        print('fps (median gap)', round(1000.0/gaps[len(gaps)//2],1) if gaps[len(gaps)//2] else 0)
PY
