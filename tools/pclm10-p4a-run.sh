#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p4a-2026-11-05
{
  echo "P4a latency run $(date -Is)"
  sha256sum hakios-kernel userland/root.apfs
} >> "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
args="cpus=8 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800 epss_hw=1 bootcpu=7 cpufreq=0 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=60 touch_lat=1 rec_secs=300 rec_ring=1 rec_step=6 rec_mb=256"
xnuloader/mkpayload.py -o /tmp/lat.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=240 epoch=$(date +%s) sb_delay=8 $args" | tail -1
timeout 30 fastboot stage /tmp/lat.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 260 ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
# log first
timeout 90 fastboot get_staged /tmp/lat.log >/dev/null 2>&1
cp -f /tmp/lat.log "$out/run.log"
ls -l "$out/run.log" >> "$out/start.txt"
# then the recording (kept as raw too)
XL_REC_KEEP=1 ./xl recording "$out/recording.mp4" >> "$out/recording.log" 2>&1 || echo "recording fetch failed" >> "$out/start.txt"
cp -f logs/recording.raw "$out/recording.raw" 2>/dev/null || true
ls -l "$out/recording.raw" >> "$out/start.txt" 2>&1
grep -a -n -E "resident image|kernel returned|touch_lat|tl: p|SpringBoard created|thermal_stop" "$out/run.log" | head -8 >> "$out/start.txt"
