#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p2c-live-2026-11-05
mkdir -p "$out"
{
  echo "P2c live-log diagnosis, fb_beam default (1) $(date -Is)"
  sha256sum hakios-kernel
} > "$out/start.txt"
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
args="cpus=8 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800 epss_hw=1 bootcpu=7 cpufreq=0 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=60"
xnuloader/mkpayload.py -o /tmp/l1.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=180 epoch=$(date +%s) sb_delay=8 $args" | tail -1
timeout 30 fastboot stage /tmp/l1.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
last=""
for i in $(seq 1 40); do
  sleep 5
  timeout 8 fastboot oem log >/dev/null 2>&1
  timeout 20 fastboot get_staged /tmp/live-$i.log >/dev/null 2>&1
  if [ -s /tmp/live-$i.log ]; then
    cp -f /tmp/live-$i.log "$out/live-$i.log"
    last="$out/live-$i.log"
    # a fresh loader banner with no kernel = the phone reset
    if head -c 40 /tmp/live-$i.log | grep -q "XNULOADER v3"; then
      echo "loader banner at live-$i (reset)" >> "$out/start.txt"
      break
    fi
  fi
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  case "$r" in *running*) ;; *) echo "result at live-$i: $r" >> "$out/start.txt"; break ;; esac
done
echo "files: $(ls $out/live-*.log 2>/dev/null | wc -l)" >> "$out/start.txt"
for f in $(ls $out/live-*.log 2>/dev/null | tail -5); do
  echo "--- $f ---" >> "$out/start.txt"
  grep -a -n -E "fb_beam|beam|the panel's scan|counters|INTF|line" "$f" | tail -8 >> "$out/start.txt"
done
