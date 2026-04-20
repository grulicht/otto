---
name: ssl-certs
description: SSL/TLS certificate monitoring via openssl CLI
type: cli
required_env:
  - OTTO_SSL_DOMAINS
required_tools:
  - openssl
check_command: "openssl version 2>/dev/null"
---

# SSL Certificates

## Connection

OTTO checks SSL certificates by connecting to remote hosts via `openssl s_client`.
Set `OTTO_SSL_DOMAINS` to a comma-separated list of domains to monitor.

```bash
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
```

## Available Data

- **Expiry dates**: Certificate not-before and not-after dates
- **Issuer**: Certificate authority details
- **Subject**: Common name and SANs
- **Chain**: Full certificate chain validation
- **Protocol**: TLS version and cipher suite

## Common Queries

### Check certificate expiry
```bash
echo | openssl s_client -servername "$domain" -connect "$domain":443 2>/dev/null | \
  openssl x509 -noout -enddate
```

### Days until expiry
```bash
expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain":443 2>/dev/null | \
  openssl x509 -noout -enddate | cut -d= -f2)
echo $(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 )) days
```

### Full certificate details
```bash
echo | openssl s_client -servername "$domain" -connect "$domain":443 2>/dev/null | \
  openssl x509 -noout -text
```

### Check certificate chain
```bash
echo | openssl s_client -showcerts -servername "$domain" -connect "$domain":443 2>/dev/null
```

### Verify TLS version support
```bash
openssl s_client -tls1_3 -connect "$domain":443 </dev/null 2>/dev/null && echo "TLS 1.3 supported"
```
