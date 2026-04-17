# Networking Best Practices
tags: networking, firewall, tls, dns, vpn, security, zero-trust

## Firewall Rules

- Default deny all inbound, allow all outbound
- Allow only necessary ports per service
- Use security groups / network ACLs in cloud environments
- Log denied traffic for auditing
- Review rules quarterly; remove unused entries
- Use named rules with descriptions for auditability

```bash
# UFW example
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.0.0.0/8 to any port 22 proto tcp comment "SSH from internal"
ufw allow 443/tcp comment "HTTPS"
ufw enable
```

## TLS Configuration

- Minimum TLS 1.2, prefer TLS 1.3
- Disable weak ciphers (RC4, DES, 3DES, export ciphers)
- Use strong key sizes: RSA 2048+ or ECDSA P-256+
- Enable HSTS (HTTP Strict Transport Security)
- Automate certificate renewal (Let's Encrypt / certbot)
- Use Mozilla SSL Configuration Generator for settings

```nginx
# Modern TLS config
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_prefer_server_ciphers off;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
add_header Strict-Transport-Security "max-age=63072000" always;
```

## DNS Management

- Use infrastructure-as-code for DNS records (Terraform, OctoDNS)
- Set appropriate TTLs: low (300s) for dynamic, high (86400s) for static
- Always have at least 2 nameservers in different networks
- Monitor DNS resolution and propagation
- Implement DNSSEC where possible
- Document all DNS records and their purpose

## VPN Setup

- Use WireGuard for simplicity and performance
- Use IPSec (strongSwan) for enterprise/compliance requirements
- Rotate keys regularly
- Use split tunneling only when necessary
- Monitor VPN connection health
- Implement MFA for VPN access

```ini
# WireGuard example config
[Interface]
PrivateKey = <server-private-key>
Address = 10.200.0.1/24
ListenPort = 51820

[Peer]
PublicKey = <client-public-key>
AllowedIPs = 10.200.0.2/32
```

## Network Segmentation

- Separate environments (prod, staging, dev) into different VPCs/VLANs
- Use private subnets for databases and internal services
- Place load balancers and bastion hosts in public subnets
- Implement micro-segmentation for sensitive workloads
- Use network policies in Kubernetes

```yaml
# Kubernetes NetworkPolicy - deny all, allow specific
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

## Zero Trust Principles

- Never trust, always verify -- regardless of network location
- Authenticate and authorize every request
- Use mutual TLS (mTLS) for service-to-service communication
- Implement least-privilege access
- Encrypt all traffic, even internal
- Continuously monitor and log all access
- Use identity-aware proxies (e.g., BeyondCorp, Tailscale, Cloudflare Access)
- Rotate credentials automatically
