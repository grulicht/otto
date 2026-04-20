---
name: security-events
description: Local security event monitoring via journalctl and lastb
type: cli
required_env: []
required_tools:
  - journalctl
  - lastb
check_command: "journalctl --version 2>/dev/null | head -1"
---

# Security Events

## Connection

OTTO monitors local security events through system log utilities. No external
services required -- all data comes from the local journal and auth logs.

```bash
journalctl --version     # verify journald availability
```

## Available Data

- **Failed logins**: SSH brute force attempts, failed sudo, failed console logins
- **Authentication events**: Successful and failed auth attempts
- **Sudo usage**: Commands executed via sudo
- **SSH sessions**: Active and recent SSH sessions
- **Service changes**: Systemd unit file modifications
- **Firewall events**: Dropped/rejected packets from iptables/nftables logs
- **Audit events**: SELinux/AppArmor denials

## Common Queries

### Failed login attempts
```bash
lastb -n 20 2>/dev/null
```

### Recent SSH auth failures
```bash
journalctl -u sshd --since "1 hour ago" --no-pager | grep -i "failed\|invalid"
```

### Sudo commands executed
```bash
journalctl _COMM=sudo --since "24 hours ago" --no-pager | tail -30
```

### Currently logged-in users
```bash
who -u
```

### Recent auth log summary
```bash
journalctl -t sshd -t sudo -t su --since "24 hours ago" --no-pager --output short-iso | tail -50
```

### SELinux/AppArmor denials
```bash
journalctl --since "24 hours ago" --no-pager | grep -i "denied\|apparmor" | tail -20
```

### Failed password attempts by IP
```bash
journalctl -u sshd --since "24 hours ago" --no-pager | grep "Failed password" | \
  awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -10
```
