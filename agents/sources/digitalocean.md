---
name: digitalocean
description: DigitalOcean cloud platform via REST API for droplets, databases, and Kubernetes
type: api
required_env:
  - OTTO_DIGITALOCEAN_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: Bearer ${OTTO_DIGITALOCEAN_TOKEN}' 'https://api.digitalocean.com/v2/account' | jq -r '.account.email'"
---

# DigitalOcean

## Connection

OTTO connects to DigitalOcean through the REST API v2 using a personal access token.

```bash
curl -sf "https://api.digitalocean.com/v2/<endpoint>" \
  -H "Authorization: Bearer ${OTTO_DIGITALOCEAN_TOKEN}"
```

## Available Data

- **Droplets**: Create, manage, and monitor virtual machines
- **Kubernetes (DOKS)**: Cluster management
- **Databases**: Managed database clusters
- **Spaces**: S3-compatible object storage
- **Load Balancers**: L4 load balancer management
- **Domains**: DNS management
- **Firewalls**: Cloud firewall rules
- **Monitoring**: Alerts and metrics

## Common Queries

### List droplets
```bash
curl -sf -H "Authorization: Bearer ${OTTO_DIGITALOCEAN_TOKEN}" \
  "https://api.digitalocean.com/v2/droplets?per_page=50" | \
  jq '.droplets[] | {id, name, status, size: .size_slug, region: .region.slug, ip: .networks.v4[0].ip_address}'
```

### List Kubernetes clusters
```bash
curl -sf -H "Authorization: Bearer ${OTTO_DIGITALOCEAN_TOKEN}" \
  "https://api.digitalocean.com/v2/kubernetes/clusters" | \
  jq '.kubernetes_clusters[] | {id, name, region, version: .version_slug, status: .status.state, node_pools: [.node_pools[] | {name, size, count}]}'
```

### List managed databases
```bash
curl -sf -H "Authorization: Bearer ${OTTO_DIGITALOCEAN_TOKEN}" \
  "https://api.digitalocean.com/v2/databases" | \
  jq '.databases[] | {id, name, engine, version, status, region, size}'
```

### List domains and records
```bash
curl -sf -H "Authorization: Bearer ${OTTO_DIGITALOCEAN_TOKEN}" \
  "https://api.digitalocean.com/v2/domains" | \
  jq '.domains[] | {name, ttl}'
```
