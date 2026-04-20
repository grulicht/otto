# Getting Started with OTTO

## What is OTTO?

OTTO (Operations & Technology Toolchain Orchestrator) is an AI DevOps assistant
that runs as a Claude Code plugin. It acts as an experienced DevOps engineer
by your side - helping you manage infrastructure, CI/CD pipelines, monitoring,
security, databases, and more.

## Installation

### Prerequisites

- [Claude Code](https://code.claude.com) CLI installed and configured
- `jq` installed (`sudo apt install jq` / `brew install jq`)
- `yq` installed (optional but recommended: `brew install yq`)

### Option 1: Claude Code Plugin (recommended)

```bash
claude plugin marketplace add https://github.com/grulicht/otto
claude plugin install otto@otto
```

### Option 2: Manual Installation

```bash
git clone https://github.com/grulicht/otto.git
cd otto
./install.sh
```

The setup wizard will:

1. Check prerequisites (jq, yq, curl)
2. Detect your installed DevOps tools
3. Let you choose a permission profile
4. Create your configuration at `~/.config/otto/`

## First Steps

### 1. Configure your tools

Edit `~/.config/otto/.env` and add tokens for your tools:

```bash
# Slack
OTTO_SLACK_TOKEN=xoxb-your-token
OTTO_SLACK_CHANNEL_ID=C12345

# Grafana
OTTO_GRAFANA_URL=https://grafana.example.com
OTTO_GRAFANA_TOKEN=your-token
```

### 2. Customize permissions

Edit `~/.config/otto/config.yaml` to adjust permissions for your workflow.
See [configuration.md](configuration.md) for details.

### 3. Start using OTTO

```bash
otto help       # See available commands
otto agents     # List available agents
otto status     # Check system health
otto morning    # Get morning briefing (requires communication setup)
```

## Permission Profiles

Choose the profile that matches your comfort level:

- **beginner** - OTTO explains everything and always asks before acting
- **balanced** - Read operations are automatic, writes need confirmation
- **autonomous** - Maximum automation (recommended for dev environments only)
- **paranoid** - Everything requires explicit approval

## Adding Custom Agents

Create a `.md` file in `~/.config/otto/agents/` following the template
in `agents/custom/_template.md`. OTTO will automatically discover it.

## Next Steps

- [Configuration Reference](configuration.md)
- [Agent Documentation](agents.md)
- [Night Watcher Setup](night-watcher.md)
- [Integration Guides](integrations/)
