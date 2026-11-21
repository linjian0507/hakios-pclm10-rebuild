#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p6-120hz-2026-11-05
mkdir -p "$out"
{
  echo "fast config + fb_hz=120 fb_ca_hz=120, 100 s $(date -Is)"
  sha256sum hakios-kernel userland/root.apfs
} > "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
args="cpus=8 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800 epss_hw=1 bootcpu=7 cpufreq=1 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=80 fb_hz=120 fb_ca_hz=120"
xnuloader/mkpayload.py -o /tmp/hz.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=100 epoch=$(date +%s) sb_delay=8 $args" | tail -1
timeout 30 fastboot stage /tmp/hz.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 120 ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 90 fastboot get_staged /tmp/hz.log >/dev/null 2>&1
cp -f /tmp/hz.log "$out/run.log"
ls -l "$out/run.log" >> "$out/start.txt"
Select-String -Path "$out/run.log" -Pattern "frames in" 2>/dev/null | Select-Object -Last 4 | ForEach-Object { $_.Line } >> "$out/start.txt" || true
grep -a "frames in" "$out/run.log" | tail -4 >> "$out/start.txt"
grep -a -n "frames are made at\|a second: fb_hz\|fb_ca_hz" "$out/run.log" | head -3 >> "$out/start.txt"
