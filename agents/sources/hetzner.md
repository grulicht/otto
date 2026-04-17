---
name: hetzner
description: Hetzner Cloud API for server, network, and volume management
type: api
required_env:
  - OTTO_HETZNER_API_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: Bearer ${OTTO_HETZNER_API_TOKEN}' 'https://api.hetzner.cloud/v1/servers?per_page=1' | jq -r '.meta.pagination.total_entries'"
---

# Hetzner Cloud

## Connection

OTTO connects to Hetzner Cloud through the REST API using a project API token.

```bash
curl -sf "https://api.hetzner.cloud/v1/<endpoint>" \
  -H "Authorization: Bearer ${OTTO_HETZNER_API_TOKEN}"
```

## Available Data

- **Servers**: Create, manage, and monitor cloud servers
- **Volumes**: Block storage volumes
- **Networks**: Private networks and subnets
- **Firewalls**: Firewall rules and assignments
- **Load Balancers**: L4/L7 load balancer management
- **Floating IPs**: Elastic IP addresses
- **SSH Keys**: SSH key management
- **Images**: OS images and snapshots

## Common Queries

### List servers
```bash
curl -sf -H "Authorization: Bearer ${OTTO_HETZNER_API_TOKEN}" \
  "https://api.hetzner.cloud/v1/servers" | \
  jq '.servers[] | {id, name, status, server_type: .server_type.name, datacenter: .datacenter.name, public_ip: .public_net.ipv4.ip}'
```

### Get server metrics
```bash
curl -sf -H "Authorization: Bearer ${OTTO_HETZNER_API_TOKEN}" \
  "https://api.hetzner.cloud/v1/servers/<server-id>/metrics?type=cpu&start=$(date -d '1 hour ago' --iso-8601=seconds)&end=$(date --iso-8601=seconds)" | \
  jq '.metrics.timeseries'
```

### List volumes
```bash
curl -sf -H "Authorization: Bearer ${OTTO_HETZNER_API_TOKEN}" \
  "https://api.hetzner.cloud/v1/volumes" | \
  jq '.volumes[] | {id, name, size, server, status, location: .location.name}'
```

### List firewalls
```bash
curl -sf -H "Authorization: Bearer ${OTTO_HETZNER_API_TOKEN}" \
  "https://api.hetzner.cloud/v1/firewalls" | \
  jq '.firewalls[] | {id, name, rules_count: (.rules | length), applied_to_count: (.applied_to | length)}'
```
