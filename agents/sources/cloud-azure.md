---
name: cloud-azure
description: Azure cloud infrastructure overview (alias for azure source)
type: cli
required_env: []
required_tools:
  - az
check_command: "az account show --output json 2>/dev/null | jq -r '.id'"
---

# Cloud - Azure

## Connection

Alias for the `azure` source. OTTO connects to Azure through the `az` CLI.
See `agents/sources/azure.md` for full authentication details.

```bash
az account show           # verify authentication
az account list --output table  # list subscriptions
```

## Available Data

- **Compute**: VMs, App Services, AKS clusters, Functions
- **Storage**: Storage accounts, Blob containers, File shares
- **Database**: Azure SQL, Cosmos DB, PostgreSQL Flexible Server
- **Networking**: VNets, NSGs, Load Balancers, Application Gateways
- **Monitoring**: Azure Monitor alerts and metrics
- **Cost**: Consumption and budget status

## Common Queries

### List VMs
```bash
az vm list --output table --query '[].{Name:name,RG:resourceGroup,State:powerState,Size:hardwareProfile.vmSize}'
```

### AKS clusters
```bash
az aks list --output table
```

### Active alerts
```bash
az monitor metrics alert list --output table
```

### Resource groups
```bash
az group list --output table
```
