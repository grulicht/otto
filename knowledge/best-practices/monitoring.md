# Monitoring Best Practices

## The Four Golden Signals
- **Latency** - time to serve a request (track success and error separately)
- **Traffic** - requests per second, sessions, transactions
- **Errors** - rate of failed requests (HTTP 5xx, exceptions)
- **Saturation** - resource utilization (CPU, memory, disk, connections)

## SLI/SLO/SLA
- Define SLIs (Service Level Indicators) for each service
- Set SLOs (Service Level Objectives) with error budgets
- Only promise SLAs you can measure and enforce
- Track and visualize error budget consumption

## Alerting
- Alert on symptoms (user impact), not causes
- Use multi-window, multi-burn-rate alerts for SLOs
- Avoid alert fatigue - every alert should be actionable
- Set appropriate severity levels (critical = wake someone up)
- Use silence and maintenance windows for planned work

## Dashboards
- Overview dashboard for each service/team
- Use RED method (Rate, Errors, Duration) for services
- Use USE method (Utilization, Saturation, Errors) for resources
- Keep dashboards simple and scannable
- Link from alert to relevant dashboard

## Logging
- Use structured logging (JSON)
- Include correlation IDs across services
- Set appropriate log levels (ERROR, WARN, INFO, DEBUG)
- Don't log sensitive data (PII, secrets, tokens)
- Centralize logs (ELK, Loki, CloudWatch)

## Tracing
- Implement distributed tracing for microservices
- Instrument critical paths
- Sample traces in production (not 100%)
- Link traces to logs and metrics

## Capacity Planning
- Track resource trends over time
- Set alerts for approaching capacity limits
- Plan for peak traffic (not just average)
- Regular capacity reviews
