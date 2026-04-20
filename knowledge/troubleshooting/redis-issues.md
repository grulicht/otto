# Redis Troubleshooting

## High Memory Usage
**Symptoms:** Redis using excessive memory, evictions occurring, OOM errors.
**Steps:**
1. Check memory usage: `redis-cli INFO memory`
2. Find large keys: `redis-cli --bigkeys` or `redis-cli MEMORY USAGE <key>`
3. Check fragmentation ratio: `mem_fragmentation_ratio` in INFO memory
4. If fragmentation > 1.5: restart Redis or enable `activedefrag yes`
5. Review eviction policy: `maxmemory-policy`
6. Check for key expiration issues: `dbsize` vs expected
7. Consider: are keys missing TTLs? Use `OBJECT IDLETIME` to find stale keys

## Connection Refused
**Symptoms:** Clients cannot connect, `Connection refused` errors.
**Steps:**
1. Check Redis is running: `systemctl status redis` or `ps aux | grep redis`
2. Check bind address: `redis-cli CONFIG GET bind` - ensure it listens on correct interface
3. Check `protected-mode`: if `yes`, only localhost connections are allowed without password
4. Check firewall: `ss -tlnp | grep 6379`
5. Check `maxclients` limit: `redis-cli INFO clients` - compare `connected_clients` vs `maxclients`
6. Check if Redis crashed: `dmesg | grep redis`, check Redis log
7. If OOM killed: check `/var/log/syslog` or `journalctl` for OOM killer

## Replication Lag
**Symptoms:** Replica data is stale, high `master_repl_offset` difference.
**Steps:**
1. Check replication status: `redis-cli INFO replication` on master
2. Monitor `slave0:...lag=N` - lag in seconds
3. Check network between master and replica: `ping`, bandwidth test
4. Check replica `loading` status - might be doing full resync
5. Check `repl-backlog-size` - increase if partial resyncs fail (default 1MB is often too small)
6. Check master `client-output-buffer-limit` for replica clients
7. Large dataset? Consider `repl-diskless-sync yes` for faster resync

## Slow Commands
**Symptoms:** High latency, slow responses, `SLOWLOG` entries.
**Steps:**
1. Check slow log: `redis-cli SLOWLOG GET 10`
2. Identify expensive commands: `KEYS *` (use `SCAN`), `SMEMBERS` on large sets, `SORT`
3. Check if `SAVE` or `BGSAVE` is running: `INFO persistence`
4. Monitor latency: `redis-cli --latency`
5. Check CPU: single-threaded Redis, one core at 100%?
6. Avoid O(N) commands on large datasets
7. Enable latency monitoring: `CONFIG SET latency-monitor-threshold 100`

## AOF Rewrite Issues
**Symptoms:** High disk I/O during AOF rewrite, Redis unresponsive.
**Steps:**
1. Check AOF status: `INFO persistence` - `aof_rewrite_in_progress`
2. Set `no-appendfsync-on-rewrite yes` to reduce I/O during rewrite
3. Increase `auto-aof-rewrite-percentage` to reduce frequency
4. Check disk I/O: `iostat -x 1`
5. If AOF corrupted: `redis-check-aof --fix <file>`
6. Consider faster disk (SSD) or separate disk for AOF

## Cluster Split-Brain
**Symptoms:** Multiple masters for same hash slots, data inconsistency.
**Steps:**
1. Check cluster state: `redis-cli CLUSTER INFO` - look for `cluster_state:fail`
2. Check node connectivity: `redis-cli CLUSTER NODES` - look for `fail` or `pfail` flags
3. Verify network: can all nodes reach each other on both data port and cluster bus port (port+10000)?
4. Check `cluster-node-timeout` - too low causes false failure detection
5. Fix: restart affected nodes, use `CLUSTER FAILOVER FORCE` if needed
6. Prevention: ensure nodes are on reliable network, use odd number of masters minimum 3
7. After recovery: verify data consistency across replicas
