#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p6-boot-2026-11-05
mkdir -p "$out"
touch sysimage/rootfs sysimage/system.manifest 2>/dev/null || true
cd userland
SLEEPD=0 ./build.sh > "$out/build.log" 2>&1
rc=$?
{
  echo "fast boot image SLEEPD=0 $(date -Is)"
  echo "build rc=$rc"
  sha256sum root.apfs
  ls -l root.apfs
} > "$out/start.txt"
tail -2 "$out/build.log" >> "$out/start.txt"
