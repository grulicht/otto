# PostgreSQL Troubleshooting

## Connection Limit Reached
**Symptoms:** `FATAL: too many connections for role`, `connection limit exceeded`.
**Steps:**
1. Check current connections: `SELECT count(*) FROM pg_stat_activity;`
2. Check per-user limits: `SELECT rolname, rolconnlimit FROM pg_roles;`
3. Find idle connections: `SELECT * FROM pg_stat_activity WHERE state = 'idle' ORDER BY state_change;`
4. Kill idle sessions: `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < now() - interval '1 hour';`
5. Increase `max_connections` (requires restart) or use connection pooler (PgBouncer)
6. Check for connection leaks in application code
7. Set `idle_in_transaction_session_timeout` to auto-kill abandoned transactions

## Slow Queries
**Symptoms:** High response times, CPU spikes, application timeouts.
**Steps:**
1. Enable `pg_stat_statements` and find top queries by `total_exec_time`
2. Check running queries: `SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE state != 'idle' ORDER BY duration DESC;`
3. Run `EXPLAIN (ANALYZE, BUFFERS)` on slow queries
4. Look for sequential scans on large tables: `pg_stat_user_tables.seq_scan`
5. Check for missing indexes
6. Check `work_mem` - increase if sorts spill to disk
7. Kill long-running queries: `SELECT pg_cancel_backend(pid);`

## Table Bloat
**Symptoms:** Table size much larger than expected, slow sequential scans.
**Steps:**
1. Check bloat: `SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 20;`
2. Check dead tuples: `SELECT relname, n_dead_tup, n_live_tup, last_autovacuum FROM pg_stat_user_tables ORDER BY n_dead_tup DESC;`
3. Run `VACUUM FULL <table>` (locks table) or use `pg_repack` (online)
4. Check autovacuum settings: is it running often enough?
5. Tune: `autovacuum_vacuum_scale_factor = 0.01` for large tables
6. Monitor `pg_stat_user_tables.last_autovacuum`

## Replication Lag
**Symptoms:** Replica data is stale, high replay lag.
**Steps:**
1. Check lag on primary: `SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, (sent_lsn - replay_lsn) AS replay_lag FROM pg_stat_replication;`
2. Check lag on replica: `SELECT now() - pg_last_xact_replay_timestamp() AS lag;`
3. Network issues? Check bandwidth and latency between primary and replica
4. Heavy write load? Replica cannot keep up - add more replicas or optimize writes
5. Check `max_wal_senders` and `wal_keep_size` on primary
6. Large transactions? They replay atomically, causing lag spikes

## WAL Accumulation
**Symptoms:** Disk filling up with WAL files in `pg_wal/`.
**Steps:**
1. Check WAL size: `du -sh $PGDATA/pg_wal/`
2. Check replication slots: `SELECT slot_name, active, pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes FROM pg_replication_slots;`
3. Inactive slots? Drop them: `SELECT pg_drop_replication_slot('slot_name');`
4. Check archive command: `SELECT * FROM pg_stat_archiver;` - is archiving failing?
5. Increase `max_wal_size` if checkpoints are too frequent
6. If using WAL archival, ensure the archive destination has space

## Lock Contention
**Symptoms:** Queries waiting, `lock timeout` errors, deadlocks.
**Steps:**
1. Check locks: `SELECT blocked.pid, blocked.query, blocking.pid, blocking.query FROM pg_stat_activity blocked JOIN pg_locks bl ON bl.pid = blocked.pid JOIN pg_locks blk ON blk.relation = bl.relation AND blk.pid != bl.pid JOIN pg_stat_activity blocking ON blocking.pid = blk.pid WHERE NOT bl.granted;`
2. Check for deadlocks in logs: `deadlock detected`
3. Find long-running transactions: `SELECT pid, now() - xact_start AS duration, query FROM pg_stat_activity WHERE xact_start IS NOT NULL ORDER BY duration DESC;`
4. Reduce lock duration: use shorter transactions, avoid `LOCK TABLE`
5. Set `lock_timeout` and `deadlock_timeout` appropriately
6. Use `SKIP LOCKED` or advisory locks for queue-like patterns

## OOM Killer
**Symptoms:** PostgreSQL processes killed, `Out of memory` in system logs.
**Steps:**
1. Check system logs: `dmesg | grep -i oom`, `journalctl -k | grep -i oom`
2. Review `shared_buffers` - should be ~25% of RAM, not more
3. Check `work_mem` * `max_connections` - total can exceed available RAM
4. Set `vm.overcommit_memory = 2` and `vm.overcommit_ratio = 80`
5. Use `huge_pages = try` to reduce memory overhead
6. Consider reducing `max_connections` and using connection pooler
7. Set OOM score adjustment: `OOMScoreAdjust=-1000` in systemd unit
