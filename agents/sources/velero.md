---
name: velero
description: Velero Kubernetes backup and disaster recovery monitoring
type: cli
required_env: []
required_tools:
  - velero
check_command: "velero version --client-only 2>/dev/null"
---

# Velero

## Connection

OTTO connects to Velero through the `velero` CLI, which communicates with the
Velero server running in the Kubernetes cluster via kubeconfig.

```bash
velero version            # verify client and server connectivity
```

## Available Data

- **Backups**: Backup status, timestamps, included resources
- **Schedules**: Configured backup schedules and last run times
- **Restores**: Restore operations and their status
- **Backup locations**: Storage locations and their availability
- **Snapshot locations**: Volume snapshot location status
- **Plugins**: Installed Velero plugins

## Common Queries

### List recent backups
```bash
velero backup get
```

### Backup details
```bash
velero backup describe <backup-name> --details
```

### List schedules
```bash
velero schedule get
```

### Check backup locations
```bash
velero backup-location get
```

### List restores
```bash
velero restore get
```

### Backup logs
```bash
velero backup logs <backup-name>
```

### Failed backups
```bash
velero backup get --output json | jq '[.items[] | select(.status.phase != "Completed") | {name: .metadata.name, phase: .status.phase}]'
```
