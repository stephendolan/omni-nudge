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

log "Preparing prompt and invoking Claude..."

PROMPT_FILE="$SCRIPT_DIR/agent-prompt.md"

if [ ! -f "$PROMPT_FILE" ]; then
    log "ERROR: Prompt file not found at $PROMPT_FILE"
    exit 1
fi

CONTEXT="You are a ruthless task enforcer operating on this system.

End of work day: $END_OF_DAY

Use 'date' command to get current time and day of week when needed.

$(cat "$PROMPT_FILE")"

claude -p "$CONTEXT" \
    --allowedTools "Bash(say:*),Bash(date:*),Bash(of:*),mcp__memory" \
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
