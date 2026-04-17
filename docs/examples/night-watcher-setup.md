# Night Watcher Setup Guide

The Night Watcher is OTTO's overnight monitoring mode. When activated, it
continuously checks your infrastructure, escalates critical issues, and
generates a comprehensive morning report.

## Basic Configuration

Enable Night Watcher in your config:

```yaml
# ~/.config/otto/config.yaml
night_watcher:
  enabled: true
  interval: 900          # Check every 15 minutes (seconds)
  quiet_hours:
    start: "22:00"
    end: "07:00"
    timezone: "Europe/Prague"
```

Start the watcher:

```bash
otto watch
```

## Communication Channel Setup

Configure where Night Watcher sends alerts and reports:

```yaml
night_watcher:
  communication:
    # Primary alert channel
    alert_channel: "#ops-alerts"
    # Morning report destination
    report_channel: "#devops-team"
    # Direct message for critical alerts
    dm_oncall: true
```

### Slack

```yaml
communication:
  channels:
    slack:
      enabled: true
      token_env: "OTTO_SLACK_TOKEN"
      default_channel: "#ops-alerts"
```

### Telegram

```yaml
communication:
  channels:
    telegram:
      enabled: true
      token_env: "OTTO_TELEGRAM_TOKEN"
      chat_id_env: "OTTO_TELEGRAM_CHAT_ID"
```

## Alert Escalation Configuration

Define how alerts escalate based on severity and duration:

```yaml
night_watcher:
  escalation:
    enabled: true
    levels:
      # Level 1: Notify the team channel
      - severity: warning
        delay: 0           # Immediate
        notify:
          - team_channel

      # Level 2: Notify on-call after 5 minutes
      - severity: high
        delay: 300
        notify:
          - team_channel
          - oncall

      # Level 3: Critical - immediate on-call + incident channel
      - severity: critical
        delay: 0
        notify:
          - incident_channel
          - oncall
          - team_channel

    # Re-alert interval for unacknowledged alerts
    repeat_interval: 1800  # 30 minutes
```

## Auto-Remediation Setup

Allow Night Watcher to automatically fix known issues:

```yaml
night_watcher:
  auto_remediation:
    enabled: true
    # Only auto-remediate with these permission levels
    max_permission: confirm
    rules:
      # Restart crashed pods
      - trigger: "pod_crash_loop"
        action: "kubectl rollout restart"
        max_retries: 2
        cooldown: 600      # 10 minutes between retries

      # Scale up on high CPU
      - trigger: "high_cpu_utilization"
        condition: "cpu > 90% for 10m"
        action: "scale_up"
        max_replicas: 10

      # Clear disk space
      - trigger: "disk_space_low"
        condition: "disk_usage > 90%"
        action: "cleanup_logs"
        retain_days: 7

      # Restart unresponsive services
      - trigger: "health_check_failed"
        condition: "consecutive_failures > 3"
        action: "service_restart"
        max_retries: 1
```

## Morning Report Customization

Configure what appears in the morning report:

```yaml
night_watcher:
  morning_report:
    enabled: true
    # When to generate (local time)
    time: "07:00"
    timezone: "Europe/Prague"
    # Report sections
    sections:
      - system_health        # Overall health status
      - alerts_summary       # Alerts that fired overnight
      - remediation_log      # Auto-remediation actions taken
      - resource_usage       # CPU, memory, disk trends
      - deployment_status    # Any deployments that happened
      - cost_summary         # Infrastructure cost changes
      - recommendations      # OTTO's suggestions
    # Report format
    format: "markdown"       # markdown | plain | html
    # Where to send it
    destinations:
      - channel: "#devops-team"
      - channel: "oncall_dm"
```

## Schedule Configuration

Run Night Watcher on a schedule instead of manually:

```yaml
night_watcher:
  schedule:
    enabled: true
    # Cron expression: weekdays 10 PM to 7 AM
    start_cron: "0 22 * * 1-5"
    stop_cron: "0 7 * * 2-6"
    # Weekend: full 24h coverage
    weekend_mode: true
    weekend_start: "friday 18:00"
    weekend_end: "monday 07:00"
```

Or use systemd for automatic start:

```bash
# Create systemd timer (otto installs this during setup)
otto watch --install-service

# Check service status
systemctl --user status otto-night-watcher.timer
```

## Integration with On-Call Schedule

Connect Night Watcher to your team's on-call rotation:

```yaml
night_watcher:
  oncall_integration:
    enabled: true
    # Source of on-call data
    source: pagerduty       # pagerduty | opsgenie | schedule | manual
    # Behavior
    notify_oncall_on_critical: true
    notify_oncall_on_remediation_failure: true
    # Handoff: send summary to incoming on-call person
    handoff_report: true
```

When integrated with the team configuration:

```yaml
team:
  oncall:
    type: pagerduty
    pagerduty_schedule_id: "PXXXXXX"

night_watcher:
  oncall_integration:
    enabled: true
    source: team_config     # Use team.oncall settings
```

## Monitoring Targets

Configure what Night Watcher monitors:

```yaml
night_watcher:
  monitors:
    # Kubernetes cluster health
    kubernetes:
      enabled: true
      namespaces: ["production", "staging"]
      checks:
        - pod_status
        - node_health
        - resource_quotas
        - ingress_health

    # Infrastructure
    infrastructure:
      enabled: true
      checks:
        - server_health
        - disk_usage
        - certificate_expiry
        - dns_resolution

    # Application health
    applications:
      enabled: true
      endpoints:
        - url: "https://app.company.com/health"
          interval: 300
          timeout: 10
        - url: "https://api.company.com/health"
          interval: 300
          timeout: 10

    # Database
    database:
      enabled: true
      checks:
        - replication_lag
        - connection_count
        - slow_queries
        - backup_status
```

## Quick Start

```bash
# 1. Set the team-default profile
export OTTO_PROFILE=team-default

# 2. Configure communication
otto config set .communication.channels.slack.enabled true

# 3. Start Night Watcher
otto watch

# 4. Check status
otto watch --status

# 5. Get morning report manually
otto morning
```
