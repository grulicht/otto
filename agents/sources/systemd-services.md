---
name: systemd-services
description: Systemd service monitoring via systemctl
type: cli
required_env: []
required_tools:
  - systemctl
check_command: "systemctl --version 2>/dev/null | head -1"
---

# Systemd Services

## Connection

OTTO monitors systemd services through the `systemctl` CLI. No additional
authentication required for status queries.

```bash
systemctl --version    # verify systemd availability
```

## Available Data

- **Service status**: Running, stopped, failed, inactive states
- **Failed units**: Services that have failed to start
- **Timers**: Scheduled timer units and next execution times
- **Journal logs**: Per-service log output via journalctl
- **Dependencies**: Service dependency trees
- **Resource usage**: CPU and memory per service (via systemd cgroups)

## Common Queries

### List failed services
```bash
systemctl --failed --no-pager
```

### Check specific service status
```bash
systemctl status <service> --no-pager -l
```

### List all active services
```bash
systemctl list-units --type=service --state=running --no-pager
```

### List timers
```bash
systemctl list-timers --no-pager
```

### View recent service logs
```bash
journalctl -u <service> --since "1 hour ago" --no-pager -l
```

### Service resource usage
```bash
systemctl show <service> --property=MemoryCurrent,CPUUsageNSec --no-pager
```

### List enabled services
```bash
systemctl list-unit-files --type=service --state=enabled --no-pager
```
