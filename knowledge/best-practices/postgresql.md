# PostgreSQL Best Practices

## Indexing
- Create indexes on columns used in WHERE, JOIN, and ORDER BY clauses
- Use partial indexes for queries with common WHERE conditions
- Use `EXPLAIN ANALYZE` to verify index usage
- Avoid over-indexing - each index adds write overhead
- Use `pg_stat_user_indexes` to find unused indexes
- Consider covering indexes (INCLUDE) to enable index-only scans

## VACUUM and Maintenance
- Never disable autovacuum - tune it instead
- Increase `autovacuum_vacuum_scale_factor` for large tables (0.01 instead of 0.2)
- Run `VACUUM ANALYZE` after bulk operations
- Monitor dead tuple count with `pg_stat_user_tables`
- Set `maintenance_work_mem` high (1-2GB) for faster vacuum
- Watch for transaction ID wraparound (`age(datfrozenxid)` approaching 2 billion)

## Connection Pooling
- Use PgBouncer or pgpool-II for connection pooling
- Set `max_connections` conservatively (100-300) and use pooler for more
- Use transaction-level pooling for most workloads
- Monitor `pg_stat_activity` for connection state and wait events

## Replication
- Use streaming replication with synchronous_commit for HA
- Deploy Patroni for automatic failover
- Monitor replication lag via `pg_stat_replication`
- Use replication slots to prevent WAL removal before replica catches up
- Set `max_wal_senders` and `wal_keep_size` appropriately

## Backup
- Use `pg_basebackup` for physical backups
- Use `pg_dump` for logical backups of specific databases
- Implement point-in-time recovery (PITR) with WAL archiving
- Test restores regularly - untested backups are not backups
- Use tools like pgBackRest or Barman for production

## Monitoring
- Enable `pg_stat_statements` for query performance tracking
- Monitor `pg_stat_user_tables` for sequential scans on large tables
- Track `pg_stat_bgwriter` for checkpoint frequency
- Alert on replication lag, connection count, and lock waits
- Use `pg_stat_activity` to find long-running queries and blocked sessions

## Query Optimization
- Avoid `SELECT *` - select only needed columns
- Use `LIMIT` with `OFFSET` carefully - use keyset pagination instead
- Batch `INSERT`s with multi-row VALUES or COPY
- Use CTEs for readability but be aware they can be optimization fences
- Prefer `EXISTS` over `IN` for subqueries
- Analyze slow queries with `auto_explain` module

## pg_stat_statements
- Enable with `shared_preload_libraries = 'pg_stat_statements'`
- Set `pg_stat_statements.track = all` for comprehensive tracking
- Regularly review top queries by `total_exec_time` and `calls`
- Reset stats periodically: `SELECT pg_stat_statements_reset()`
- Use `mean_exec_time` and `stddev_exec_time` to find variable queries

## Configuration Tuning
- `shared_buffers`: 25% of RAM
- `effective_cache_size`: 50-75% of RAM
- `work_mem`: start at 4MB, increase for complex queries
- `random_page_cost`: 1.1 for SSD, 4.0 for HDD
- `checkpoint_completion_target`: 0.9
- `wal_buffers`: 64MB for write-heavy workloads
