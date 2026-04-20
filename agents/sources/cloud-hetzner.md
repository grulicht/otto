---
name: cloud-hetzner
description: Hetzner Cloud infrastructure overview
type: cli
required_env: []
required_tools:
  - hcloud
check_command: "hcloud version 2>/dev/null"
---

# Cloud - Hetzner

## Connection

Alias for the `hetzner` source. OTTO connects to Hetzner Cloud through the
`hcloud` CLI. See `agents/sources/hetzner.md` for full authentication details.

```bash
hcloud context active     # verify authentication context
```

## Available Data

- **Servers**: Virtual machines, types, images, datacenters
- **Load Balancers**: L4/L7 load balancers and targets
- **Networking**: Networks, subnets, floating IPs, firewalls
- **Storage**: Volumes, snapshots, images
- **SSH Keys**: Registered SSH keys

## Common Queries

### List servers
```bash
hcloud server list -o columns=id,name,status,ipv4,datacenter,server_type
```

### Load balancers
```bash
hcloud load-balancer list
```

### Volumes
```bash
hcloud volume list -o columns=id,name,size,server,location
```

### Firewalls
```bash
hcloud firewall list
```

### Floating IPs
```bash
hcloud floating-ip list -o columns=id,ip,type,server,location
```
