# Taskmaster

OmniFocus task accountability system that uses Claude Code to nag you about stale tasks via system notifications and text-to-speech.

Runs via cron every 30 minutes during work hours. Uses Memory MCP to track task history and escalate urgency.

## Setup

Requires:
- [OmniFocus CLI](https://github.com/derekkinsman/omnifocus-cli) (`of` command)
- [Claude Code](https://code.claude.com) (`claude` command)
- Memory MCP server

```bash
cd ~/Repos/taskmaster

# Verify prerequisites
./dev-tools.sh check

# Test notifications and TTS
./dev-tools.sh test-alerts

# Test the nag script
./omnifocus-nag.sh

# Install cron job (runs every 30 min, 9am-5pm, Mon-Fri)
./install-cron.sh
```

## Configuration

**Change work hours**: Edit `install-cron.sh` cron schedule
**Adjust nag behavior**: Edit the prompt in `omnifocus-nag.sh`
**View logs**: `tail -f taskmaster.log`

## Troubleshooting

**No notifications?** Check macOS notification permissions for Terminal/Script Editor

**Want persistent notifications?** System Settings > Notifications > Terminal/Script Editor > Change "Banners" to "Alerts"

**Memory not working?** Verify Memory MCP: `claude mcp list` should show "memory...Connected"

## Uninstall

```bash
./uninstall-cron.sh
```
