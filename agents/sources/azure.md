---
name: azure
description: Microsoft Azure via az CLI for cloud infrastructure management
type: cli
required_env: []
required_tools:
  - az
  - jq
check_command: "az account show --query 'name' -o tsv 2>/dev/null"
fetch_script: cloud-azure.sh
---

> **Note:** The fetch script for this source is named `cloud-azure.sh` (not `azure.sh`), located in `scripts/fetch/cloud-azure.sh`.

# Microsoft Azure

## Connection

OTTO connects to Azure through the `az` CLI, which handles authentication via
interactive login, service principals, or managed identities.

```bash
az account show              # show current subscription
az account list -o table     # list available subscriptions
```

Authentication methods:
1. Interactive login: `az login`
2. Service principal: `az login --service-principal -u <app-id> -p <secret> --tenant <tenant-id>`
3. Managed identity: `az login --identity`
4. Device code: `az login --use-device-code`

Set subscription with `az account set --subscription <name-or-id>`.

## Available Data

- **VMs**: Virtual machines, scale sets, availability sets
- **AKS**: Azure Kubernetes Service clusters
- **App Service**: Web apps, function apps, slots
- **SQL**: Azure SQL databases and managed instances
- **Storage**: Storage accounts, blobs, file shares
- **Networking**: VNets, NSGs, load balancers, Application Gateway
- **Monitor**: Metrics, alerts, log analytics
- **Key Vault**: Secrets, keys, and certificates
- **Resource Groups**: Resource organization and management
- **Cost Management**: Budgets and cost analysis

## Common Queries

### List VMs
```bash
az vm list -o json | \
  jq '.[] | {name, resourceGroup, location, vmSize: .hardwareProfile.vmSize, powerState: .powerState}'
```

### List AKS clusters
```bash
az aks list -o json | \
  jq '.[] | {name, resourceGroup, location, kubernetesVersion, agentPoolProfiles: [.agentPoolProfiles[] | {name, count, vmSize}]}'
```

### List App Services
```bash
az webapp list -o json | \
  jq '.[] | {name, resourceGroup, state, defaultHostName, kind}'
```

### List SQL databases
```bash
az sql server list -o json | jq -r '.[].name' | while read -r server; do
  az sql db list --server "${server}" -o json 2>/dev/null | \
    jq --arg s "${server}" '.[] | {server: $s, name, status, edition: .sku.tier}'
done
```

### Check Azure Monitor alerts
```bash
az monitor alert list -o json 2>/dev/null | \
  jq '.[] | {name, severity, status: .essentials.monitorCondition}'
```

### List resource groups
```bash
az group list -o json | jq '.[] | {name, location, provisioningState}'
```
