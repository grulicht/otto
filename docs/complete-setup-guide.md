# OTTO - Complete Setup Guide

Step-by-step guide from zero to a fully working OTTO DevOps AI assistant.

## Prerequisites

Before starting, make sure you have:

1. **Claude Code CLI** installed and authenticated
   ```bash
   # Check if installed
   claude --version

   # If not, install from https://code.claude.com

2. **Required tools**
   ```bash
   # jq (required)
   sudo apt install jq        # Debian/Ubuntu
   brew install jq             # macOS

   # yq (recommended)
   sudo apt install yq         # Debian/Ubuntu
   brew install yq             # macOS

   # curl (usually pre-installed)
   curl --version
   ```

## Step 1: Download OTTO

```bash
# Clone the repository
git clone https://github.com/grulicht/otto.git
cd otto
```

## Step 2: Run the Setup Wizard

```bash
./install.sh
```

The wizard will:
1. Check prerequisites (jq, yq, curl)
2. Auto-detect your installed DevOps tools
3. Ask you to choose a permission profile:
   - **1 = beginner** (explains everything, always asks)
   - **2 = balanced** (recommended - read auto, write confirm)
   - **3 = autonomous** (maximum automation, for dev only)
   - **4 = paranoid** (everything requires approval)
4. Create your config at `~/.config/otto/`

**What gets created:**
```
~/.config/otto/
  config.yaml           # Your personal configuration
  .env                  # API tokens (edit this next)
  detected-tools.json   # What tools OTTO found on your system
  agents/               # Your custom agents (empty)
  state/                # Runtime state (auto-managed)
    tasks/              # Task queue
    memory/             # Knowledge base
    night-watch/        # Night Watcher logs
```

## Step 3: Add the CLI to PATH

```bash
# The installer creates a symlink, but verify:
which otto

# If not found, add manually:
export PATH="${HOME}/.local/bin:${PATH}"

# Make permanent (add to ~/.bashrc or ~/.zshrc):
echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> ~/.bashrc
source ~/.bashrc
```

## Step 4: Verify Installation

```bash
# Check version
otto version
# Expected: otto v0.1.0

# Check detected tools
otto detect
# Expected: list of your installed DevOps tools

# List agents
otto agents
# Expected: 23 agents listed with descriptions

# System health check
otto status
# Expected: CPU, memory, disk usage, detected tools

# Run a health check
otto check server-health
# Expected: JSON with cpu_percent, memory_percent, disk_percent
```

## Step 5: Integrate with Claude Code

OTTO works as a Claude Code plugin. There are two ways to use it:

### Option A: Use OTTO directory as your working directory

```bash
cd /path/to/otto
claude
```

Claude Code will automatically read `CLAUDE.md` and load OTTO's instructions.
You can now use skills like `/otto:status`, `/otto:check`, etc.

### Option B: Reference OTTO from any project

Add OTTO's path to Claude Code's additional directories:

```bash
# In your project's .claude/settings.json or ~/.claude/settings.json:
{
  "permissions": {
    "additionalDirectories": ["/path/to/otto"]
  }
}
```

Then start Claude Code in your project directory - it will have access to OTTO scripts.

## Step 6: Configure Integrations (Optional)

Edit `~/.config/otto/.env` with your API tokens:

```bash
# Open the env file
nano ~/.config/otto/.env
# or
code ~/.config/otto/.env
```

### Slack (for notifications)
```bash
# Create a Slack App at https://api.slack.com/apps
# Add Bot Token Scopes: chat:write, channels:read, im:read, im:write
# Install to your workspace, copy the Bot Token
OTTO_SLACK_TOKEN=xoxb-your-bot-token
OTTO_SLACK_CHANNEL_ID=C12345678
```

### Grafana (for monitoring)
```bash
# Create a Service Account token in Grafana
OTTO_GRAFANA_URL=https://grafana.example.com
OTTO_GRAFANA_TOKEN=glsa_your-token
```

### GitLab (for MR/pipeline monitoring)
```bash
OTTO_GITLAB_URL=https://gitlab.example.com
OTTO_GITLAB_TOKEN=glpat-your-token
```

### More integrations
See `.env.example` for all supported tokens (AWS, GCP, Azure, Jira, PagerDuty, etc.)

## Step 7: Test Everything Works

### Test CLI commands
```bash
# Basic health
otto status

# Run all available checks (skips tools you don't have)
otto check all

# If you have kubectl configured:
otto check kubernetes

# If you have Docker running:
otto check docker

# If you have Terraform projects:
otto check terraform

# SSL certificate check (set domains first):
export OTTO_SSL_DOMAINS="example.com,api.example.com"
otto check ssl-certs
```

### Test Claude Code skills
```bash
# Start Claude Code in the OTTO directory
cd /path/to/otto
claude

# Inside Claude Code, try these skills:
/otto:status
/otto:check server-health
/otto:knowledge kubernetes best practices
/otto:compliance
/otto:troubleshoot high CPU usage
```

### Test action scripts (dry-run mode - nothing changes)
```bash
# Deploy (dry run)
bash scripts/actions/deploy.sh \
  --target my-app --environment staging --version v1.0 --dry-run

