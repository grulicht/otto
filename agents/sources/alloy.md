---
name: alloy
description: Grafana Alloy telemetry collector for metrics, logs, traces, and profiles
type: api
required_env: []
required_tools:
  - curl
  - jq
check_command: "curl -sf 'http://localhost:12345/-/ready'"
---

# Grafana Alloy

## Connection

OTTO connects to Grafana Alloy through its built-in HTTP API, which exposes
component status, configuration, and health information.

Default API address is `http://localhost:12345`. Set `OTTO_ALLOY_URL` to override.

```bash
ALLOY_URL="${OTTO_ALLOY_URL:-http://localhost:12345}"
curl -sf "${ALLOY_URL}/<endpoint>"
```

## Available Data

- **Components**: List running components and their health
- **Graph**: Component dependency graph
- **Clustering**: Cluster peers and state (when clustering is enabled)
- **Configuration**: Current Alloy configuration
- **Metrics**: Internal Alloy metrics (Prometheus format)

## Common Queries

### Check readiness
```bash
curl -sf "${ALLOY_URL}/-/ready"
```

### List components and health
```bash
curl -sf "${ALLOY_URL}/api/v0/web/components" | \
  jq '.[] | {id: .localID, health: .health.type, message: .health.message}'
```

### Get component detail
```bash
curl -sf "${ALLOY_URL}/api/v0/web/components/<component-id>" | \
  jq '{id: .localID, health: .health, arguments, exports}'
```

### View cluster peers
```bash
curl -sf "${ALLOY_URL}/api/v0/web/peers" | \
  jq '.[] | {name, addr, state}'
```

### Scrape internal metrics
```bash
curl -sf "${ALLOY_URL}/metrics" | grep -E '^alloy_' | head -20
```
