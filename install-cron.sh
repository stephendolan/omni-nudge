#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAG_SCRIPT="$SCRIPT_DIR/omnifocus-nag.sh"

if [ ! -f "$NAG_SCRIPT" ]; then
    echo "ERROR: Cannot find omnifocus-nag.sh"
    exit 1
fi

[ ! -x "$NAG_SCRIPT" ] && chmod +x "$NAG_SCRIPT"

# Get current PATH to use in cron
CURRENT_PATH="$PATH"

# Prompt for work calendar name
echo "Enter your work calendar name (e.g., work@company.com) or press Enter to skip meeting detection:"
read -r CALENDAR_NAME

if [ -n "$CALENDAR_NAME" ]; then
    CRON_LINE1="0,30 9-15 * * 1-5 PATH=$CURRENT_PATH WORK_CALENDAR=\"$CALENDAR_NAME\" $NAG_SCRIPT"
    CRON_LINE2="0,30 16 * * 1-5 PATH=$CURRENT_PATH WORK_CALENDAR=\"$CALENDAR_NAME\" $NAG_SCRIPT"
else
    CRON_LINE1="0,30 9-15 * * 1-5 PATH=$CURRENT_PATH $NAG_SCRIPT"
    CRON_LINE2="0,30 16 * * 1-5 PATH=$CURRENT_PATH $NAG_SCRIPT"
fi

if crontab -l 2>/dev/null | grep -q "omnifocus-nag.sh"; then
    crontab -l 2>/dev/null | grep -v "omnifocus-nag.sh" | { cat; echo "$CRON_LINE1"; echo "$CRON_LINE2"; } | crontab -
else
    (crontab -l 2>/dev/null; echo "$CRON_LINE1"; echo "$CRON_LINE2") | crontab -
fi

echo "Cron job installed: Every 30 min, 9am-4:30pm, Mon-Fri"
echo "Test: $NAG_SCRIPT"
echo "Logs: tail -f $SCRIPT_DIR/taskmaster.log"
