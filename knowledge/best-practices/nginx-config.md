# nginx Configuration Best Practices

## Worker Processes
- Set `worker_processes auto` to match CPU cores
- Set `worker_connections 1024-4096` based on expected load
- Use `worker_rlimit_nofile` to increase file descriptor limit
- Enable `multi_accept on` and use `epoll` (Linux) event method

## Keepalive Connections
- Enable keepalive to upstream: `keepalive 32` in upstream block
- Set `keepalive_timeout 65` for client connections
- Set `keepalive_requests 1000` to limit requests per connection
- Use `proxy_http_version 1.1` and `proxy_set_header Connection ""` for upstream keepalive

## Gzip Compression
- Enable with `gzip on`
- Set `gzip_comp_level 5` (balance between CPU and compression)
- Include common types: `gzip_types text/plain text/css application/json application/javascript text/xml`
- Set `gzip_min_length 256` to skip tiny responses
- Enable `gzip_vary on` for proper caching

## Caching
- Use `proxy_cache_path` with appropriate levels and sizes
- Set `proxy_cache_valid 200 1h` for successful responses
- Use `proxy_cache_use_stale` for serving stale content on backend errors
- Add `proxy_cache_lock on` to prevent thundering herd
- Use `X-Cache-Status` header for debugging: `add_header X-Cache-Status $upstream_cache_status`

## Rate Limiting
- Define zones: `limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s`
- Apply with burst: `limit_req zone=api burst=20 nodelay`
- Use `limit_conn_zone` for connection limiting
- Return 429 status: `limit_req_status 429`
- Whitelist trusted IPs with geo/map blocks

## SSL/TLS Configuration
- Use TLS 1.2+ only: `ssl_protocols TLSv1.2 TLSv1.3`
- Strong ciphers: `ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...'`
- Enable OCSP stapling: `ssl_stapling on; ssl_stapling_verify on`
- Set `ssl_session_cache shared:SSL:10m`
- Add security headers: HSTS, X-Content-Type-Options, X-Frame-Options
- Use `ssl_prefer_server_ciphers on`

## Reverse Proxy
- Set proper headers: `proxy_set_header Host $host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`
- Configure timeouts: `proxy_connect_timeout 5s`, `proxy_read_timeout 60s`
- Use `proxy_next_upstream` for automatic failover
- Set `proxy_buffering on` with appropriate buffer sizes
- Add health checks with `max_fails` and `fail_timeout` in upstream

## Logging
- Use structured JSON logging for log aggregation
- Separate access and error logs per vhost
- Use `log_format` with request timing: `$request_time`, `$upstream_response_time`
- Conditionally log with `map` to skip health checks
- Set `access_log off` for static assets if not needed
- Use `open_log_file_cache` for performance with many log files

## Security
- Hide version: `server_tokens off`
- Limit request body: `client_max_body_size 10m`
- Set `client_body_timeout` and `client_header_timeout`
- Block common attack patterns with location blocks
- Use `allow`/`deny` directives for IP-based access control
