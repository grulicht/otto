---
name: mimir
description: Grafana Mimir for long-term Prometheus metrics storage and querying
type: api
required_env:
  - OTTO_MIMIR_URL
required_tools:
  - curl
  - jq
check_command: "curl -sf '${OTTO_MIMIR_URL}/ready'"
---

# Grafana Mimir

## Connection

OTTO connects to Grafana Mimir through its Prometheus-compatible API and native
endpoints. Mimir uses the same query language (PromQL) as Prometheus.

Set `OTTO_MIMIR_TENANT_ID` for multi-tenant deployments (passed via `X-Scope-OrgID` header).

```bash
MIMIR_HEADERS=""
if [[ -n "${OTTO_MIMIR_TENANT_ID:-}" ]]; then
    MIMIR_HEADERS="-H X-Scope-OrgID:${OTTO_MIMIR_TENANT_ID}"
fi
curl -sf ${MIMIR_HEADERS} "${OTTO_MIMIR_URL}/prometheus/api/v1/<endpoint>"
```

## Available Data

- **Metrics**: PromQL queries against long-term storage
- **Rules**: Alerting and recording rules
- **Alerts**: Active alerts from ruler
- **Tenants**: Multi-tenant metrics isolation
- **Ring**: Component ring status (distributor, ingester, compactor)
- **Config**: Runtime configuration

## Common Queries

### Run a PromQL query
```bash
curl -sf ${MIMIR_HEADERS} "${OTTO_MIMIR_URL}/prometheus/api/v1/query" \
  --data-urlencode 'query=up' | jq '.data.result[] | {metric: .metric, value: .value[1]}'
```

### List active alerting rules
```bash
curl -sf ${MIMIR_HEADERS} "${OTTO_MIMIR_URL}/prometheus/api/v1/rules?type=alert" | \
  jq '.data.groups[].rules[] | select(.state == "firing") | {name, state, labels}'
```

### Check component health
```bash
curl -sf "${OTTO_MIMIR_URL}/distributor/ring" | jq '.shards[] | {id, state, address}'
curl -sf "${OTTO_MIMIR_URL}/ingester/ring" | jq '.shards[] | {id, state}'
```

### Query range
```bash
curl -sf ${MIMIR_HEADERS} "${OTTO_MIMIR_URL}/prometheus/api/v1/query_range" \
  --data-urlencode 'query=rate(http_requests_total[5m])' \
  --data-urlencode 'start='"$(date -d '1 hour ago' +%s)" \
  --data-urlencode 'end='"$(date +%s)" \
  --data-urlencode 'step=60' | jq '.data.result'
```
