---
name: cloud-digitalocean
description: DigitalOcean cloud infrastructure overview
type: cli
required_env: []
required_tools:
  - doctl
check_command: "doctl account get --format Email --no-header 2>/dev/null"
---

# Cloud - DigitalOcean

## Connection

OTTO connects to DigitalOcean through the `doctl` CLI. Authentication is
handled via `doctl auth init` or the `DIGITALOCEAN_ACCESS_TOKEN` environment
variable.

```bash
doctl account get       # verify authentication
```

## Available Data

- **Droplets**: Virtual machines, sizes, images, regions
- **Kubernetes**: DOKS clusters, node pools
- **Databases**: Managed database clusters
- **Networking**: Load balancers, firewalls, domains, floating IPs
- **Storage**: Volumes, Spaces (S3-compatible object storage)
- **Monitoring**: Alerts and uptime checks

## Common Queries

### List droplets
```bash
doctl compute droplet list --format ID,Name,PublicIPv4,Region,Status,Memory,VCPUs
```

### Kubernetes clusters
```bash
doctl kubernetes cluster list --format ID,Name,Region,Version,Status,NodePools
```

### Database clusters
```bash
doctl databases list --format ID,Name,Engine,Version,Status,Region
```

### Load balancers
```bash
doctl compute load-balancer list --format ID,Name,IP,Status,Region
```

### Volumes
```bash
doctl compute volume list --format ID,Name,Size,Region,DropletIDs
```
