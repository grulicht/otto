---
name: grafana
description: Grafana observability platform for dashboards, alerting, and data exploration
type: mcp
required_env:
  - OTTO_GRAFANA_URL
  - OTTO_GRAFANA_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: Bearer ${OTTO_GRAFANA_TOKEN}' '${OTTO_GRAFANA_URL}/api/health' | jq -r '.database'"
---

# Grafana

## Connection

OTTO connects to Grafana through the MCP server (`grafana-medoro`) when available, or
falls back to the REST API via `curl`. The MCP integration provides richer tool support
including dashboard management, alerting, Sift investigations, and on-call schedules.

**MCP server** (preferred): The `grafana-medoro` MCP server exposes tools such as
`search_dashboards`, `query_prometheus`, `query_loki_logs`, `list_incidents`,
`get_current_oncall_users`, and many more. When the MCP server is connected, prefer
its tools over raw API calls.

**REST API fallback**: Use `curl` with Bearer token authentication against the
Grafana HTTP API. All API endpoints are documented at
`${OTTO_GRAFANA_URL}/api/` and follow the pattern:

```bash
curl -sf -H "Authorization: Bearer ${OTTO_GRAFANA_TOKEN}" \
  -H "Content-Type: application/json" \
  "${OTTO_GRAFANA_URL}/api/<endpoint>"
```

## Available Data

- **Dashboards**: Search, retrieve, create, and update dashboards and folders
- **Alerting**: List alert rules, alert groups, notification policies, contact points, and silences
- **Data sources**: List configured data sources and their details
- **Prometheus metrics**: Run PromQL queries, list metric names, label names/values
- **Loki logs**: Run LogQL queries, list label names/values, view patterns and stats
- **Incidents**: Create, list, update, and resolve Grafana Incident records
- **On-call**: View schedules, shifts, teams, and current on-call users
- **Annotations**: Create, list, and update annotations on dashboards
- **Sift**: Start investigations, analyze logs/traces, find error patterns

## Common Queries

### Check health
```bash
curl -sf -H "Authorization: Bearer ${OTTO_GRAFANA_TOKEN}" \
  "${OTTO_GRAFANA_URL}/api/health"
```

### List firing alerts
```bash
curl -sf -H "Authorization: Bearer ${OTTO_GRAFANA_TOKEN}" \
  "${OTTO_GRAFANA_URL}/api/prometheus/grafana/api/v1/alerts" | \
  jq '[.data.alerts[] | select(.state=="firing")]'
```

### Search dashboards
```bash
curl -sf -H "Authorization: Bearer ${OTTO_GRAFANA_TOKEN}" \
  "${OTTO_GRAFANA_URL}/api/search?query=<term>&type=dash-db"
```

### Query Prometheus via Grafana
```bash
curl -sf -H "Authorization: Bearer ${OTTO_GRAFANA_TOKEN}" \
  "${OTTO_GRAFANA_URL}/api/ds/query" \
  -d '{"queries":[{"datasourceId":<id>,"expr":"up","refId":"A"}]}'
```

### List data sources
```bash
curl -sf -H "Authorization: Bearer ${OTTO_GRAFANA_TOKEN}" \
  "${OTTO_GRAFANA_URL}/api/datasources"
```
