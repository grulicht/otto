# Configuration Reference

OTTO uses a layered configuration system:

1. `config/default.yaml` - Built-in defaults (shipped with OTTO)
2. `config/profiles/*.yaml` - Permission profiles
3. `~/.config/otto/config.yaml` - User overrides (takes precedence)
4. `~/.config/otto/.env` - Secrets and tokens

## User Profile

```yaml
user:
  experience_level: auto    # beginner | intermediate | advanced | expert | auto
  role: devops_engineer     # devops_engineer | sre | platform_engineer | developer |
                            # sysadmin | security_engineer | manager | student
  preferred_tools:
    iac: terraform          # terraform | opentofu | ansible
    cicd: github_actions    # gitlab_ci | github_actions | jenkins | argocd | bitbucket
    containers: kubernetes  # kubernetes | docker_compose | podman
    monitoring: grafana     # grafana | zabbix | datadog | elk | newrelic
    communication: slack    # slack | telegram | rocketchat | teams | discord | email
```

## Permissions

### Permission Levels

| Level | Behavior |
|-------|----------|
| `deny` | Action is forbidden - OTTO will not perform or suggest it |
| `suggest` | OTTO proposes the action and waits for explicit approval |
| `confirm` | OTTO asks "Proceed? [Y/n]" before executing |
| `auto` | OTTO executes automatically and reports the result |

### Per-Environment

```yaml
permissions:
  environments:
    development:
      default: auto
    staging:
      default: confirm
    production:
      default: suggest
      destructive: deny
```

### Per-Domain

See `config/default.yaml` for the complete list of domain-specific permissions.

## Communication

```yaml
communication:
  primary: slack    # Primary channel for reports
  channels:
    slack:
      enabled: true
    telegram:
      enabled: false
    # ... other channels
```

Tokens are stored in `~/.config/otto/.env` (see `.env.example`).

## Night Watcher

```yaml
night_watcher:
  enabled: true
  schedule:
    start: "22:00"
    end: "07:00"
    timezone: "Europe/Prague"
  heartbeat_interval: 900
  morning_report:
    format: detailed    # brief | detailed | executive
```

See [night-watcher.md](night-watcher.md) for the full reference.

## Heartbeat

```yaml
heartbeat:
  interval: 600        # Base interval (seconds)
  adaptive: true       # Enable adaptive intervals
  min_interval: 300    # Minimum (active mode)
  max_interval: 3600   # Maximum (idle mode)
```

## Logging

```yaml
logging:
  level: info          # debug | info | warn | error
  format: json         # json | human
  max_size_mb: 50
  rotate: true
```
