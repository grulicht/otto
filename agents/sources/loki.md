---
name: loki
description: Grafana Loki log aggregation via logcli CLI or HTTP API
type: cli
required_env:
  - OTTO_LOKI_URL
required_tools:
  - logcli
  - curl
  - jq
check_command: "curl -sf '${OTTO_LOKI_URL}/ready'"
---

# Loki

## Connection

OTTO connects to Loki through `logcli` CLI, the HTTP API, or Grafana MCP tools.
If Grafana MCP is available and Loki is a configured data source, prefer MCP tools
(`query_loki_logs`, `list_loki_label_names`, `query_loki_stats`, etc.).

**logcli CLI** (preferred for interactive use):
```bash
export LOKI_ADDR="${OTTO_LOKI_URL}"
logcli query '{job="myapp"}'
```

**HTTP API**:
```bash
curl -sf "${OTTO_LOKI_URL}/loki/api/v1/query_range" \
  --data-urlencode 'query={job="myapp"}'
```

If authentication is required, set `OTTO_LOKI_USER` and `OTTO_LOKI_PASSWORD` or
pass a Bearer token via `OTTO_LOKI_TOKEN`.

## Available Data

- **Log queries**: Run LogQL queries for log lines and metric queries
- **Label discovery**: List all label names and values for a given label
- **Series**: List all series matching a given set of label matchers
- **Patterns**: Discover log patterns from recent data
- **Stats**: Get ingestion and query statistics
- **Tail**: Stream live logs matching a query

## Common Queries

### Query recent logs
```bash
logcli query '{job="myapp"}' --limit=100 --since=1h
```

### Query with filter
```bash
logcli query '{namespace="production"} |= "error" | logfmt | level="error"' --limit=50
```

### HTTP API - query range
```bash
curl -sf "${OTTO_LOKI_URL}/loki/api/v1/query_range" \
  --data-urlencode 'query={job="myapp"} |= "error"' \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode "limit=100" | jq '.data.result'
```

### List label names
```bash
curl -sf "${OTTO_LOKI_URL}/loki/api/v1/labels" | jq '.data'
```

### List label values
```bash
curl -sf "${OTTO_LOKI_URL}/loki/api/v1/label/job/values" | jq '.data'
```

### Log volume (metric query)
```bash
logcli query 'sum(count_over_time({job="myapp"}[5m])) by (level)' --since=1h
```

### Tail live logs
```bash
logcli tail '{namespace="production"} |= "error"'
```
