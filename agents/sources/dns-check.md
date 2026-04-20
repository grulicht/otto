---
name: dns-check
description: DNS health checking via dig CLI
type: cli
required_env:
  - OTTO_DNS_DOMAINS
required_tools:
  - dig
check_command: "dig +short version.bind txt chaos 2>/dev/null || dig -v 2>&1 | head -1"
---

# DNS Check

## Connection

OTTO checks DNS health using the `dig` utility. Set `OTTO_DNS_DOMAINS` to a
comma-separated list of domains to monitor.

```bash
dig example.com +short     # verify dig is working
```

## Available Data

- **A/AAAA records**: IPv4 and IPv6 address resolution
- **MX records**: Mail server configuration
- **NS records**: Nameserver delegation
- **SOA records**: Zone authority and serial numbers
- **CNAME records**: Alias resolution
- **TXT records**: SPF, DKIM, DMARC, and other TXT records
- **Response time**: DNS query latency
- **Propagation**: Multi-resolver consistency checks

## Common Queries

### Resolve A record
```bash
dig "$domain" A +short
```

### Check all record types
```bash
for type in A AAAA MX NS TXT CNAME SOA; do
  echo "=== $type ===" && dig "$domain" "$type" +short
done
```

### Check DNS response time
```bash
dig "$domain" | grep "Query time"
```

### Verify against multiple resolvers
```bash
for ns in 8.8.8.8 1.1.1.1 9.9.9.9; do
  echo "=== $ns ===" && dig "@$ns" "$domain" +short
done
```

### Check DNSSEC
```bash
dig "$domain" +dnssec +short
```

### Reverse DNS lookup
```bash
dig -x "$ip" +short
```
