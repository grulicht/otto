---
name: datadog
description: Datadog monitoring platform via REST API for metrics, logs, and alerts
type: api
required_env:
  - OTTO_DATADOG_API_KEY
  - OTTO_DATADOG_APP_KEY
required_tools:
  - curl
  - jq
check_command: "curl -sf 'https://api.datadoghq.com/api/v1/validate' -H 'DD-API-KEY: ${OTTO_DATADOG_API_KEY}' | jq -r '.valid'"
---

# Datadog

## Connection

OTTO connects to Datadog through the REST API using an API key and Application key.
Set `OTTO_DATADOG_SITE` if using a non-US site (e.g., `datadoghq.eu`).

```bash
DATADOG_SITE="${OTTO_DATADOG_SITE:-datadoghq.com}"
curl -sf "https://api.${DATADOG_SITE}/api/v1/<endpoint>" \
  -H "DD-API-KEY: ${OTTO_DATADOG_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${OTTO_DATADOG_APP_KEY}"
```

## Available Data

- **Metrics**: Query time-series metrics, list metric names
- **Monitors**: List, create, and manage monitors/alerts
- **Events**: Post and query events
- **Logs**: Search and analyze log data
- **Dashboards**: List and manage dashboards
- **Hosts**: List infrastructure hosts and tags
- **Synthetics**: API and browser test results
- **SLOs**: Service Level Objective tracking

## Common Queries

### List triggered monitors
```bash
curl -sf "https://api.${DATADOG_SITE}/api/v1/monitor?monitor_tags=team:ops&group_states=alert,warn" \
  -H "DD-API-KEY: ${OTTO_DATADOG_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${OTTO_DATADOG_APP_KEY}" | \
  jq '.[] | {id, name, overall_state, message}'
```

### Query metrics
```bash
curl -sf "https://api.${DATADOG_SITE}/api/v1/query?from=$(date -d '1 hour ago' +%s)&to=$(date +%s)&query=avg:system.cpu.user{*}" \
  -H "DD-API-KEY: ${OTTO_DATADOG_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${OTTO_DATADOG_APP_KEY}" | \
  jq '.series[0].pointlist[-5:]'
```

### Search logs
```bash
curl -sf -X POST "https://api.${DATADOG_SITE}/api/v2/logs/events/search" \
  -H "DD-API-KEY: ${OTTO_DATADOG_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${OTTO_DATADOG_APP_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filter":{"query":"status:error","from":"now-1h","to":"now"},"page":{"limit":20}}' | \
  jq '.data[] | {timestamp: .attributes.timestamp, message: .attributes.message}'
```

### List hosts
```bash
curl -sf "https://api.${DATADOG_SITE}/api/v1/hosts?count=50" \
  -H "DD-API-KEY: ${OTTO_DATADOG_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${OTTO_DATADOG_APP_KEY}" | \
  jq '.host_list[] | {name: .host_name, up: .is_muted_count, apps: .apps}'
```
