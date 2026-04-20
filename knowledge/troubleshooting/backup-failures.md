# Backup Failure Troubleshooting

## Restic Lock Issues
**Symptoms:** `repository is already locked`, backup fails to start.
**Steps:**
1. Check for stale locks: `restic list locks`
2. Verify no other backup process is running: `ps aux | grep restic`
3. Remove stale lock: `restic unlock` (safe if no backup is running)
4. Force unlock if needed: `restic unlock --remove-all`
5. Prevent: use lock timeout in wrapper scripts
6. If on shared storage: check for zombie NFS locks
7. After unlock: run `restic check` to verify repository integrity

## Borg Corruption
**Symptoms:** `IntegrityError`, `Repository corrupted`, failed verification.
**Steps:**
1. Run check: `borg check --repository-only /path/to/repo`
2. If corrupted: `borg check --repair --repository-only /path/to/repo`
3. Check archive integrity: `borg check --archives-only /path/to/repo`
4. Repair archives: `borg check --repair --archives-only /path/to/repo`
5. If unrepairable: restore from secondary backup, recreate repository
6. Prevent: use `borg check` in cron after backups
7. Check disk health: `smartctl -a /dev/sdX`
8. Ensure no process is writing to repo during check/repair

## Velero Partial Failure
**Symptoms:** Backup shows `PartiallyFailed`, some resources not backed up.
**Steps:**
1. Check backup details: `velero backup describe <name> --details`
2. Check backup logs: `velero backup logs <name>`
3. Common causes: CRD issues, webhook timeouts, RBAC insufficient
4. Check for resource exclusions: annotations `velero.io/exclude-from-backup`
5. Verify Velero has access to all namespaces
6. Check volume snapshot provider: `velero get snapshot-locations`
7. For PV failures: check CSI driver compatibility and snapshot class
8. Increase timeout: `--default-volumes-to-fs-backup` for problematic volumes

## pg_dump Permission Denied
**Symptoms:** `pg_dump: error: permission denied`, incomplete SQL dump.
**Steps:**
1. Verify user has required privileges: `\du` in psql
2. Grant necessary permissions: `GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;`
3. For `pg_dumpall`: requires superuser or `pg_read_all_data` role (PG14+)
4. Check `pg_hba.conf` allows connection from backup host
5. Verify password/authentication: `.pgpass` file or `PGPASSWORD` env var
6. For RDS: use the master user or grant `rds_superuser` role
7. Check for row-level security policies blocking access
8. Test: `psql -U backup_user -h <host> -d <db> -c "SELECT 1"`

## Disk Full During Backup
**Symptoms:** Backup fails with `No space left on device`, partial backup file.
**Steps:**
1. Check disk space: `df -h` on backup destination and temp directories
2. Clean up old backups: apply retention policy
3. Check for large temp files: backups often use `/tmp` or `TMPDIR`
4. Set `TMPDIR` to a volume with sufficient space
5. Use streaming/incremental backups to reduce space needs
6. For pg_dump: use `--compress=9` to reduce dump size
7. For restic/borg: use deduplication (built-in) to reduce repository growth
8. Monitor: set up disk space alerts on backup destinations
9. Consider: backup to object storage (S3, GCS) instead of local disk
10. Clean up incomplete backup files after failure
