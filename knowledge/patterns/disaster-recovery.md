# Disaster Recovery Patterns
tags: disaster-recovery, dr, high-availability, backup, rpo, rto

## Key Metrics

- **RPO (Recovery Point Objective):** Maximum acceptable data loss (time)
- **RTO (Recovery Time Objective):** Maximum acceptable downtime

| Pattern | RPO | RTO | Cost |
|---------|-----|-----|------|
| Backup & Restore | Hours | Hours-Days | Low |
| Pilot Light | Minutes | 10-30 min | Low-Medium |
| Warm Standby | Seconds-Minutes | Minutes | Medium |
| Active-Passive | Seconds | Seconds-Minutes | Medium-High |
| Active-Active | Zero | Near-zero | High |

## Backup & Restore

Simplest pattern. Regular backups stored offsite.

- Automate backups with scheduled jobs
- Store in different region/provider (3-2-1 rule: 3 copies, 2 media, 1 offsite)
- Test restores regularly (at least quarterly)
- Document restore procedures as runbooks

```bash
# Example: automated database backup to S3
pg_dump mydb | gzip | aws s3 cp - s3://backups/db/mydb-$(date +%Y%m%d).sql.gz
```

## Pilot Light

Minimal version of the environment always running in DR region.

- Core infrastructure (database replicas, DNS) running at all times
- Application servers are pre-configured but stopped
- Scale up on failover

**When to use:** RPO minutes, RTO 10-30 minutes, moderate budget.

## Warm Standby

Scaled-down but fully functional copy in DR region.

- All components running at reduced capacity
- Database replication (async or sync)
- Can handle read traffic during normal operations
- Scale up to full capacity on failover

**When to use:** RPO seconds-minutes, RTO minutes.

## Active-Passive

Full copy of production in DR region, ready to take over.

- Full infrastructure running in standby
- Synchronous or near-synchronous data replication
- Automated failover with health checks
- DNS or load balancer switches traffic

**When to use:** RPO seconds, RTO seconds-minutes.

```yaml
# Example: Route53 health check failover
Type: AWS::Route53::RecordSet
Properties:
  Failover: PRIMARY
  HealthCheckId: !Ref PrimaryHealthCheck
  SetIdentifier: primary
```

## Active-Active (Multi-Region)

Both regions serve production traffic simultaneously.

- Data replicated bi-directionally
- Geographic load balancing
- Conflict resolution strategy required
- Most complex but highest availability

**When to use:** Zero RPO, near-zero RTO, global users.

**Challenges:**
- Data consistency across regions
- Conflict resolution (last-writer-wins, CRDTs, application-level)
- Network partitions (split-brain)
- Higher operational complexity

## RPO/RTO Tradeoffs

**Lower RPO requires:**
- More frequent backups or real-time replication
- Higher storage and bandwidth costs
- Synchronous replication impacts write latency

**Lower RTO requires:**
- More infrastructure running in standby
- Automated failover mechanisms
- Regular failover testing
- Higher compute costs

## Testing DR

- **Tabletop exercise:** Walk through scenarios on paper
- **Partial failover:** Fail over non-critical services
- **Full failover:** Complete DR activation (do quarterly)
- **Chaos engineering:** Random failure injection (Netflix Chaos Monkey)

Document and review results after each test. Update runbooks accordingly.
