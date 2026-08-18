#!/bin/zsh
set -e

cd "$(dirname "$0")"

echo "Running Pre-final P1 swap check..."
echo

python3 scripts/swap_prefinal_p1_from_name_sheet.py

echo
echo "Done. Press Return to close this window."
read -r _
