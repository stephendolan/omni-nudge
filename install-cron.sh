#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAG_SCRIPT="$SCRIPT_DIR/omnifocus-nag.sh"

if [ ! -f "$NAG_SCRIPT" ]; then
    echo "ERROR: Cannot find omnifocus-nag.sh"
    exit 1
fi

[ ! -x "$NAG_SCRIPT" ] && chmod +x "$NAG_SCRIPT"

CRON_LINE="*/30 9-17 * * 1-5 $NAG_SCRIPT"

if crontab -l 2>/dev/null | grep -q "omnifocus-nag.sh"; then
    crontab -l 2>/dev/null | grep -v "omnifocus-nag.sh" | { cat; echo "$CRON_LINE"; } | crontab -
else
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
fi

echo "Cron job installed: Every 30 min, 9am-5pm, Mon-Fri"
echo "Test: $NAG_SCRIPT"
echo "Logs: tail -f $SCRIPT_DIR/taskmaster.log"
