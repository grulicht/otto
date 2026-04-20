# General Cloud Troubleshooting

## Network Connectivity Issues
**Symptoms:** Services cannot communicate, timeouts, connection refused.
**Steps:**
1. Verify security groups / firewall rules allow traffic on required ports
2. Check network ACLs (stateless rules - need both directions)
3. Verify route tables have correct routes (especially for VPC peering, transit gateway)
4. Test connectivity: `telnet <host> <port>`, `nc -zv <host> <port>`
5. Check DNS resolution: `nslookup <hostname>`, `dig <hostname>`
6. Verify VPN/peering connections are active
7. Check for MTU issues: `ping -M do -s 1472 <host>` (fragmentation)
8. Use VPC flow logs or network monitoring to trace packets

## DNS Propagation Delays
**Symptoms:** DNS changes not reflected, old IP returned, intermittent resolution.
**Steps:**
1. Check TTL on the record being changed - propagation takes up to TTL seconds
2. Verify change was applied: `dig @<authoritative-ns> <domain>`
3. Check from multiple resolvers: `dig @8.8.8.8`, `dig @1.1.1.1`
4. Clear local DNS cache: `systemd-resolve --flush-caches` (Linux), `dscacheutil -flushcache` (macOS)
5. Check for cached negative responses (NXDOMAIN caching)
6. Lower TTL before making changes, wait for old TTL to expire, then change
7. If using Route53: check hosted zone ID, alias vs CNAME behavior

## Certificate Errors
**Symptoms:** `SSL_ERROR`, `certificate verify failed`, browser security warnings.
**Steps:**
1. Check certificate validity: `openssl s_client -connect <host>:443 -servername <host>`
2. Verify full chain is served: intermediate certificates must be included
3. Check expiration: `echo | openssl s_client -connect <host>:443 2>/dev/null | openssl x509 -dates`
4. Verify domain matches: SAN/CN must match the requested hostname
5. Check for mixed content (HTTP resources on HTTPS page)
6. If Let's Encrypt: check auto-renewal (`certbot renew --dry-run`)
7. Cloud-specific: verify ACM certificate is in correct region (CloudFront needs us-east-1)
8. Check for CAA records that might block issuance

## API Rate Limiting
**Symptoms:** `429 Too Many Requests`, `ThrottlingException`, `Rate exceeded`.
**Steps:**
1. Check response headers for rate limit info: `X-RateLimit-*`, `Retry-After`
2. Implement exponential backoff with jitter
3. Cache API responses where possible
4. Use batch/bulk API endpoints instead of individual calls
5. Request rate limit increase from provider if legitimate need
6. Distribute requests across multiple credentials/regions if allowed
7. AWS-specific: use API Gateway caching, or switch to eventual consistency reads
8. Monitor API call patterns to find the source of excessive calls

## Regional Outages
**Symptoms:** Services down in specific region, status page shows issues.
**Steps:**
1. Check provider status page: AWS (health.aws.amazon.com), GCP (status.cloud.google.com), Azure (status.azure.com)
2. Verify if issue is regional: test from other regions
3. Check if multi-region failover is configured and working
4. Switch DNS to healthy region (if multi-region DNS is configured)
5. Notify stakeholders with ETA based on provider communication
6. Document the incident timeline for postmortem
7. Post-outage: verify data consistency across regions
8. Review: should you add multi-region redundancy?
