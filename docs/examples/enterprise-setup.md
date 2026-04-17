# Enterprise Setup Guide

This guide covers deploying OTTO for a team or organization with shared
configuration, role-based access, centralized knowledge, and compliance features.

## Prerequisites

- OTTO installed on each team member's machine
- A shared Git repository for team configuration
- Communication channels set up (Slack, Telegram, etc.)
- Optional: PagerDuty or OpsGenie for on-call management

## 1. Shared Team Configuration via Git

Store your team configuration in a Git repository so all members share the
same base settings.

```bash
# Create a team config repository
mkdir devops-otto-config && cd devops-otto-config
git init

# Create the team config file
cat > team-config.yaml <<'EOF'
team:
  name: "Platform Engineering"
  members:
    - name: "Alice"
      email: "alice@company.com"
      role: admin
      slack_id: "U12345"
    - name: "Bob"
      email: "bob@company.com"
      role: engineer
      slack_id: "U67890"
    - name: "Carol"
      email: "carol@company.com"
      role: junior
      slack_id: "U11111"
  oncall:
    type: pagerduty
    pagerduty_schedule_id: "PXXXXXX"
  shared_knowledge:
    type: git
    repo: "git@github.com:company/devops-knowledge.git"
    path: "knowledge/"
  notification:
    team_channel: "#platform-eng"
    incident_channel: "#incidents"
EOF

git add team-config.yaml
git commit -m "Initial team configuration"
git remote add origin git@github.com:company/otto-config.git
git push -u origin main
```

Each team member points OTTO to the shared config:

```yaml
# ~/.config/otto/config.yaml
team:
  config_path: "/path/to/devops-otto-config/team-config.yaml"
```

## 2. Role-Based Access Control

OTTO supports four roles with different permission levels:

| Role     | Read | Write    | Destructive | Team Config |
|----------|------|----------|-------------|-------------|
| admin    | auto | auto     | confirm     | full access |
| engineer | auto | confirm  | confirm     | no access   |
| viewer   | auto | deny     | deny        | no access   |
| junior   | auto | suggest  | deny        | no access   |

Assign roles in the team configuration. Each member's role determines what
actions OTTO will allow them to perform.

Admins can override permissions for specific members:

```yaml
team:
  members:
    - name: "Bob"
      role: engineer
      overrides:
        kubernetes.delete: confirm  # Allow with confirmation instead of deny
```

## 3. Centralized Knowledge Base

Store runbooks, playbooks, and operational knowledge in a shared Git repository:

```bash
# Initialize team knowledge sync
otto team sync-knowledge

# Create a shared runbook
otto team create-runbook "database-failover" <<'EOF'
# Database Failover Procedure

1. Verify primary is down: `pg_isready -h primary-db`
2. Promote replica: `pg_ctl promote -D /var/lib/postgresql/data`
3. Update DNS: `aws route53 change-resource-record-sets ...`
4. Notify team: `otto team notify "Database failover complete"`
5. Update monitoring: silence primary alerts
EOF
```

## 4. On-Call Integration

### PagerDuty

```yaml
team:
  oncall:
    type: pagerduty
    pagerduty_schedule_id: "PXXXXXX"
```

Set the API key:
```bash
echo "OTTO_PAGERDUTY_API_KEY=your-key-here" >> ~/.config/otto/.env
```

### OpsGenie

```yaml
team:
  oncall:
    type: opsgenie
    opsgenie_schedule_id: "schedule-uuid"
```

### Manual Schedule

```yaml
team:
  oncall:
    type: schedule
    schedule:
      - name: "Alice"
        start: "monday"
        end: "friday"
      - name: "Bob"
        start: "friday"
        end: "monday"
```

## 5. Compliance Requirements

Enable audit logging for all actions:

```yaml
audit:
  enabled: true
  log_all_actions: true
  compliance_mode: true
```

Generate compliance reports:

```bash
# Daily audit summary
otto audit summary daily

# Export audit log as CSV for review
otto audit export csv "2024-01-01T00:00:00Z" "2024-02-01T00:00:00Z" > audit-january.csv

# Full compliance report
otto audit compliance-report > compliance-report.txt
```

## 6. Multi-Environment Setup

Configure different permission levels per environment:

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

Set the current environment in your shell:

```bash
export OTTO_ENVIRONMENT=production
```

Or per-project in the project's `.otto.yaml`:

```yaml
environment: staging
```

## 7. Audit Logging

All team member actions are logged to `~/.config/otto/state/audit.jsonl`:

```json
{"ts":"2024-01-15T10:30:00Z","actor":"alice","action":"deploy","target":"myapp","environment":"production","details":"Deployed v1.2.3","result":"success","permission_level":"suggest"}
```

Search and filter audit entries:

```bash
# Find all production deploys
otto audit search '{"action":"deploy","environment":"production"}'

# Find denied actions (potential policy violations)
otto audit search '{"result":"denied"}'

# Export weekly report
otto audit summary weekly
```

## 8. Cost Management

Track infrastructure costs by tagging OTTO-initiated changes:

```yaml
audit:
  tag_actions: true
  cost_tracking:
    enabled: true
    budget_alerts:
      - threshold: 80
        notify: team_channel
      - threshold: 95
        notify: incident_channel
```

## Quick Start Checklist

1. [ ] Create shared team config repository
2. [ ] Define team members and roles
3. [ ] Configure on-call integration
4. [ ] Set up shared knowledge repository
5. [ ] Configure notification channels
6. [ ] Enable audit logging
7. [ ] Set environment-specific permissions
8. [ ] Use `team-default` profile: `OTTO_PROFILE=team-default`
9. [ ] Run `otto team init "Your Team Name"` on each machine
10. [ ] Verify with `otto team dashboard`
