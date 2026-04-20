---
name: backup-status
description: General backup status aggregator for Restic, Borg, and Velero
type: cli
required_env: []
required_tools:
  - restic
  - borg
  - velero
check_command: "restic version 2>/dev/null || borg --version 2>/dev/null || velero version --client-only 2>/dev/null"
---

# Backup Status

## Connection

OTTO aggregates backup status from multiple backup tools. It checks whichever
tools are available (Restic, Borg, Velero) and presents a unified view.

```bash
restic version 2>/dev/null && echo "restic available"
borg --version 2>/dev/null && echo "borg available"
velero version --client-only 2>/dev/null && echo "velero available"
```

## Available Data

- **Last backup time**: When each repository was last backed up
- **Backup size**: Repository and snapshot sizes
- **Backup health**: Integrity check results
- **Snapshot list**: Available restore points
- **Backup schedules**: Expected vs actual backup times
- **Errors**: Failed backup attempts and error details

## Common Queries

### Restic - list recent snapshots
```bash
restic -r "$RESTIC_REPOSITORY" snapshots --latest 5 --json 2>/dev/null | jq '.[].time'
```

### Borg - list recent archives
```bash
borg list --last 5 --json "$BORG_REPO" 2>/dev/null | jq '.archives[].start'
```

### Velero - list recent backups
```bash
velero backup get --output json 2>/dev/null | jq '.items[] | {name: .metadata.name, status: .status.phase, started: .status.startTimestamp}'
```

### Check for stale backups (no backup in 24h)
```bash
last=$(restic -r "$RESTIC_REPOSITORY" snapshots --latest 1 --json 2>/dev/null | jq -r '.[0].time')
echo "Last backup: $last"
```
