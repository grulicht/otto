---
name: nginx
description: Nginx web server status and configuration monitoring
type: cli
required_env: []
required_tools:
  - nginx
  - openssl
check_command: "nginx -v 2>&1"
---

# Nginx

## Connection

OTTO monitors nginx through the `nginx` CLI and by reading configuration and
log files. The stub_status module provides real-time connection metrics.

```bash
nginx -v           # verify nginx is installed
nginx -t           # test configuration syntax
```

## Available Data

- **Configuration**: Virtual hosts, upstreams, SSL settings
- **Status**: Active connections, request rates (via stub_status)
- **Logs**: Access and error logs
- **SSL**: Certificate status for configured sites
- **Upstreams**: Backend server health

## Common Queries

### Test configuration
```bash
nginx -t 2>&1
```

### List enabled sites
```bash
ls /etc/nginx/sites-enabled/ 2>/dev/null || ls /etc/nginx/conf.d/
```

### Check nginx status
```bash
systemctl status nginx
```

### Active connections (stub_status)
```bash
curl -s http://localhost/nginx_status 2>/dev/null
```

### Recent error log entries
```bash
tail -50 /var/log/nginx/error.log 2>/dev/null
```

### Check SSL certificates for configured domains
```bash
grep -r "ssl_certificate " /etc/nginx/ 2>/dev/null | awk '{print $2}' | tr -d ';' | while read -r cert; do
  openssl x509 -in "$cert" -noout -enddate -subject 2>/dev/null
done
```

### Top request paths from access log
```bash
awk '{print $7}' /var/log/nginx/access.log 2>/dev/null | sort | uniq -c | sort -rn | head -20
```
