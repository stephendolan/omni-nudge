#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${OMNI_NUDGE_LOG_FILE:-$SCRIPT_DIR/omni-nudge.log}"
END_OF_DAY="${OMNI_NUDGE_END_OF_DAY:-16:30}"
SKIP_CONFIRMATION="${OMNI_NUDGE_SKIP_CONFIRMATION:-false}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting OmniFocus task check..."

if ! command -v of &> /dev/null; then
    log "ERROR: 'of' command not found. Install omnifocus-cli first."
    exit 1
fi

if ! command -v claude &> /dev/null; then
    log "ERROR: 'claude' command not found. Install Claude Code first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log "ERROR: 'jq' command not found. Install jq for JSON filtering."
    exit 1
fi

cd "$SCRIPT_DIR"

if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
    USER_RESPONSE=$(osascript -e 'button returned of (display dialog "Time for your productivity check-in. Run audit now?" buttons {"Skip", "Run Audit"} default button "Run Audit" giving up after 10)' 2>/dev/null || echo "Skip")

    if [[ "$USER_RESPONSE" != "Run Audit" ]]; then
        log "User skipped audit"
        exit 0
    fi
fi

log "Verifying MCP configuration..."
if ! claude mcp list 2>&1 | grep -q "memory.*Connected"; then
    log "WARNING: Memory MCP server not connected. Task history tracking will be limited."
fi

log "Fetching OmniFocus data..."

INBOX_RAW=$(of inbox list 2>/dev/null | grep -v "^- Loading")
if [ -n "$INBOX_RAW" ]; then
    INBOX_JSON=$(echo "$INBOX_RAW" | jq '[.[] | select(.completed | not)]') || {
        log "ERROR: Failed to filter inbox JSON"
        exit 1
    }
else
    INBOX_JSON="[]"
fi

NEXT_RAW=$(of perspective view "Next" 2>/dev/null | grep -v "^- Loading")
if [ -n "$NEXT_RAW" ]; then
    NEXT_JSON=$(echo "$NEXT_RAW" | jq '[.[] | select(.completed | not)]') || {
        log "ERROR: Failed to filter next actions JSON"
        exit 1
    }
else
    NEXT_JSON="[]"
fi

DAY_OF_WEEK=$(date "+%A")
DAY_NUMBER=$(date "+%u")
IS_WEEKEND=$([[ "$DAY_NUMBER" -ge 6 ]] && echo "true" || echo "false")

CURRENT_TIME=$(date "+%H:%M")
if [[ "$IS_WEEKEND" == "true" ]]; then
    WORK_HOURS_REMAINING=0
else
    CURRENT_MINUTES=$((10#$(date "+%H") * 60 + 10#$(date "+%M")))
    EOD_HOUR=$(echo "$END_OF_DAY" | cut -d: -f1)
    EOD_MINUTE=$(echo "$END_OF_DAY" | cut -d: -f2)
    EOD_MINUTES=$((10#$EOD_HOUR * 60 + 10#$EOD_MINUTE))
    REMAINING_MINUTES=$((EOD_MINUTES - CURRENT_MINUTES))
    WORK_HOURS_REMAINING=$(awk "BEGIN {printf \"%.1f\", $REMAINING_MINUTES / 60}")
fi

TASK_SNAPSHOT=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "current_time": "$(date "+%Y-%m-%d %H:%M:%S %Z")",
  "end_of_day": "$END_OF_DAY",
  "day_of_week": "$DAY_OF_WEEK",
  "is_weekend": $IS_WEEKEND,
  "work_hours_remaining": $WORK_HOURS_REMAINING,
  "inbox": $INBOX_JSON,
  "next_actions": $NEXT_JSON
}
EOF
)

PROMPT_FILE="$SCRIPT_DIR/agent-prompt.md"
if [ ! -f "$PROMPT_FILE" ]; then
    log "ERROR: Prompt file not found at $PROMPT_FILE"
    exit 1
fi

log "Invoking Claude..."

CONTEXT="You are a ruthless task enforcer operating on this system.

## CURRENT OMNIFOCUS SNAPSHOT

\`\`\`json
$TASK_SNAPSHOT
\`\`\`

## YOUR INSTRUCTIONS

$(cat "$PROMPT_FILE")"

claude -p "$CONTEXT" \
    --allowedTools "Bash(say:*),Bash(date:*),Bash(of:*),Bash(terminal-notifier:*),mcp__memory" \
    --output-format json \
    --model haiku \
    --verbose 2>&1 | tee -a "$LOG_FILE"

RESULT=$?

if [ $RESULT -eq 0 ]; then
    log "Task check completed successfully"
else
    log "ERROR: Task check failed with exit code $RESULT"
fi

exit $RESULT
