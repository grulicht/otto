---
name: server-health
description: Local server health monitoring via CLI for CPU, RAM, disk, and load metrics
type: cli
required_env: []
required_tools:
  - free
  - df
  - uptime
check_command: "uptime 2>/dev/null | awk '{print $1}'"
---

# Server Health

## Connection

OTTO monitors local server health through standard Linux CLI utilities. No
external services or authentication required -- all data comes from the local
system.

```bash
uptime          # verify system is responding
uname -a        # show kernel and OS info
```

## Available Data

- **CPU**: Load averages, per-core usage, top processes
- **Memory**: Total, used, free, available, swap usage
- **Disk**: Filesystem usage, inode usage, mount points
- **Load**: 1/5/15-minute load averages
- **Processes**: Running, sleeping, zombie process counts
- **Uptime**: System uptime and boot time

## Common Queries

### System load overview
```bash
uptime
```

### Memory usage
```bash
free -h
```

### Disk usage
```bash
df -h --output=source,fstype,size,used,avail,pcent,target | grep -v tmpfs
```

### Inode usage
```bash
df -i | grep -v tmpfs
```

### Top CPU-consuming processes
```bash
ps aux --sort=-%cpu | head -15
```

### Top memory-consuming processes
```bash
ps aux --sort=-%mem | head -15
```

### Check for zombie processes
```bash
ps aux | awk '$8=="Z" {print}'
```
