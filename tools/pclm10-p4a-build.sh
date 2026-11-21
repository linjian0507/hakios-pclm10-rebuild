#!/bin/bash
set -uo pipefail
cd /root/hakios || exit 1
out=/mnt/s/opencode/hakios/logs/p4a-2026-11-05
mkdir -p "$out"
echo "--- clear the sysimage guard by date (content unchanged) ---" | tee -a "$out/build.log"
touch sysimage/rootfs sysimage/system.manifest 2>/dev/null || true
cp /mnt/s/opencode/hakios/userland/rc.jobs.latency.pclm10 userland/rc.jobs.latency.pclm10
cd userland
RC_JOBS=rc.jobs.latency.pclm10 ./build.sh >> "$out/build.log" 2>&1
rc=$?
{
  echo "P4a software latency image build $(date -Is)"
  echo "build rc=$rc"
  sha256sum root.apfs
  ls -l root.apfs
} > "$out/start.txt"
tail -3 "$out/build.log" >> "$out/start.txt"
python3 - <<'PY' >> "$out/start.txt" 2>&1
import sys
sys.path.insert(0,'../tools/apfs')
PY
python3 ../tools/apfs/apfs.py cat root.apfs /etc/rc.jobs 2>/dev/null | tail -8 >> "$out/start.txt"
