---
name: borg
description: BorgBackup repository monitoring via borg CLI
type: cli
required_env:
  - BORG_REPO
required_tools:
  - borg
check_command: "borg --version 2>/dev/null"
---

# BorgBackup

## Connection

OTTO connects to BorgBackup repositories via the `borg` CLI. Set `BORG_REPO`
to the repository path or remote location. For encrypted repos, set
`BORG_PASSPHRASE` or `BORG_PASSCOMMAND`.

```bash
borg info "$BORG_REPO"    # verify repository access
```

## Available Data

- **Archives**: List of backup archives with timestamps and sizes
- **Repository info**: Total size, deduplicated size, encryption mode
- **Archive contents**: Files and directories in each archive
- **Integrity**: Repository and archive consistency checks
- **Compaction**: Repository compaction status

## Common Queries

### List recent archives
```bash
borg list --last 10 "$BORG_REPO"
```

### Repository info
```bash
borg info "$BORG_REPO"
```

### Archive details
```bash
borg info "$BORG_REPO"::<archive_name>
```

### Check repository integrity
```bash
borg check --verify-data "$BORG_REPO"
```

### List archive contents
```bash
borg list "$BORG_REPO"::<archive_name> | head -50
```

### Repository size (JSON)
```bash
borg info --json "$BORG_REPO" | jq '.repository | {total_size, unique_size: .unique_csize}'
```
