#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/metal-ca-run-2026-11-05
mkdir -p "$out"
{
  echo "Metal CA run $(date -Is)"
  sha256sum hakios-kernel userland/root.apfs userland/system.apfs
} > "$out/start.txt"
ls -d userland/hakios-metal-cache 2>/dev/null && ls userland/hakios-metal-cache | wc -l >> "$out/start.txt" || true
./xl reboot 2>&1 | tail -1
for i in $(seq 1 40); do sleep 3; s=$(./xl state 2>/dev/null); [ "$s" = loader ] && break; done
./xl ramdisk userland/system.apfs 2>&1 | tail -1 | tee -a "$out/start.txt"
gpu="adreno=22 adreno_skip=0x1cc0 adreno_no_oob=1 adreno_gpucc_restore=1 adreno_vendor_rptr=1 adreno_vendor_nc=1 adreno_vendor_protect=1 adreno_halt_observe=1 adreno_walk=1 adreno_keep=1"
base="cpus=8 bootcpu=7 cpufreq=1 touch=1 pon=1 thermal=1 thermal_pclm10=1 thermal_log=5 thermal_stop=80 bq27541=1 wled=1 smb5=1 cmdb=0x85f20000 epss_hw=1 epss0=0x18323000 epss1=0x18325800 epss2=0x18327800"
metal="gpu=1 metal=1 metal_fps=1 ca_metallib=/redwood/share/ca-share/QuartzCore-default.metallib anim_max=1 fb_hz=120"
args="$base $gpu $metal"
echo "cmdline chars: ${#args}" >> "$out/start.txt"
xnuloader/mkpayload.py -o /tmp/mca.bin kernel=hakios-kernel ramdisk=userland/root.apfs --cmdline "loader_return_after=240 epoch=$(date +%s) sb_delay=8 $args" | tail -1 | tee -a "$out/start.txt"
timeout 30 fastboot stage /tmp/mca.bin 2>&1 | tail -1
timeout 20 fastboot oem run 2>&1 | tail -1
start=$(date +%s)
while :; do
  sleep 3
  now=$(date +%s); [ $((now - start)) -gt 260 ] && { echo "poll timeout" >> "$out/start.txt"; break; }
  r=$(timeout 8 fastboot getvar result 2>/dev/null | grep '^result:' | tail -1)
  [ -z "$r" ] && continue
  case "$r" in *running*) ;; *) echo "final: $r" >> "$out/start.txt"; break ;; esac
done
timeout 90 fastboot get_staged /tmp/mca.log >/dev/null 2>&1
cp -f /tmp/mca.log "$out/run.log"
ls -l "$out/run.log" >> "$out/start.txt"
grep -a -n -E "resident image|kernel returned|HakiosMetal|metal|FD640|renderer|SpringBoard created|frames in|panic\(|M2V|Failed" "$out/run.log" | head -12 >> "$out/start.txt"
