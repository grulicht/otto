---
name: restic
description: Restic backup repository monitoring via restic CLI
type: cli
required_env:
  - RESTIC_REPOSITORY
required_tools:
  - restic
check_command: "restic version 2>/dev/null"
---

# Restic

## Connection

OTTO connects to Restic repositories via the `restic` CLI. Set
`RESTIC_REPOSITORY` to the repository location and `RESTIC_PASSWORD` or
`RESTIC_PASSWORD_FILE` for decryption.

```bash
restic -r "$RESTIC_REPOSITORY" snapshots --latest 1    # verify access
```

Supported backends: local, SFTP, S3, Azure Blob, GCS, Backblaze B2, REST server.

## Available Data

- **Snapshots**: List of snapshots with timestamps, hosts, paths, and tags
- **Repository stats**: Total size, data blobs, tree blobs
- **Integrity**: Repository consistency and data verification
- **Differences**: Changes between snapshots
- **Locks**: Active repository locks

## Common Queries

### List recent snapshots
```bash
restic -r "$RESTIC_REPOSITORY" snapshots --latest 10
```

### Snapshot details (JSON)
```bash
restic -r "$RESTIC_REPOSITORY" snapshots --json | jq '.[-1] | {time, hostname, paths, tags}'
```

### Repository stats
```bash
restic -r "$RESTIC_REPOSITORY" stats
```

### Check repository integrity
```bash
restic -r "$RESTIC_REPOSITORY" check
```

### Diff between snapshots
```bash
restic -r "$RESTIC_REPOSITORY" diff <snapshot1> <snapshot2>
```

### Remove stale locks
```bash
restic -r "$RESTIC_REPOSITORY" unlock
```
