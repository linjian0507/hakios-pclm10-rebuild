#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p2c-guard-75-2026-11-05
mkdir -p "$out"
{
  echo "P2c guard 75 s (short log, no ring wrap) $(date -Is)"
  sha256sum hakios-kernel
} > "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
args="cpus=8 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800 epss_hw=1 bootcpu=7 cpufreq=0 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=60"
xnuloader/mkpayload.py -o /tmp/g75.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=75 epoch=$(date +%s) sb_delay=8 $args" | tail -1
timeout 30 fastboot stage /tmp/g75.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 120 ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 60 fastboot get_staged /tmp/g75.log >/dev/null 2>&1
cp -f /tmp/g75.log "$out/run.log"
ls -l "$out/run.log" >> "$out/start.txt"
grep -a -n "fb_beam\|probe knows\|frames stay" "$out/run.log" | head -5 >> "$out/start.txt"
grep -a -n "kernel returned" "$out/run.log" | head -2 >> "$out/start.txt"
