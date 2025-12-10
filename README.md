# OmniNudge

**A ruthless task accountability system powered by Claude Code.**

## How It Works

1. Fetches OmniFocus tasks (Inbox + Next perspective)
2. Sends snapshot to Claude Code with a [ruthless enforcement agent](.claude/agents/task-enforcer.md)
3. Claude analyzes task ages, patterns, and time pressure
4. Delivers **specific** actions via notification and text-to-speech

The secret sauce is the **agent prompt** ([task-enforcer.md](.claude/agents/task-enforcer.md)) - brutally honest, highly specific, and action-oriented. It tells you "Delete the freezer organizer task" not "process your inbox".

**Key features**: Specificity, escalation for repeat offenders, time pressure urgency, multi-modal delivery (visual + audio), pattern tracking via Memory MCP.

## Quick Start

### Prerequisites

- macOS (for `osascript` notifications and `say` text-to-speech)
- [OmniFocus CLI](https://github.com/derekkinsman/omnifocus-cli) (`of` command)
- [Claude Code](https://code.claude.com) installed and authenticated (`claude` command)
- `jq` for JSON processing: `brew install jq`
- `terminal-notifier` for notifications: `brew install terminal-notifier`
- Optional: [Memory MCP server](https://github.com/modelcontextprotocol/servers) for pattern tracking

### Installation

```bash
# Clone the repo
git clone https://github.com/stephendolan/omni-nudge.git
cd omni-nudge

# Make the script executable
chmod +x omni-nudge.sh

# Test it manually first
./omni-nudge.sh
```

### Running Automatically

Run via cron during work hours. Edit your crontab:

```bash
crontab -e
```

Add this line (every 30 minutes, 9am-4:30pm, Monday-Friday):

```bash
0,30 9-16 * * 1-5 PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin OMNI_NUDGE_SKIP_CONFIRMATION=true /path/to/omni-nudge/omni-nudge.sh
```

**Important**:
- Replace `/path/to/omni-nudge/omni-nudge.sh` with the absolute path to your script
- Set `PATH` to include where `of`, `claude`, `jq`, and `terminal-notifier` are installed
- Set `OMNI_NUDGE_SKIP_CONFIRMATION=true` to avoid dialog prompts in automated runs
- Use `which of` and `which claude` to verify your PATH includes the correct directories

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

**Edit the agent prompt** (`.claude/agents/task-enforcer.md`) to adjust personality, time pressure thresholds, or notification behavior.

**Change allowed tools** by modifying the `--allowedTools` parameter in `omni-nudge.sh`.

**Emergency stop** (e.g., you're on a call):
```bash
pkill -9 say              # Kill text-to-speech
pkill -f "omni-nudge"     # Kill the script
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

## Improving Voice Quality

macOS uses a default text-to-speech voice, but you can download higher-quality voices for better clarity:

1. Open **System Settings > Accessibility > Spoken Content**
2. Click **System Voice > Manage Voices...**
3. Download **Samantha (Enhanced)** or other premium voices
4. Select your preferred voice in the System Voice dropdown

Enhanced voices sound significantly more natural and are easier to understand.

## Troubleshooting

**No notifications appearing?**
- Enable macOS notification permissions: System Settings > Notifications > Terminal
- For persistent notifications: Change "Banners" to "Alerts"

**"of: command not found"**
- Install OmniFocus CLI: [derekkinsman/omnifocus-cli](https://github.com/derekkinsman/omnifocus-cli)

**"claude: command not found"**
- Install Claude Code: [code.claude.com](https://code.claude.com)

**"terminal-notifier: command not found"**
- Install via Homebrew: `brew install terminal-notifier`

**Memory MCP not working?**
- Verify: `claude mcp list` shows "memory...Connected"
- Reinstall: `claude mcp add --transport stdio memory -- npx -y @modelcontextprotocol/server-memory`

**Cron not running?**
- Check the log file: `tail -f ~/Repos/omni-nudge/omni-nudge.log`
- Verify PATH includes `of`, `claude`, `jq`, and `terminal-notifier`: Run `which of` and `which claude`
- Test manually first: Run the script directly to ensure it works

## Adapting for Other Task Systems

OmniNudge is built for OmniFocus, but works with any task system that has a CLI. Replace `of` commands with your task system's equivalent, adjust the prompt, and modify notification commands if not on macOS.

The core value is the **prompt** and **approach** - the implementation is adaptable.

## Contributing

Contributions welcome: adapters for other task systems, alternative prompts, notification improvements.

## License

MIT License - see [LICENSE](LICENSE) for details.
