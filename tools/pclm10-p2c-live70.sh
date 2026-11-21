#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p2c-guard-live-2026-11-05
mkdir -p "$out"
{
  echo "P2c guard live check at 70 s $(date -Is)"
  sha256sum hakios-kernel
} > "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
args="cpus=8 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800 epss_hw=1 bootcpu=7 cpufreq=0 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=60"
xnuloader/mkpayload.py -o /tmp/gl.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=150 epoch=$(date +%s) sb_delay=8 $args" | tail -1
timeout 30 fastboot stage /tmp/gl.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
sleep 70
timeout 8 fastboot oem log >/dev/null 2>&1
timeout 20 fastboot get_staged /tmp/gl-live.log >/dev/null 2>&1
cp -f /tmp/gl-live.log "$out/live-70.log"
echo "live size: $(stat -c %s $out/live-70.log)" >> "$out/start.txt"
grep -a -n "fb_beam\|probe knows\|frames stay" "$out/live-70.log" | head -5 >> "$out/start.txt"
# let it finish for the record
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 100 ] && break
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  case "$r" in *running*|"") ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 60 fastboot get_staged /tmp/gl-final.log >/dev/null 2>&1
cp -f /tmp/gl-final.log "$out/final.log" 2>/dev/null || true
