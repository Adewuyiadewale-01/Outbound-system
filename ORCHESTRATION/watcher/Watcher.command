#!/bin/zsh
set -euo pipefail

cd "$(cd "$(dirname "$0")/../.." && pwd)"
python3 ORCHESTRATION/watcher/orchestration_watcher.py

echo
echo "Done. Press Return to close this window."
read -r _
