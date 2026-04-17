# Team Setup Example

Set up OTTO for a DevOps team with shared configuration.

## Step 1: Shared Configuration

Create a team config file that everyone uses:

```yaml
# team-config.yaml (commit this to your team repo)
user:
  experience_level: auto
  role: devops_engineer

permissions:
  default_mode: balanced
  environments:
    production:
      default: suggest
      destructive: deny

communication:
  primary: slack
  channels:
    slack:
      enabled: true

night_watcher:
  enabled: true
  schedule:
    start: "22:00"
    end: "07:00"
    timezone: "Europe/Prague"
```

## Step 2: Individual Setup

Each team member:

```bash
# Install OTTO
git clone https://github.com/grulicht/otto.git
cd otto
./install.sh

# Copy team config
cp /path/to/team-config.yaml ~/.config/otto/config.yaml

# Add personal tokens
vim ~/.config/otto/.env
```

## Step 3: Shared Knowledge Base

Place team-specific runbooks and knowledge in:
- `~/.config/otto/knowledge/` for team-wide knowledge
- Or commit to your team repo and symlink

## Step 4: Team Communication

Set up a shared Slack channel for OTTO notifications:
- Morning briefings go to #devops-otto
- Critical alerts go to individual DMs
- Triage items posted for team review

## Step 5: Custom Agents

Create team-specific agents for your workflows:
- Deployment procedures specific to your stack
- Custom health checks for your services
- Company-specific compliance rules
