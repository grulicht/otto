# Observability Stack Pattern

## Three Pillars of Observability

### Metrics (Prometheus)
- Numeric measurements over time (counters, gauges, histograms)
- Best for: alerting, dashboards, capacity planning, SLO tracking
- Collection: pull-based scraping of `/metrics` endpoints
- Storage: TSDB with configurable retention
- Key metrics: RED (Rate, Errors, Duration) for services, USE (Utilization, Saturation, Errors) for resources

### Logs (Loki / ELK)
- Timestamped text records of discrete events
- Best for: debugging, audit trails, error investigation
- Collection: agents (Promtail, Fluentd, Vector) ship to central store
- Use structured logging (JSON) for efficient querying
- Include trace IDs in logs for correlation

### Traces (Tempo / Jaeger)
- End-to-end request path across services
- Best for: latency analysis, dependency mapping, bottleneck identification
- Collection: OpenTelemetry SDK in applications, auto-instrumentation where possible
- Sample traces in production (1-10% depending on volume)
- Always capture traces for errors and slow requests (tail-based sampling)

## Dashboards (Grafana)

### Dashboard Design
- Use consistent layout across services
- Top row: key SLIs (error rate, latency P50/P95/P99, throughput)
- Second row: resource utilization (CPU, memory, disk, network)
- Detail rows: service-specific metrics
- Use template variables for namespace, service, environment filtering
- Link dashboards: overview -> service -> pod -> trace

### Recommended Dashboards
1. **Platform Overview**: cluster health, node utilization, pod status
2. **Service Dashboard**: per-service RED metrics, dependencies
3. **Database Dashboard**: connections, query time, replication lag, cache hit ratio
4. **Infrastructure Dashboard**: node metrics, disk, network I/O
5. **Cost Dashboard**: resource cost by namespace, idle resources

## Alerting

### Alert Design
- Alert on symptoms (high error rate, latency) not causes (CPU high)
- Use multi-window, multi-burn-rate alerts for SLO-based alerting
- Severity levels: critical (page), warning (ticket), info (dashboard)
- Include runbook link in every alert annotation
- Group related alerts to reduce noise

### Example Alert Rules
```yaml
groups:
  - name: slo-alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))
          > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate above 1% for 5 minutes"
          runbook: "https://runbooks.example.com/high-error-rate"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
          > 1.0
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "P99 latency above 1s for 10 minutes"
```

## SLOs (Service Level Objectives)

### Defining SLOs
- Availability SLO: `successful_requests / total_requests >= 99.9%`
- Latency SLO: `requests_under_500ms / total_requests >= 99%`
- Use error budgets to balance reliability and velocity
- Measure over rolling 30-day windows
- Start with achievable SLOs and tighten over time

### Error Budget
- Error budget = 1 - SLO target (e.g., 99.9% = 0.1% error budget)
- 0.1% of 30 days = 43.2 minutes of downtime allowed
- When budget is exhausted: freeze deployments, focus on reliability
- Track burn rate: how fast are you consuming the budget?

## Implementation Checklist
- [ ] Deploy Prometheus + Grafana for metrics
- [ ] Deploy Loki (or ELK) for log aggregation
- [ ] Deploy Tempo (or Jaeger) for distributed tracing
- [ ] Instrument applications with OpenTelemetry
- [ ] Create standard dashboards for all services
- [ ] Define SLOs for critical services
- [ ] Configure alerting rules with runbook links
- [ ] Set up on-call rotation and escalation policies
- [ ] Implement log correlation with trace IDs
- [ ] Enable exemplars for metrics-to-traces linking
