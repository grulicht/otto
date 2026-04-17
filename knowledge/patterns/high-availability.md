# High Availability Pattern

## Principles
- **No single point of failure** - redundancy at every layer
- **Graceful degradation** - partial functionality over total failure
- **Automatic failover** - detect failures and switch without human intervention
- **Health monitoring** - continuous checking of all components

## Architecture Layers

### Application Layer
- Run multiple replicas (minimum 3 for quorum)
- Use horizontal pod autoscaler (HPA) for dynamic scaling
- Implement circuit breakers for downstream dependencies
- Use retry with exponential backoff for transient failures
- Implement health checks (readiness + liveness)

### Load Balancing
- Use active-active load balancing (not active-passive)
- Health check backends and remove unhealthy ones
- Use session affinity only when necessary
- Consider geographic load balancing for global services

### Database Layer
- Primary-replica replication (sync or async based on RPO)
- Automatic failover (Patroni for PostgreSQL, Orchestrator for MySQL)
- Connection pooling (PgBouncer, ProxySQL)
- Regular backup testing

### Infrastructure Layer
- Multi-AZ deployment (cloud)
- Cluster across multiple nodes (on-prem)
- Redundant networking (multiple uplinks, LACP)
- UPS and generator for power redundancy

### DNS & CDN
- Multiple DNS providers or anycast DNS
- CDN for static content and DDoS protection
- Low TTL for DNS records used in failover

## Kubernetes Specifics
- Pod anti-affinity to spread across nodes/zones
- PodDisruptionBudgets to maintain minimum availability
- Multiple replicas in Deployments
- Use topology spread constraints
- Node pools across availability zones

## SLA Targets
| Availability | Downtime/year | Downtime/month |
|-------------|---------------|----------------|
| 99% | 3.65 days | 7.3 hours |
| 99.9% | 8.76 hours | 43.8 minutes |
| 99.95% | 4.38 hours | 21.9 minutes |
| 99.99% | 52.6 minutes | 4.4 minutes |
