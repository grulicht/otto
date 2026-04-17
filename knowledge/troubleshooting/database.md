# Database Common Issues

## PostgreSQL

### Connection Refused
1. Check service: `systemctl status postgresql`
2. Check listen_addresses in postgresql.conf
3. Check pg_hba.conf for client authentication
4. Check firewall allows port 5432

### Slow Queries
1. `EXPLAIN ANALYZE <query>` - check query plan
2. Look for sequential scans on large tables
3. Add missing indexes
4. Check `pg_stat_activity` for long-running queries
5. `pg_stat_statements` for top resource consumers

### Replication Lag
1. Check `pg_stat_replication` on primary
2. Check `pg_stat_wal_receiver` on replica
3. Common causes: network latency, replica under load, WAL archive behind

### Disk Space
1. Check bloated tables: `pg_stat_all_tables` (dead tuples)
2. Run `VACUUM FULL` for reclaiming space (locks table!)
3. Check WAL file accumulation
4. Archive/delete old data

## MySQL/MariaDB

### Too Many Connections
1. Check current: `SHOW PROCESSLIST`
2. Increase: `SET GLOBAL max_connections = N`
3. Check for connection leaks in application

### Slow Queries
1. Enable slow query log
2. `EXPLAIN <query>` - check query plan
3. Check for missing indexes: `SHOW INDEX FROM <table>`

## Redis

### Out of Memory
1. Check: `redis-cli INFO memory`
2. Set maxmemory and eviction policy
3. Check for large keys: `redis-cli --bigkeys`
4. Consider data expiration (TTL)

### High Latency
1. `redis-cli --latency` - measure
2. Check for slow commands: `SLOWLOG GET`
3. Avoid large keys and blocking operations (KEYS *)
