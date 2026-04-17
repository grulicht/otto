# Disk Space Cleanup Runbook

## Quick Assessment
```bash
# Check disk usage overview
df -h

# Find largest directories
du -sh /* 2>/dev/null | sort -rh | head -20

# Find large files
find / -xdev -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -20
```

## Safe Cleanup Actions

### System
```bash
# Clean package manager cache
apt clean                    # Debian/Ubuntu
yum clean all               # RHEL/CentOS
dnf clean all               # Fedora

# Remove old kernels (keep current + one previous)
apt autoremove              # Debian/Ubuntu

# Clean temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Truncate large log files (don't delete - may break logging)
truncate -s 0 /var/log/syslog.1
```

### Docker
```bash
# Remove unused images, containers, volumes, networks
docker system prune -a --volumes

# Check Docker disk usage
docker system df
```

### Kubernetes
```bash
# Clean up completed/failed pods
kubectl delete pods --field-selector=status.phase=Succeeded -A
kubectl delete pods --field-selector=status.phase=Failed -A

# Clean up old ReplicaSets
kubectl get rs -A --no-headers | awk '$3==0 && $4==0' | awk '{print $1, $2}' | while read ns rs; do kubectl delete rs "$rs" -n "$ns"; done
```

### Logs
```bash
# Rotate logs now
logrotate -f /etc/logrotate.conf

# Clean journal logs older than 7 days
journalctl --vacuum-time=7d

# Clean journal logs to max size
journalctl --vacuum-size=500M
```

## Prevention
- Set up log rotation for all services
- Configure Docker to limit container log size
- Monitor disk usage with alerts at 80% and 90%
- Set up automatic cleanup cron jobs for temporary files
