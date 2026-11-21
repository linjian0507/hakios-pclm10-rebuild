#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/qemu-open-2026-11-05
mkdir -p "$out"
{
  echo "P1 QEMU-open smoke $(date -Is)"
  echo "pclm10 kernel before: $(sha256sum hakios-kernel 2>/dev/null)"
  ls -l /usr/share/AAVMF/AAVMF_CODE.fd /usr/share/edk2/aarch64/QEMU_EFI.fd 2>&1
} > "$out/start.txt"
cp -f hakios-kernel "$out/hakios-kernel.merged-7f37c8" 2>/dev/null || true
cp -f .config "$out/.config.pclm10" 2>/dev/null || true
echo "--- open defconfig ---" >> "$out/start.txt"
make defconfig >> "$out/build.log" 2>&1
echo "defconfig rc=$?" >> "$out/start.txt"
echo "--- qemu-open (build + 40 s run) ---" >> "$out/start.txt"
make qemu-open SECS=40 >> "$out/build.log" 2>&1
echo "qemu rc=$?" >> "$out/start.txt"
cp -f logs/qemu-open.log "$out/qemu-open.log" 2>/dev/null || true
echo "--- restore pclm10 ---" >> "$out/start.txt"
cp -f "$out/.config.pclm10" .config
make pclm10_defconfig >> "$out/restore.log" 2>&1
make kernel >> "$out/restore.log" 2>&1
echo "restore rc=$?" >> "$out/start.txt"
sha256sum hakios-kernel >> "$out/start.txt"
echo "done $(date -Is)" >> "$out/start.txt"
