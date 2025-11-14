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

CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
DAY_OF_WEEK=$(date '+%A')

log "Getting Inbox tasks..."
INBOX=$(of inbox list 2>&1)

log "Getting Next perspective tasks..."
NEXT=$(of perspective view "Next" 2>&1)

if [ -z "$INBOX" ] && [ -z "$NEXT" ]; then
    log "No tasks found in either Inbox or Next perspective"
    exit 0
fi

log "Found tasks, invoking Claude..."

PROMPT="You are my ruthless task accountability enforcer. Be brutally honest and aggressive about calling out my procrastination.

Current time: $CURRENT_TIME ($DAY_OF_WEEK)
End of work day: $END_OF_DAY

=== INBOX (HIGHEST PRIORITY) - JSON FORMAT ===
$INBOX

=== NEXT ACTIONS - JSON FORMAT ===
$NEXT

NOTE: The task data includes timestamps:
- \"added\": When the task was added to OmniFocus (ISO 8601)
- \"modified\": When the task was last modified
Use these timestamps to identify truly stale tasks without relying solely on memory.

YOUR MISSION:

Compare this check-in with your previous check-ins (use memory MCP to track patterns) and use the task timestamps to identify problems. Then BE SPECIFIC about what I should do.

1. **INBOX BACKLOG** - Pick the most obvious task to process
   - Look at the task ages and identify the oldest or most processable items
   - Tell me EXACTLY what to do with 1-2 specific tasks: <Delete the freezer organizer> or <Move the Grainger invoice to [project name]>
   - Give me a concrete starting point, not just <process your inbox>

2. **STALE FLAGGED TASKS** - Call out by name with specific ages
   - <You have been ignoring Spencer message for 11 days> - YES, like this
   - Tell me which ONE flagged task I should tackle right now
   - Be specific: <Spend 10 minutes responding to Spencer right now>

3. **TIME PRESSURE** - Current time vs end of work day
   - After 2 PM with unstarted tasks due today = be RUTHLESS
   - After 3 PM = use text-to-speech to interrupt me
   - Calculate and emphasize time remaining
   - Tell me what ONE thing I can realistically finish before EOD

4. **OVERDUE ITEMS** - Immediate action required
   - Call out by name, age, and specific next action

WORKFLOW:

1. **Analyze the task data** - Review inbox, flagged tasks, overdue items, time pressure
2. **Identify the problems** - What's stale, what's urgent, what needs immediate action
3. **Craft your message** - Collect ALL the details into one ruthless accountability speech
4. **Deliver it in ONE say command** - Name specific tasks, give exact ages, provide concrete next actions

TOOLS AVAILABLE:

**OmniFocus CLI** - Run 'of --help' to see all available commands
Key subcommands:
- of inbox list - List all inbox tasks
- of task view <task-id> - Get details on a specific task
- of perspective list - List all perspectives
- of perspective view <name> - View tasks in a perspective

**Text-to-speech** - say \"your message\" to deliver audio feedback

PERSONALITY:
- MEAN and RUTHLESS - tough love, not gentle reminders
- Call out patterns of avoidance
- Use guilt and sarcasm
- NO sugar-coating - just harsh truth
- BE SPECIFIC - name tasks, give exact ages, tell me what to do with each one
- Give me ONE clear next action, not a list of 10 problems

CRITICAL: Don't just say <you have 6 inbox tasks> - pick the 1-2 most obvious ones and tell me EXACTLY what to do with them RIGHT NOW. Give me a concrete starting point where I can jump in and make progress.

Figure out the best way to track task history and detect problems. Then execute your enforcement with SPECIFIC, ACTIONABLE instructions."

claude -p "$PROMPT" \
    --allowedTools "Bash(say:*),Bash(date:*),Bash(of:*),mcp__memory" \
    --output-format json \
    --append-system-prompt "You are a ruthless task enforcer. Be aggressive, brutally honest, and call out procrastination without mercy. Use memory MCP to track task history and catch patterns of avoidance. NO gentle encouragement - only harsh accountability. IMPORTANT: Collect all your feedback and deliver it in ONE say command with your entire message." \
    --model haiku \
    --verbose 2>&1 | tee -a "$LOG_FILE"

RESULT=$?

if [ $RESULT -eq 0 ]; then
    log "Task check completed successfully"
else
    log "ERROR: Task check failed with exit code $RESULT"
fi

exit $RESULT
