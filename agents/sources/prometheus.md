---
name: prometheus
description: Prometheus time-series monitoring via promtool CLI or HTTP API
type: cli
required_env:
  - OTTO_PROMETHEUS_URL
required_tools:
  - promtool
  - curl
  - jq
check_command: "curl -sf '${OTTO_PROMETHEUS_URL}/-/healthy'"
---

# Prometheus

## Connection

OTTO connects to Prometheus either through `promtool` CLI commands or the HTTP API.
If Grafana MCP is available and Prometheus is configured as a Grafana data source,
prefer using MCP tools (`query_prometheus`, `list_prometheus_metric_names`, etc.)
for a richer integration.

**promtool CLI**: Use for rule checking, configuration validation, and TSDB operations.

**HTTP API**: Use `curl` against the Prometheus query API at `${OTTO_PROMETHEUS_URL}/api/v1/`.

```bash
curl -sf "${OTTO_PROMETHEUS_URL}/api/v1/query?query=<promql>"
```

## Available Data

- **Instant queries**: Evaluate a PromQL expression at a single point in time
- **Range queries**: Evaluate a PromQL expression over a time range
- **Metric metadata**: List all metric names, label names, and label values
- **Targets**: List all scrape targets and their health status
- **Alerts**: List active alerts from Prometheus alert rules
- **Rules**: List configured recording and alerting rules
- **Configuration**: Retrieve current Prometheus configuration
- **TSDB status**: Check database status, cardinality, and storage usage

## Common Queries

### Instant query
```bash
curl -sf "${OTTO_PROMETHEUS_URL}/api/v1/query" \
  --data-urlencode "query=up" | jq '.data.result'
```

### Range query
```bash
curl -sf "${OTTO_PROMETHEUS_URL}/api/v1/query_range" \
  --data-urlencode "query=rate(http_requests_total[5m])" \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode "step=60" | jq '.data.result'
```

### List all metric names
```bash
curl -sf "${OTTO_PROMETHEUS_URL}/api/v1/label/__name__/values" | jq '.data'
```

### Check targets health
```bash
curl -sf "${OTTO_PROMETHEUS_URL}/api/v1/targets" | \
  jq '[.data.activeTargets[] | {instance: .labels.instance, health: .health, job: .labels.job}]'
```

### List active alerts
```bash
curl -sf "${OTTO_PROMETHEUS_URL}/api/v1/alerts" | jq '.data.alerts'
```

### Validate rules file
```bash
promtool check rules /path/to/rules.yml
```

### Check configuration
```bash
promtool check config /etc/prometheus/prometheus.yml
```

### TSDB status
```bash
curl -sf "${OTTO_PROMETHEUS_URL}/api/v1/status/tsdb" | jq '.data'
```
