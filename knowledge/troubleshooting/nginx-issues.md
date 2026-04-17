# Nginx Troubleshooting Guide
tags: nginx, web-server, reverse-proxy, load-balancer

## 502 Bad Gateway

**Symptom:** Nginx returns `502 Bad Gateway` to clients

**Diagnosis:**
1. Check upstream service is running: `systemctl status myapp`
2. Verify upstream address/port in nginx config
3. Check upstream logs for crashes or errors
4. Test upstream directly: `curl http://127.0.0.1:8080/health`

**Fix:**
```bash
# Check if upstream is listening
ss -tlnp | grep 8080

# Check nginx error log
tail -f /var/log/nginx/error.log

# Common causes:
# - Upstream service crashed
# - Wrong upstream port
# - Upstream socket file missing (PHP-FPM, uWSGI)
# - SELinux blocking connections: setsebool -P httpd_can_network_connect 1
```

## 504 Gateway Timeout

**Symptom:** Nginx returns `504 Gateway Timeout` after waiting

**Diagnosis:**
1. Upstream is responding too slowly
2. Check upstream processing time
3. Review timeout settings in nginx config

**Fix:**
```nginx
# Increase proxy timeouts
location / {
    proxy_connect_timeout 300s;
    proxy_send_timeout    300s;
    proxy_read_timeout    300s;
    send_timeout          300s;
}
```

## SSL/TLS Handshake Failed

**Symptom:** `SSL_do_handshake() failed`, browser shows certificate error

**Diagnosis:**
1. Check certificate validity: `openssl x509 -in cert.pem -noout -dates`
2. Verify certificate chain is complete
3. Check private key matches certificate
4. Verify TLS protocol/cipher compatibility

**Fix:**
```bash
# Verify cert and key match
openssl x509 -noout -modulus -in cert.pem | md5sum
openssl rsa -noout -modulus -in key.pem | md5sum

# Test SSL configuration
openssl s_client -connect domain.com:443 -servername domain.com

# Check for missing intermediate certs
# Concatenate: cat cert.pem intermediate.pem > fullchain.pem
```

## Too Many Open Files

**Symptom:** `socket() failed (24: Too many open files)` in error log

**Diagnosis:**
1. Check current limits: `cat /proc/$(pgrep -f 'nginx: master')/limits`
2. Check open file count: `ls /proc/$(pgrep -f 'nginx: worker')/fd | wc -l`
3. Review `worker_connections` setting

**Fix:**
```bash
# In nginx.conf
worker_rlimit_nofile 65535;
events {
    worker_connections 16384;
}

# System-wide
echo "nginx soft nofile 65535" >> /etc/security/limits.conf
echo "nginx hard nofile 65535" >> /etc/security/limits.conf

# Systemd override
# [Service]
# LimitNOFILE=65535
systemctl edit nginx
systemctl restart nginx
```

## Configuration Syntax Errors

**Symptom:** Nginx fails to start or reload, syntax error in logs

**Diagnosis:**
```bash
# Test configuration
nginx -t

# Check specific config file
nginx -t -c /etc/nginx/nginx.conf
```

**Common mistakes:**
- Missing semicolon at end of directive
- Mismatched braces
- Invalid directive in wrong context
- Duplicate `listen` directives on same port

## Upstream Connection Refused

**Symptom:** `connect() failed (111: Connection refused) while connecting to upstream`

**Diagnosis:**
1. Upstream service is not running
2. Upstream is listening on different interface (127.0.0.1 vs 0.0.0.0)
3. Firewall blocking the connection
4. Docker networking issues (wrong network or container name)

**Fix:**
```bash
# Verify upstream is listening on correct interface
ss -tlnp | grep <port>

# Check firewall
iptables -L -n | grep <port>

# For Docker: use container name in docker-compose network
# upstream backend {
#     server app:8080;
# }
```
