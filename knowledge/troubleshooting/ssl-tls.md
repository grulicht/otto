# SSL/TLS Troubleshooting

## Quick Certificate Check
```bash
# Check remote certificate
openssl s_client -connect HOST:443 -servername HOST 2>/dev/null | openssl x509 -noout -dates -subject -issuer

# Check local certificate file
openssl x509 -in cert.pem -noout -text

# Check if key matches certificate
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
# (hashes should match)
```

## Common Issues

### Certificate Expired
- Check expiry: `openssl x509 -in cert.pem -noout -enddate`
- Renew: `certbot renew` or check cert-manager status
- Auto-renewal: ensure cron/timer is running

### Incomplete Chain
- Include intermediate certificates in server config
- Order: server cert -> intermediate(s) -> (root optional)
- Test: `openssl s_client -showcerts -connect HOST:443`

### Subject Alternative Name (SAN) Missing
- Modern browsers require SAN, not just CN
- Generate CSR with `-addext "subjectAltName=DNS:example.com,DNS:*.example.com"`

### Mixed Content
- All resources must be loaded over HTTPS
- Check for hardcoded HTTP URLs in application code

### HSTS Issues
- Once HSTS is set, browser won't allow HTTP fallback
- Be careful with includeSubDomains and max-age values
