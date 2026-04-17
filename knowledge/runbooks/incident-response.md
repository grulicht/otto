# Incident Response Runbook

## Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| SEV1 | Critical - service down | Immediate | Production outage, data loss |
| SEV2 | Major - degraded service | 15 minutes | High latency, partial outage |
| SEV3 | Minor - limited impact | 1 hour | Non-critical feature broken |
| SEV4 | Low - cosmetic/minor | Next business day | UI glitch, minor bug |

## Response Steps

### 1. Acknowledge
- Acknowledge the alert in monitoring system
- Notify the team via primary communication channel
- Assign incident commander

### 2. Assess
- Determine severity level
- Identify affected services and users
- Check recent deployments and changes
- Review monitoring dashboards and logs

### 3. Diagnose
- Check system health (CPU, memory, disk, network)
- Review application logs for errors
- Check database connectivity and performance
- Verify external dependency status
- Review recent changes (deployments, config changes)

### 4. Mitigate
- If caused by a recent deployment: rollback
- If resource exhaustion: scale up or restart
- If dependency failure: enable fallback/circuit breaker
- If security incident: isolate affected systems
- Communicate status updates regularly

### 5. Resolve
- Apply the fix
- Verify service recovery
- Monitor for recurrence
- Update status page

### 6. Post-Mortem
- Document timeline of events
- Identify root cause
- List contributing factors
- Define action items to prevent recurrence
- Share with the team
