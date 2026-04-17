# DNS Troubleshooting Guide
tags: dns, networking, domain, resolution

## NXDOMAIN (Non-Existent Domain)

**Symptom:** `NXDOMAIN` response, domain not found

**Diagnosis:**
1. Verify the domain is registered: `whois example.com`
2. Check authoritative NS records: `dig NS example.com`
3. Query authoritative nameserver directly: `dig @ns1.example.com example.com`
4. Check for typos in domain name

**Fix:**
- Add missing DNS record at your DNS provider
- Verify nameserver delegation is correct
- Wait for propagation if recently changed (up to 48h for NS changes)
- Check if domain registration has expired

## Slow DNS Resolution

**Symptom:** Connections take seconds to establish, `dig` shows high query time

**Diagnosis:**
```bash
# Measure resolution time
dig example.com | grep "Query time"

# Check which nameserver is being used
cat /etc/resolv.conf

# Test with different resolvers
dig @8.8.8.8 example.com
dig @1.1.1.1 example.com
```

**Fix:**
- Switch to faster DNS resolver (Cloudflare 1.1.1.1, Google 8.8.8.8)
- Install local caching resolver (dnsmasq, unbound, systemd-resolved)
- Check for DNS over TCP fallback (indicates UDP issues)
- Reduce TTL on frequently-changed records

## Stale DNS Cache

**Symptom:** Old IP address still being resolved after DNS change

**Diagnosis:**
1. Check TTL on current record: `dig +noall +answer example.com`
2. Compare authoritative vs cached answer
3. Check local resolver cache

**Fix:**
```bash
# Flush systemd-resolved cache
sudo systemd-resolve --flush-caches

# Flush dnsmasq cache
sudo systemctl restart dnsmasq

# Flush nscd cache
sudo nscd --invalidate=hosts

# Check from authoritative source
dig @ns1.provider.com example.com +short
```

## Wrong NS Records

**Symptom:** Domain resolves to old/wrong IP, or does not resolve at some locations

**Diagnosis:**
```bash
# Check NS delegation at registrar level
dig NS example.com +trace

# Verify all NS servers return same data
dig @ns1.example.com A www.example.com +short
dig @ns2.example.com A www.example.com +short
```

**Fix:**
- Update NS records at your domain registrar
- Ensure all nameservers are configured identically
- Wait for NS propagation (can take 24-48 hours)

## Missing PTR Records (Reverse DNS)

**Symptom:** Email rejected, reverse DNS lookup fails, `host <ip>` returns NXDOMAIN

**Diagnosis:**
```bash
# Check reverse DNS
dig -x 203.0.113.1
host 203.0.113.1
```

**Fix:**
- Contact your hosting/IP provider to set PTR record
- For cloud providers: set reverse DNS in console (AWS, GCP, Azure)
- PTR must match the A record (forward-confirmed reverse DNS)

## SPF/DKIM/DMARC Failures

**Symptom:** Email going to spam, DMARC reports showing failures

**Diagnosis:**
```bash
# Check SPF record
dig TXT example.com | grep spf

# Check DKIM record
dig TXT selector._domainkey.example.com

# Check DMARC record
dig TXT _dmarc.example.com
```

**Fix:**
```dns
; SPF - authorize mail servers
example.com.  TXT  "v=spf1 include:_spf.google.com include:mail.example.com -all"

; DKIM - add public key
selector._domainkey.example.com.  TXT  "v=DKIM1; k=rsa; p=MIGf..."

; DMARC - set policy
_dmarc.example.com.  TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
```

**Validation tools:**
- MXToolbox: https://mxtoolbox.com/
- Google Admin Toolbox: https://toolbox.googleapps.com/apps/checkmx/
