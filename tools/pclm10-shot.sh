#!/bin/bash
# pclm10-shot.sh -- 抓当前帧缓冲为 PNG（会话运行期间可用）
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
f=${1:-/mnt/s/opencode/hakios/logs/screen.png}
./xl screenshot "$f" 2>&1 | tail -2
ls -l "$f" 2>&1
