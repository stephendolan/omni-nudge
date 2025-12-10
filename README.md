# OmniNudge

**A ruthless task accountability system powered by Claude Code.**

## The Core Idea

Traditional task managers are passive - they show you lists and hope you'll process them. OmniNudge is **active accountability**:

1. Fetches your OmniFocus tasks (Inbox + Next perspective)
2. Sends them to Claude Code with a [ruthless enforcement agent](.claude/agents/task-enforcer.md)
3. Claude analyzes task ages, patterns, and time pressure
4. Delivers **specific** actions via notifications: "Delete the freezer organizer task" not "process your inbox"
5. Uses Memory MCP to track patterns and escalate for repeat offenders

The secret sauce is the **agent prompt** (see [.claude/agents/task-enforcer.md](.claude/agents/task-enforcer.md)). It's designed to be brutally honest, highly specific, and action-oriented.

## Why This Works

- **Specificity**: Tells you exactly which task to act on and what to do with it
- **Escalation**: Notices when tasks keep appearing and gets more aggressive
- **Time pressure**: Calculates hours until end of day and creates urgency
- **Multi-modal**: Visual notifications + audio interruptions = harder to ignore
- **Patterns**: Tracks task history to identify avoidance behaviors

## Quick Start

### Prerequisites

- macOS (for `osascript` notifications and `say` text-to-speech)
- [OmniFocus CLI](https://github.com/derekkinsman/omnifocus-cli) installed (`of` command)
- [Claude Code](https://code.claude.com) installed and authenticated (`claude` command)
- Optional: [Memory MCP server](https://github.com/modelcontextprotocol/servers) for pattern tracking

### Installation

```bash
# Clone the repo
git clone https://github.com/yourusername/omni-nudge.git
cd omni-nudge

# Make the script executable
chmod +x omni-nudge.sh

# Test it manually first
./omni-nudge.sh
```

### Running Automatically

The most common setup is to run this via cron during work hours:

```bash
# Edit your crontab
crontab -e

# Add this line (adjust times for your schedule):
# Every 30 minutes, 9am-4:30pm, Monday-Friday
0,30 9-16 * * 1-5 /absolute/path/to/omni-nudge.sh
```

**Important for cron**: If you're running via cron, you'll need to set environment variables:

```bash
# In your crontab, set PATH and optionally skip the confirmation dialog
0,30 9-16 * * 1-5 PATH=/usr/local/bin:/usr/bin:/bin OMNI_NUDGE_SKIP_CONFIRMATION=true /path/to/omni-nudge.sh
```

## Configuration

The script is configured via environment variables:

- `OMNI_NUDGE_LOG_FILE` - Where to write logs (default: `./omni-nudge.log`)
- `OMNI_NUDGE_END_OF_DAY` - When your work day ends (default: `16:30`)
- `OMNI_NUDGE_SKIP_CONFIRMATION` - Set to `true` to skip the confirmation dialog (default: `false`)

Example:

```bash
export OMNI_NUDGE_END_OF_DAY="17:00"
export OMNI_NUDGE_SKIP_CONFIRMATION=true
./omni-nudge.sh
```

## Customization

### Adjust the Prompt

The agent prompt is in `.claude/agents/task-enforcer.md`. Edit it to:
- Change the personality (though we recommend keeping it ruthless)
- Adjust time pressure thresholds
- Modify notification behavior
- Add or remove task perspectives

### Change Allowed Tools

The script restricts Claude to specific tools for safety. To modify:

```bash
# In omni-nudge.sh, find the --allowedTools parameter
--allowedTools "Bash(osascript:*),Bash(say:*),Bash(sleep:*),Bash(date:*),Bash(of:*),Bash(open:*),mcp__memory"
```

### Emergency Stop

If you need to kill a running audit (e.g., you're on a call):

```bash
pkill -9 say                    # Kill text-to-speech
pkill -f "omni-nudge"           # Kill the script
```

## Setup Memory MCP (Optional)

Memory MCP allows Claude to track task patterns over time:

```bash
claude mcp add --transport stdio memory -- npx -y @modelcontextprotocol/server-memory
```

Verify it's connected:

```bash
claude mcp list
# Should show: memory...Connected
```

## Troubleshooting

**No notifications appearing?**
- Enable macOS notification permissions: System Settings > Notifications > Terminal (or Script Editor)
- For persistent notifications: Change "Banners" to "Alerts"

**"of: command not found"**
- Install OmniFocus CLI: [derekkinsman/omnifocus-cli](https://github.com/derekkinsman/omnifocus-cli)

**"claude: command not found"**
- Install Claude Code: [code.claude.com](https://code.claude.com)

**Memory MCP not working?**
- Verify: `claude mcp list` shows "memory...Connected"
- Reinstall: `claude mcp add --transport stdio memory -- npx -y @modelcontextprotocol/server-memory`

**Cron not running?**
- Check cron logs: `grep CRON /var/log/system.log`
- Ensure PATH includes `of` and `claude` commands
- Check the log file: `tail -f omni-nudge.log`

## Adapting for Other Task Systems

OmniNudge is built for OmniFocus, but the approach works with any task system that has a CLI:

1. Replace `of inbox list` with your task system's equivalent
2. Replace `of perspective view "Next"` with your active tasks query
3. Adjust the prompt to match your task structure
4. Modify notification commands if not on macOS

The core value is the **prompt** and **approach** - the specific implementation is just one example.

## Philosophy

This project is based on a few beliefs:

1. **Specificity beats generality** - "Delete the freezer organizer" is more actionable than "process your inbox"
2. **Accountability beats automation** - Sometimes you need someone (or something) to call you out
3. **Interruption can be valuable** - A well-timed interruption prevents bigger problems
4. **AI excels at pattern recognition** - Claude is great at spotting when you're avoiding something
5. **Ruthless honesty works** - Gentle reminders get ignored; harsh truth gets action

## Contributing

This is a simple shell script and a powerful prompt. Contributions welcome:

- Adapters for other task systems (Things, Todoist, etc.)
- Alternative prompts (less ruthless, more encouraging, etc.)
- Notification improvements
- Better cron management

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Created by someone who needed to stop letting tasks rot in their inbox.

The real innovation here is the **prompt**, not the code. Feel free to adapt it for your own systems.
