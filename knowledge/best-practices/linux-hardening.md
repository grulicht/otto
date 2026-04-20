# Linux Server Hardening Best Practices

## SSH Configuration
- Disable root login: `PermitRootLogin no`
- Use key-based authentication only: `PasswordAuthentication no`
- Change default port (optional, defense in depth)
- Limit SSH access with `AllowUsers` or `AllowGroups`
- Set `MaxAuthTries 3` and `LoginGraceTime 30`
- Enable `ClientAliveInterval 300` and `ClientAliveCountMax 2`
- Use SSH certificates for large-scale management
- Disable X11 forwarding: `X11Forwarding no`
- Use `Match` blocks for per-user/group overrides

## Firewall
- Default deny all incoming, allow all outgoing
- Use `ufw` or `firewalld` for management (iptables/nftables underneath)
- Allow only necessary ports (SSH, HTTP/S, application ports)
- Use rate limiting for SSH: `ufw limit ssh`
- Log dropped packets for analysis
- Review rules regularly and remove stale entries
- Use connection tracking (`conntrack`) for stateful filtering

## Fail2ban
- Install and enable for SSH at minimum
- Configure appropriate `bantime` (1h+), `findtime` (10m), `maxretry` (3-5)
- Add jails for other services: nginx, postfix, dovecot
- Use `ignoreip` to whitelist trusted IPs
- Monitor ban activity: `fail2ban-client status sshd`
- Send alert on repeated bans from same IP

## Unattended Upgrades
- Enable automatic security updates: `unattended-upgrades` (Debian/Ubuntu)
- Configure `dnf-automatic` (RHEL/Fedora)
- Only auto-apply security patches, not all updates
- Configure email notification for applied updates
- Set appropriate reboot policy (auto-reboot or notify)
- Test on staging before enabling on production

## Audit Logging
- Enable `auditd` for system call auditing
- Monitor file access: `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`
- Track privilege escalation: `sudo`, `su`, `setuid`
- Log all authentication events
- Ship audit logs to central SIEM
- Use `ausearch` and `aureport` for analysis
- Key audit rules:
  ```
  -w /etc/passwd -p wa -k identity
  -w /etc/shadow -p wa -k identity
  -w /etc/sudoers -p wa -k sudoers
  -a always,exit -F arch=b64 -S execve -k exec
  ```

## User Management
- Follow principle of least privilege
- Use `sudo` instead of root login
- Create individual accounts - no shared credentials
- Set password policies: minimum length 12+, complexity, expiration
- Disable unused accounts: `usermod -L <user>`
- Review sudoers regularly - avoid `ALL=(ALL) NOPASSWD: ALL`
- Use groups for permission management

## File Permissions
- Set `umask 027` as default
- No world-writable files: `find / -perm -002 -type f`
- Secure sensitive files: `chmod 600 /etc/shadow`
- Use `setfacl` for fine-grained access control when needed
- Remove SUID/SGID from unnecessary binaries
- Mount `/tmp` with `noexec,nosuid,nodev`
- Mount `/var` and `/home` with `nosuid`

## Kernel Parameters
- Disable IP forwarding (unless router): `net.ipv4.ip_forward = 0`
- Enable SYN flood protection: `net.ipv4.tcp_syncookies = 1`
- Disable ICMP redirects: `net.ipv4.conf.all.accept_redirects = 0`
- Enable reverse path filtering: `net.ipv4.conf.all.rp_filter = 1`
- Disable source routing: `net.ipv4.conf.all.accept_source_route = 0`
- Restrict core dumps: `fs.suid_dumpable = 0`
- Randomize address space (ASLR): `kernel.randomize_va_space = 2`
- Apply with `sysctl -p /etc/sysctl.d/99-hardening.conf`

## Additional Measures
- Remove unnecessary packages and services
- Use SELinux (enforcing) or AppArmor
- Enable process accounting: `psacct` / `acct`
- Use AIDE or Tripwire for file integrity monitoring
- Configure NTP with authenticated sources
- Disable USB storage if not needed: `blacklist usb-storage`
