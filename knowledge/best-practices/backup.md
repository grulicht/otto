# Backup Best Practices

## The 3-2-1 Rule
- **3** copies of your data
- **2** different storage media/types
- **1** offsite/remote copy

## Strategy
- Define RPO (Recovery Point Objective) and RTO (Recovery Time Objective)
- Full + incremental backup combination for efficiency
- Encrypt backups at rest and in transit
- Verify backups regularly (test restores!)
- Document restore procedures as runbooks

## Database Backups
- Use native dump tools (pg_dump, mysqldump, mongodump)
- Prefer logical backups for portability, physical for speed
- Enable WAL/binlog archiving for point-in-time recovery
- Test restore to a separate environment monthly

## Kubernetes Backups
- Back up etcd regularly
- Use Velero for namespace/resource-level backups
- Back up PersistentVolumes separately
- Store backup configs in Git

## File/System Backups
- Use deduplication tools (Restic, Borg) for efficiency
- Exclude temporary and cache directories
- Monitor backup job success/failure
- Rotate old backups (daily -> weekly -> monthly)

## Disaster Recovery
- Document and test DR procedures
- Maintain runbooks for each service restoration
- Practice DR regularly (at least quarterly)
- Track time-to-restore metrics
- Consider multi-region for critical services
