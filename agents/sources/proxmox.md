---
name: proxmox
description: Proxmox VE hypervisor management via REST API
type: api
required_env:
  - OTTO_PROXMOX_URL
  - OTTO_PROXMOX_TOKEN_ID
  - OTTO_PROXMOX_TOKEN_SECRET
required_tools:
  - curl
  - jq
check_command: "curl -sfk -H 'Authorization: PVEAPIToken=${OTTO_PROXMOX_TOKEN_ID}=${OTTO_PROXMOX_TOKEN_SECRET}' '${OTTO_PROXMOX_URL}/api2/json/version' | jq -r '.data.version'"
---

# Proxmox VE

## Connection

OTTO connects to Proxmox VE through the REST API using API tokens.
The `-k` flag is used because Proxmox often uses self-signed certificates.

```bash
PVE_AUTH="PVEAPIToken=${OTTO_PROXMOX_TOKEN_ID}=${OTTO_PROXMOX_TOKEN_SECRET}"
curl -sfk -H "Authorization: ${PVE_AUTH}" "${OTTO_PROXMOX_URL}/api2/json/<endpoint>"
```

## Available Data

- **Nodes**: Cluster nodes, status, and resources
- **VMs (QEMU)**: Virtual machine management
- **Containers (LXC)**: LXC container management
- **Storage**: Storage pools, volumes, and usage
- **Network**: Network configuration and bridges
- **Cluster**: Cluster status, HA, and resources
- **Tasks**: Running and completed task log

## Common Queries

### List all VMs across nodes
```bash
curl -sfk -H "Authorization: ${PVE_AUTH}" \
  "${OTTO_PROXMOX_URL}/api2/json/cluster/resources?type=vm" | \
  jq '.data[] | {vmid, name, status, node, cpu, maxmem, type}'
```

### Get node status
```bash
curl -sfk -H "Authorization: ${PVE_AUTH}" \
  "${OTTO_PROXMOX_URL}/api2/json/nodes" | \
  jq '.data[] | {node, status, cpu, maxcpu, mem, maxmem}'
```

### List storage
```bash
curl -sfk -H "Authorization: ${PVE_AUTH}" \
  "${OTTO_PROXMOX_URL}/api2/json/storage" | \
  jq '.data[] | {storage, type, content, nodes}'
```

### Start/stop a VM
```bash
# Start
curl -sfk -X POST -H "Authorization: ${PVE_AUTH}" \
  "${OTTO_PROXMOX_URL}/api2/json/nodes/<node>/qemu/<vmid>/status/start"
# Stop
curl -sfk -X POST -H "Authorization: ${PVE_AUTH}" \
  "${OTTO_PROXMOX_URL}/api2/json/nodes/<node>/qemu/<vmid>/status/stop"
```
