# Backup Integrations

OTTO supports monitoring and managing backups through Restic, BorgBackup, and
Velero. The backup specialist agent aggregates status from all configured backup
tools and alerts on missed or failed backups.

## Restic

### Setup

1. Install Restic: `apt install restic` or download from [restic.net](https://restic.net)
2. Initialize a repository:
   ```bash
   export RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-backup-bucket
   export RESTIC_PASSWORD=your-repo-password
   restic init
   ```
3. Configure OTTO environment (`~/.config/otto/.env`):
   ```bash
   RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-backup-bucket
   RESTIC_PASSWORD_FILE=/etc/restic/password
   # For S3 backend:
   AWS_ACCESS_KEY_ID=your-key
   AWS_SECRET_ACCESS_KEY=your-secret
   ```

### What OTTO Monitors

- Latest snapshot timestamp and age
- Snapshot count and sizes
- Repository integrity (periodic `restic check`)
- Backup duration trends
- Stale backup alerts (configurable threshold, default 24h)

### Configuration

In `~/.config/otto/config.yaml`:
```yaml
backup:
  restic:
    enabled: true
    stale_threshold: 24h
    check_integrity: weekly
    repositories:
      - name: production-db
        repo: s3:s3.amazonaws.com/prod-db-backup
        password_file: /etc/restic/prod-db.pass
      - name: app-data
        repo: /mnt/backup/app-data
        password_file: /etc/restic/app-data.pass
```

## BorgBackup

### Setup

1. Install Borg: `apt install borgbackup`
2. Initialize a repository:
   ```bash
   export BORG_REPO=/mnt/backup/borg-repo
   export BORG_PASSPHRASE=your-passphrase
   borg init --encryption=repokey
   ```
3. Configure OTTO environment (`~/.config/otto/.env`):
   ```bash
   BORG_REPO=/mnt/backup/borg-repo
   BORG_PASSPHRASE=your-passphrase
   # Or for remote:
   BORG_REPO=ssh://backup@server/./repo
   ```

### What OTTO Monitors

- Latest archive timestamp and age
- Archive count and repository size (original vs deduplicated)
- Repository integrity (`borg check`)
- Compression ratios and deduplication efficiency
- Stale backup alerts

### Configuration

In `~/.config/otto/config.yaml`:
```yaml
backup:
  borg:
    enabled: true
    stale_threshold: 24h
    check_integrity: weekly
    repositories:
      - name: server-backup
        repo: /mnt/backup/borg-repo
      - name: remote-backup
        repo: ssh://backup@nas.local/./server
```

## Velero

### Setup

1. Install Velero CLI: download from [velero.io](https://velero.io)
2. Install Velero in your Kubernetes cluster:
   ```bash
   velero install \
     --provider aws \
     --bucket my-velero-bucket \
     --secret-file ./credentials-velero \
     --backup-location-config region=us-east-1 \
     --snapshot-location-config region=us-east-1
   ```
3. Create a backup schedule:
   ```bash
   velero schedule create daily-backup --schedule="0 2 * * *" --ttl 720h
   ```

### What OTTO Monitors

- Backup completion status and phase
- Schedule adherence (missed schedules)
- Backup location availability
- Restore operations and their status
- Failed backups with error details

### Configuration

In `~/.config/otto/config.yaml`:
```yaml
backup:
  velero:
    enabled: true
    stale_threshold: 24h
    expected_schedules:
      - daily-backup
      - hourly-db-backup
```

## Alerting

OTTO sends backup alerts through configured communication channels:

| Condition | Severity | Default Action |
|-----------|----------|---------------|
| Backup older than threshold | warning | Notify via Slack/email |
| Backup failed | critical | Immediate alert |
| Repository integrity error | critical | Immediate alert + create incident |
| Backup size anomaly (>50% change) | warning | Notify via Slack/email |
| Backup location unreachable | critical | Immediate alert |

## Troubleshooting

Common backup issues are documented in:
- `knowledge/troubleshooting/backup-failures.md`
- Run `otto troubleshoot backup failing` for interactive troubleshooting
