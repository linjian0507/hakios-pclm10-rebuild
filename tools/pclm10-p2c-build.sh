#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p2c-guard-2026-11-05
mkdir -p "$out"
{
  echo "P2c guard build $(date -Is)"
  cp -f xnu-src/xnu-8796.121.2/iokit/Kernel/MiniIOMobileFramebuffer.cpp "$out/MiniIOMobileFramebuffer.before-guard.cpp"
} > "$out/start.txt"
cp -f /mnt/s/opencode/hakios/xnu/files/iokit/Kernel/MiniIOMobileFramebuffer.cpp xnu-src/xnu-8796.121.2/iokit/Kernel/MiniIOMobileFramebuffer.cpp
grep -c "beamKverHas" xnu-src/xnu-8796.121.2/iokit/Kernel/MiniIOMobileFramebuffer.cpp >> "$out/start.txt"
make kernel > "$out/build.log" 2>&1
rc=$?
{
  echo "build rc=$rc $(date -Is)"
  sha256sum hakios-kernel
  ls -l hakios-kernel
} >> "$out/start.txt"
