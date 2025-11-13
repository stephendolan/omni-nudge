#!/bin/bash

set -euo pipefail

if crontab -l 2>/dev/null | grep -q "omnifocus-nag.sh"; then
    crontab -l 2>/dev/null | grep -v "omnifocus-nag.sh" | crontab -
    echo "Cron job removed"
else
    echo "No cron job found"
fi
