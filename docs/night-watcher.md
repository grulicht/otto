# Night Watcher

Night Watcher is OTTO's overnight monitoring mode. When activated, OTTO
monitors your systems while you sleep and delivers a comprehensive
morning report when you wake up.

## Activation

```bash
# Start Night Watcher
otto watch

# Or use natural language in chat
"otto good night"
"otto watch the systems tonight"
```

## What It Monitors

- **System health** - CPU, memory, disk usage trends
- **Monitoring alerts** - from Grafana, Prometheus, Zabbix, Datadog, etc.
- **CI/CD pipelines** - build/deploy status, failures
- **Kubernetes** - pod health, restart counts, resource pressure
- **Security events** - failed logins, vulnerability alerts, Wazuh alerts
- **Database health** - connections, replication lag, slow queries
- **SSL certificates** - expiration warnings
- **Backup status** - last backup success/failure
- **Log anomalies** - unusual error patterns

## Morning Report

The morning report (`otto morning`) contains:

1. **Executive Summary** - overall status (OK/WARN/CRIT), alert count
2. **System Health Overview** - per-server/cluster status, resource trends
3. **Deployments & Changes** - what deployed overnight, pipeline results
4. **Security Events** - failed logins, vulnerability alerts, cert warnings
5. **Action Items** - what needs attention NOW vs. what can wait
6. **Trends & Insights** - week-over-week comparison, predictions

## Configuration

```yaml
night_watcher:
  enabled: true
  schedule:
    start: "22:00"       # When to start night mode
    end: "07:00"         # When to generate morning report
    timezone: "Europe/Prague"
  heartbeat_interval: 900  # Check every 15 minutes

  checks:
    system_health: true
    monitoring_alerts: true
    cicd_pipelines: true
    kubernetes_pods: true
    security_events: true
    database_health: true
    ssl_certificates: true
    backup_status: true
    log_anomalies: true

  critical_escalation:
    enabled: true
    cooldown: 1800       # 30 min between escalations

  auto_remediation:
    enabled: false       # Must be explicitly enabled
    allowed_actions:
      - restart_crashed_pods
      - clear_disk_space_temp
      - rotate_logs

  morning_report:
    format: detailed     # brief | detailed | executive
    include_trends: true
    include_predictions: true
```

## Critical Escalation

For critical alerts during the night, OTTO can send immediate notifications
through your configured communication channels. This respects the `cooldown`
setting to prevent alert fatigue.

## Auto-Remediation

When enabled, OTTO can take limited automatic actions during the night:

- Restart crashed Kubernetes pods
- Clear temporary files to free disk space
- Rotate logs that are filling up disk

Auto-remediation respects the permission system. Destructive actions are
never performed automatically regardless of this setting.
