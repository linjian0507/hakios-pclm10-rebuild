#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p2-variantA-2026-11-05
mkdir -p "$out"
echo "--- paths ---" > "$out/start.txt"
ls -l xnu-src/xnu-8796.121.2/iokit/Kernel/MiniIOMobileFramebuffer.cpp >> "$out/start.txt"
cp -f xnu-src/xnu-8796.121.2/iokit/Kernel/MiniIOMobileFramebuffer.cpp "$out/MiniIOMobileFramebuffer.merged.cpp"
git -C /mnt/s/opencode/hakios show pclm10-2026-11-05:xnu/files/iokit/Kernel/MiniIOMobileFramebuffer.cpp > "$out/MiniIOMobileFramebuffer.premerge.cpp"
wc -l "$out/MiniIOMobileFramebuffer.merged.cpp" "$out/MiniIOMobileFramebuffer.premerge.cpp" >> "$out/start.txt"
cp -f "$out/MiniIOMobileFramebuffer.premerge.cpp" xnu-src/xnu-8796.121.2/iokit/Kernel/MiniIOMobileFramebuffer.cpp
make kernel > "$out/build.log" 2>&1
rc=$?
{
  echo "build rc=$rc $(date -Is)"
  sha256sum hakios-kernel
  ls -l hakios-kernel
} >> "$out/start.txt"
