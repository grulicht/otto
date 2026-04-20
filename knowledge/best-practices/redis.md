# Redis Best Practices

## Memory Management
- Set `maxmemory` and choose an appropriate eviction policy (`allkeys-lru` for cache, `noeviction` for data store)
- Monitor memory with `INFO memory` - watch for fragmentation ratio > 1.5
- Use `MEMORY DOCTOR` and `MEMORY USAGE <key>` to find large keys
- Avoid storing large objects (>1MB) - break them into smaller keys
- Use `UNLINK` instead of `DEL` for large keys (non-blocking deletion)

## Persistence
- **RDB**: Point-in-time snapshots, good for backups, faster restarts
- **AOF**: Append-only log, better durability, use `appendfsync everysec` as compromise
- Use both RDB + AOF for best durability with fast recovery
- Set `no-appendfsync-on-rewrite yes` to avoid disk I/O spikes during rewrites
- Monitor `rdb_last_bgsave_status` and `aof_last_bgrewrite_status`

## Replication
- Use async replication with `min-replicas-to-write` and `min-replicas-max-lag`
- Monitor replication lag via `INFO replication` (`master_repl_offset` vs `slave_repl_offset`)
- Set `repl-diskless-sync yes` for faster initial sync on fast networks
- Replicas should be read-only (`replica-read-only yes`)

## Sentinel
- Deploy at least 3 Sentinel nodes across different failure domains
- Set `down-after-milliseconds` appropriately (5000-30000ms)
- Configure `failover-timeout` to allow sufficient time for failover
- Monitor Sentinel logs for split-brain scenarios

## Cluster Mode
- Use at least 6 nodes (3 masters + 3 replicas)
- Distribute hash slots evenly across masters
- Avoid multi-key operations across slots (use hash tags `{tag}` to colocate)
- Monitor with `CLUSTER INFO` and `CLUSTER NODES`

## Key Naming
- Use colons as separators: `service:entity:id:field`
- Keep key names short but descriptive
- Use consistent prefixes for namespacing
- Avoid generic names like `data`, `temp`, `cache`

## TTL and Expiration
- Always set TTL on cache keys to prevent unbounded growth
- Use `EXPIREAT` for absolute timestamps, `EXPIRE` for relative
- Avoid thundering herd: add random jitter to TTL values
- Monitor `expired_keys` and `evicted_keys` in `INFO stats`

## Pipelining
- Batch multiple commands with `PIPELINE` to reduce round-trip latency
- Aim for pipeline batches of 100-1000 commands
- Use `MULTI`/`EXEC` for atomic transactions, pipeline for throughput

## Connection Management
- Set `maxclients` appropriately (default 10000)
- Use connection pooling in clients
- Set `timeout` to close idle connections (300s is reasonable)
- Monitor `connected_clients` and `rejected_connections`