# Rollback (dry run)
bash scripts/actions/rollback.sh \
  --target my-app --environment staging --dry-run

# Scale (dry run)
bash scripts/actions/scale.sh \
  --target my-app --replicas 3 --environment dev --dry-run

# Backup (dry run)
bash scripts/actions/backup-create.sh \
  --target /data --type restic --dry-run

# Certificate renewal (dry run)
bash scripts/actions/cert-renew.sh \
  --domain example.com --dry-run

# Incident creation (dry run)
bash scripts/actions/incident-create.sh \
  --title "Test incident" --severity low --description "Testing OTTO" --dry-run
```

### Test Night Watcher
```bash
# Check if Night Watcher would start now based on schedule:
bash scripts/core/night-watcher.sh should-start

# Manually start Night Watcher (will monitor until you stop):
otto watch

# In another terminal, check status:
otto status
# Night Watcher should show: ACTIVE

# Stop Night Watcher and generate report:
otto unwatch

# View morning report:
otto morning
```

### Test Knowledge Engine
```bash
# Search for a topic
bash scripts/core/knowledge-engine.sh search "kubernetes crashloopbackoff"

# List all topics
bash scripts/core/knowledge-engine.sh topics

# Get best practices for a domain
bash scripts/core/knowledge-engine.sh best-practices kubernetes
```

### Test Dashboard
```bash
# Generate terminal dashboard
bash scripts/core/dashboard.sh terminal

# Generate HTML dashboard
bash scripts/core/dashboard.sh html
# Opens state/dashboard.html

# Start web server for dashboard (optional)
bash scripts/core/web-server.sh start 8080
# Visit http://localhost:8080
```

## Step 8: Customize for Your Workflow

### Adjust permissions
```bash
# Edit your config
nano ~/.config/otto/config.yaml
```

Key sections to customize:
```yaml
# Your role (affects recommendations)
user:
  role: devops_engineer  # or: sre, developer, student

# Per-environment permissions
permissions:
  environments:
    production:
      default: suggest     # Always ask in production
      destructive: deny    # Never auto-destroy in production

# Night Watcher schedule
night_watcher:
  enabled: true
  schedule:
    start: "22:00"
    end: "07:00"
    timezone: "Europe/Prague"  # Your timezone
```

### Add custom agents
```bash
# Copy the template
cp agents/custom/_template.md ~/.config/otto/agents/my-agent.md

# Edit with your custom logic
nano ~/.config/otto/agents/my-agent.md
```

### Set up scheduled checks
```yaml
# Add to ~/.config/otto/config.yaml:
scheduled_checks:
  - name: ssl-weekly
    cron: "0 9 * * 1"
    check: ssl-certs
    alert_if: "days_remaining < 30"
  - name: backup-daily
    cron: "0 7 * * *"
    check: backup-status
    alert_if: "last_backup_age_hours > 24"
```

## Step 9: Team Setup (Optional)

For team use, see [docs/examples/team-setup.md](examples/team-setup.md).

Quick version:
```bash
# Initialize team config
bash scripts/core/team.sh init "My DevOps Team"

# Edit team config
nano ~/.config/otto/team/config.yaml

# Sync team knowledge
bash scripts/core/team.sh sync
```

## Troubleshooting

### "otto: command not found"
```bash
# Check symlink
ls -la ~/.local/bin/otto

# Re-create if missing
ln -sf /path/to/otto/otto ~/.local/bin/otto

# Verify PATH
echo $PATH | grep '.local/bin'
```

### "jq: command not found"
```bash
sudo apt install jq   # Debian/Ubuntu
brew install jq        # macOS
```

### Fetch scripts return empty JSON
The tool isn't installed or the env token isn't set. Check:
```bash
# Is the tool installed?
which kubectl  # or terraform, docker, etc.

# Are tokens set?
cat ~/.config/otto/.env | grep -v '^#' | grep -v '^$'
```

### Claude Code doesn't see OTTO skills
Make sure you're running Claude Code from the OTTO directory:
```bash
cd /path/to/otto
claude
```
Or add OTTO as an additional directory in Claude Code settings.

### Night Watcher doesn't start automatically
Check your schedule configuration:
```bash
bash scripts/core/night-watcher.sh should-start
# If "false", check timezone and schedule in config.yaml
```

## Quick Reference Card

```bash
# Health & Status
otto status                  # System overview
otto check all               # All health checks
otto check kubernetes        # Specific check
otto detect                  # Detect tools

# Night Watcher
otto watch                   # Start monitoring
otto unwatch                 # Stop monitoring
otto morning                 # Morning report

# Tasks
otto task "Fix SSL cert"     # Create task
otto tasks                   # List all tasks

# Config
otto config                  # Show config
otto config set .key value   # Update config
otto agents                  # List agents
otto permissions             # Permission summary

# Claude Code Skills
/otto:status                 # Health overview
/otto:check [target]         # Health check
/otto:deploy app env ver     # Deploy
/otto:troubleshoot symptom   # Diagnose
/otto:incident title         # Create incident
/otto:compliance             # Audit
/otto:knowledge topic        # Search KB
/otto:review                 # Code review
/otto:watch                  # Night Watcher
/otto:morning                # Briefing
```
