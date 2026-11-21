#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p6-boot-fast-2026-11-05
mkdir -p "$out"
{
  echo "fast boot run: SLEEPD=0, cpufreq=1, 120 s, rec_ring=0 $(date -Is)"
  sha256sum hakios-kernel userland/root.apfs
} > "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
args="cpus=8 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800 epss_hw=1 bootcpu=7 cpufreq=1 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=80 rec_secs=120 rec_ring=0 rec_step=6 rec_mb=256"
xnuloader/mkpayload.py -o /tmp/bf.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=120 epoch=$(date +%s) sb_delay=8 $args" | tail -1
timeout 30 fastboot stage /tmp/bf.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 140 ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 90 fastboot get_staged /tmp/bf.log >/dev/null 2>&1
cp -f /tmp/bf.log "$out/run.log"
XL_REC_KEEP=1 ./xl recording "$out/recording.mp4" >> "$out/recording.log" 2>&1 || true
cp -f logs/recording.raw "$out/recording.raw" 2>/dev/null || true
ls -l "$out/run.log" "$out/recording.raw" >> "$out/start.txt" 2>&1
grep -a -n -E "kernel returned|SpringBoard created|frames in|no GPU draws|thermal: .*hottest" "$out/run.log" | head -8 >> "$out/start.txt"
