# Beginner Setup Example

This guide shows how to set up OTTO if you're new to DevOps.

## Step 1: Install

```bash
git clone https://github.com/grulicht/otto.git
cd otto
./install.sh
# Choose profile: 1 (beginner)
```

## Step 2: What Happens

The setup wizard:
- Detects what tools you have installed
- Creates your config with beginner profile (OTTO explains everything)
- Creates the config directory at ~/.config/otto/

## Step 3: Explore

```bash
# See what OTTO can help with
otto help

# See what tools OTTO detected
otto detect

# See what agents are available
otto agents

# Check your system health
otto status
```

## Step 4: Ask OTTO for Help

In Claude Code, OTTO can help you with common DevOps tasks:

- "How do I create a Dockerfile for my Node.js app?"
- "Help me set up a GitLab CI pipeline"
- "What's wrong with my Kubernetes pod?"
- "Review my terraform configuration"

OTTO will explain each step and ask before making any changes.

## Step 5: Add Integrations (Optional)

Edit `~/.config/otto/.env` to connect OTTO to your tools:
- Grafana for monitoring dashboards
- Slack for notifications
- GitLab/GitHub for code management

## Tips for Beginners

- OTTO in beginner mode will explain every command before running it
- All destructive actions are disabled by default
- You can ask OTTO to explain any DevOps concept
- Check the knowledge base in `knowledge/` for best practices
