# Database Recovery Runbook

## PostgreSQL

### From pg_dump Backup
```bash
# Restore full database
pg_restore -h HOST -U USER -d DBNAME backup.dump

# Restore specific table
pg_restore -h HOST -U USER -d DBNAME -t TABLE_NAME backup.dump

# Restore from SQL dump
psql -h HOST -U USER -d DBNAME < backup.sql
```

### Point-in-Time Recovery (PITR)
1. Restore base backup
2. Configure recovery.conf / postgresql.auto.conf:
   - `restore_command = 'cp /path/to/wal/%f %p'`
   - `recovery_target_time = '2026-04-17 02:00:00'`
3. Start PostgreSQL - it will replay WAL files to target time

## MySQL/MariaDB

### From mysqldump
```bash
mysql -h HOST -u USER -p DBNAME < backup.sql
```

### Point-in-Time Recovery
1. Restore last full backup
2. Apply binary logs: `mysqlbinlog binlog.000001 | mysql -u root`
3. Stop at specific time: `--stop-datetime="2026-04-17 02:00:00"`

## MongoDB
```bash
mongorestore --host HOST --db DBNAME dump/DBNAME/
```

## From Restic/Borg
```bash
# List snapshots
restic -r /repo snapshots

# Restore specific snapshot
restic -r /repo restore <snapshot-id> --target /restore/path

# Borg
borg list /repo
borg extract /repo::archive-name
```

## Verification Steps
1. Check data integrity after restore
2. Verify row counts on critical tables
3. Test application connectivity
4. Check replication status (if applicable)
5. Monitor for errors in application logs
