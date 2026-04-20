# Web Server Troubleshooting

## Apache 403 Forbidden

**Steps:**
1. Check file permissions: `ls -la /var/www/html/` -- files need `644`, dirs `755`
2. Check ownership: should match Apache user (`www-data` or `apache`)
3. Verify `<Directory>` block has `Require all granted` (Apache 2.4+)
4. Check SELinux context: `ls -Z /var/www/` -- should be `httpd_sys_content_t`
5. Fix SELinux: `restorecon -Rv /var/www/html/`
6. Check `AllowOverride` if using `.htaccess`

## Apache mod_rewrite Issues

**Symptoms:** Rewrite rules not working, 404 on clean URLs.
**Steps:**
1. Verify module loaded: `apache2ctl -M | grep rewrite`
2. Enable if missing: `a2enmod rewrite && systemctl restart apache2`
3. Check `AllowOverride All` in `<Directory>` block (needed for `.htaccess` rules)
4. Enable rewrite log for debugging: `LogLevel alert rewrite:trace3`
5. Common mistake: missing `RewriteEngine On` in `.htaccess`
6. Verify `RewriteBase` matches the URL path prefix

## Caddy Auto-HTTPS Failures

**Symptoms:** Caddy won't start, ACME challenge fails, certificate not issued.
**Steps:**
1. Check Caddy logs: `journalctl -u caddy -f`
2. Verify domain DNS points to this server: `dig +short <domain>`
3. Ensure ports 80 and 443 are open and not used by another process
4. Check firewall: `ss -tlnp | grep -E ':80|:443'`
5. For staging/testing use: `tls internal` or `acme_ca https://acme-staging-v02.api.letsencrypt.org/directory`
6. Rate limits: check if Let's Encrypt rate limit hit (5 certs per domain per week)

## Traefik IngressRoute Not Working

**Symptoms:** 404 on routes, IngressRoute created but traffic not routing.
**Steps:**
1. Check IngressRoute CRD is applied: `kubectl get ingressroute`
2. Verify Traefik is watching the correct namespace: check `--providers.kubernetescrd.namespaces`
3. Check Traefik dashboard for the route: `kubectl port-forward deploy/traefik 9000:9000`
4. Verify entrypoints match: IngressRoute `entryPoints` must match Traefik config
5. Check middleware references exist: `kubectl get middleware`
6. Check service name and port match the Kubernetes Service

## Reverse Proxy Headers

**Problem:** Backend sees wrong client IP, protocol, or host.
**Fix:**
1. Set `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Real-IP` headers in proxy config
2. Nginx: `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`
3. Nginx: `proxy_set_header X-Forwarded-Proto $scheme;`
4. Nginx: `proxy_set_header Host $host;`
5. Backend must trust the proxy IP -- check `set_real_ip_from` in nginx or `TRUSTED_PROXIES` in app

## WebSocket Proxy

**Symptoms:** WebSocket connection fails through reverse proxy, 400/502 errors.
**Fix for nginx:**
```nginx
location /ws {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;
}
```
**Fix for Apache:**
1. Enable modules: `a2enmod proxy_wstunnel`
2. `ProxyPass "/ws" "ws://backend:8080/ws"`

**Fix for Caddy:** Caddy handles WebSocket automatically -- no special config needed.

## HTTP/2 Issues

**Symptoms:** HTTP/2 not working, connection falls back to HTTP/1.1.
**Steps:**
1. Verify TLS is configured (HTTP/2 requires HTTPS in browsers)
2. Nginx: add `http2` to listen directive: `listen 443 ssl http2;`
3. Apache: `Protocols h2 h2c http/1.1` and `a2enmod http2`
4. Check with: `curl -I --http2 https://example.com` -- look for `HTTP/2`
5. Some older clients/ciphers are incompatible -- ensure modern TLS config
6. Check for `proxy_pass` to HTTP/1.1 backends (fine -- proxy can upgrade)
