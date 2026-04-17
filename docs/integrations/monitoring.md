# Monitoring Integrations

## Grafana

OTTO integrates with Grafana via the Grafana MCP server or REST API.

### Setup
```bash
# In ~/.config/otto/.env
OTTO_GRAFANA_URL=https://grafana.example.com
OTTO_GRAFANA_TOKEN=your-service-account-token
```

### Capabilities
- Query dashboards and panels
- Read and manage alerts
- Execute PromQL/LogQL queries through Grafana datasources
- Create annotations
- Get panel images

## Prometheus

### Setup
Prometheus is accessed via `promtool` CLI or Grafana datasource.

### Capabilities
- Execute PromQL queries
- Check alert rules and target health
- Explore metric names and labels

## Loki

### Setup
Via `logcli` CLI or Grafana datasource.

### Capabilities
- Execute LogQL queries
- Explore log patterns and labels
- Detect anomalies in log streams

## Zabbix

### Setup
```bash
OTTO_ZABBIX_URL=https://zabbix.example.com
OTTO_ZABBIX_TOKEN=your-api-token
```

### Capabilities
- Monitor host and trigger status
- Manage templates and items
- Analyze problems and events

## Datadog

### Setup
```bash
OTTO_DATADOG_API_KEY=your-api-key
OTTO_DATADOG_APP_KEY=your-app-key
```

### Capabilities
- Query metrics
- Manage monitors
- APM trace analysis

## ELK Stack

### Capabilities
- Elasticsearch queries
- Kibana dashboard management
- Index management and health

## New Relic

### Setup
```bash
OTTO_NEWRELIC_API_KEY=your-api-key
OTTO_NEWRELIC_ACCOUNT_ID=your-account-id
```

### Capabilities
- Execute NRQL queries
- Manage alert policies
- Track SLI/SLO

## Mimir / Grafana Alloy / StatusPage
See source definitions in `agents/sources/` for setup details.
