---
name: watch
description: Activate Night Watcher mode for overnight monitoring
user-invocable: true
---

# OTTO Night Watcher Activation

Configure and activate OTTO's Night Watcher mode for overnight monitoring.

## Steps

1. Run `./otto watch` to activate Night Watcher mode
2. Verify the heartbeat mode switches to "night"
3. Explain what will be monitored based on the current configuration

## What Gets Monitored

When Night Watcher is active, OTTO checks these on a 15-30 minute interval:

- **Monitoring alerts** - Prometheus/Grafana alerts (every tick)
- **Communication inbox** - Slack/email notifications (every tick)
- **CI/CD pipelines** - Build/deploy status (every 3 ticks)
- **Kubernetes pods** - Pod health and restarts (every 3 ticks)
- **System health** - CPU, memory, disk (every 6 ticks)
- **Database health** - Connection pools, replication lag (every 6 ticks)
- **Security events** - Auth failures, suspicious activity (every 6 ticks)

## Escalation

Critical alerts are escalated immediately via the configured notification channel.
Non-critical issues are collected for the morning briefing.

## Deactivation

Night Watcher stops automatically at the configured wakeup time, or manually with `./otto unwatch`.
After deactivation, a morning report is generated summarizing the night.
