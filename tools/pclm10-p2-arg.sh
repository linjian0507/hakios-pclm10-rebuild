#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
tag="${TAG:-args}"
out=/mnt/s/opencode/hakios/logs/p2-$tag-2026-11-05
mkdir -p "$out"
{
  echo "P2 merged kernel + extra='${EXTRA:-}' $(date -Is)"
  sha256sum hakios-kernel userland/root.apfs
} > "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
args="cpus=8 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800 epss_hw=1 bootcpu=7 cpufreq=0 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=60 ${EXTRA:-}"
xnuloader/mkpayload.py -o /tmp/a1.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=150 epoch=$(date +%s) sb_delay=8 $args" | tail -1
timeout 30 fastboot stage /tmp/a1.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 230 ] && { echo "poll timeout $((now-start))s" >> "$out/start.txt"; break; }
  r=$(timeout 10 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 90 fastboot get_staged /tmp/a1.log 2>&1 | tail -1
cp -f /tmp/a1.log "$out/run.log"
ls -l "$out/run.log" >> "$out/start.txt"
grep -a -n -E "resident image|BSD root|kernel returned|panic\(|SpringBoard created|thermal_stop" "$out/run.log" | head -8 >> "$out/start.txt"
echo "state after: $(./xl state)" >> "$out/start.txt"
