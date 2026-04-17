# SSL Certificate Renewal Runbook
tags: ssl, tls, certificate, renewal, certbot, security

## Overview
Renew SSL/TLS certificates before expiry to prevent service disruption.

## Prerequisites
- Access to the server hosting the certificate
- DNS control (for DNS-01 challenge) or HTTP access (for HTTP-01)
- Backup access

## Step 1: Check Certificate Expiry

```bash
# Check expiry from the server
openssl x509 -in /etc/ssl/certs/domain.pem -noout -enddate

# Check remotely
echo | openssl s_client -connect domain.com:443 -servername domain.com 2>/dev/null \
  | openssl x509 -noout -dates

# Check days until expiry
echo | openssl s_client -connect domain.com:443 -servername domain.com 2>/dev/null \
  | openssl x509 -noout -checkend 2592000
# Returns 0 if valid for 30 more days, 1 if expiring sooner
```

## Step 2: Backup Existing Certificates

```bash
BACKUP_DIR="/etc/ssl/backup/$(date +%Y%m%d)"
mkdir -p "${BACKUP_DIR}"
cp /etc/ssl/certs/domain.pem "${BACKUP_DIR}/"
cp /etc/ssl/private/domain.key "${BACKUP_DIR}/"
cp /etc/ssl/certs/fullchain.pem "${BACKUP_DIR}/"
echo "Backup created at ${BACKUP_DIR}"
```

## Step 3: Renew Certificate

### Option A: Certbot (Let's Encrypt)

```bash
# Automatic renewal (recommended)
certbot renew --dry-run    # Test first
certbot renew              # Actually renew

# Force renewal for specific domain
certbot certonly --force-renewal -d domain.com -d www.domain.com

# Using DNS challenge (for wildcard certs)
certbot certonly --manual --preferred-challenges dns -d "*.domain.com" -d domain.com
```

### Option B: Manual / Commercial CA

1. Generate new CSR:
```bash
openssl req -new -key /etc/ssl/private/domain.key \
  -out /tmp/domain.csr \
  -subj "/CN=domain.com/O=Company/C=US"
```

2. Submit CSR to your CA (DigiCert, Sectigo, etc.)
3. Download the new certificate and chain
4. Place files:
```bash
cp new-cert.pem /etc/ssl/certs/domain.pem
cp new-chain.pem /etc/ssl/certs/fullchain.pem
```

## Step 4: Verify New Certificate

```bash
# Verify cert matches key
CERT_MOD=$(openssl x509 -noout -modulus -in /etc/ssl/certs/domain.pem | md5sum)
KEY_MOD=$(openssl rsa -noout -modulus -in /etc/ssl/private/domain.key | md5sum)

if [[ "${CERT_MOD}" == "${KEY_MOD}" ]]; then
    echo "OK: Certificate and key match"
else
    echo "ERROR: Certificate and key do NOT match!"
    exit 1
fi

# Verify chain
openssl verify -CAfile /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/fullchain.pem

# Check new expiry
openssl x509 -in /etc/ssl/certs/domain.pem -noout -dates
```

## Step 5: Deploy / Reload Services

```bash
# Nginx
nginx -t && systemctl reload nginx

# Apache
apachectl configtest && systemctl reload apache2

# HAProxy
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
```

## Step 6: Test

```bash
# Test HTTPS connection
curl -vI https://domain.com 2>&1 | grep -E "expire|subject|issuer"

# Test with SSL Labs (external)
echo "Visit: https://www.ssllabs.com/ssltest/analyze.html?d=domain.com"

# Test certificate chain
openssl s_client -connect domain.com:443 -servername domain.com < /dev/null 2>/dev/null \
  | openssl x509 -noout -text | grep -A2 "Validity"
```

## Rollback

If the new certificate causes issues:
```bash
# Restore from backup
cp "${BACKUP_DIR}/domain.pem" /etc/ssl/certs/domain.pem
cp "${BACKUP_DIR}/domain.key" /etc/ssl/private/domain.key
cp "${BACKUP_DIR}/fullchain.pem" /etc/ssl/certs/fullchain.pem

# Reload service
nginx -t && systemctl reload nginx
```

## Automation

Set up automatic renewal with cron or systemd timer:
```bash
# Certbot timer (usually installed automatically)
systemctl enable --now certbot.timer

# Or cron
0 3 * * 1 certbot renew --quiet --deploy-hook "systemctl reload nginx"
```
