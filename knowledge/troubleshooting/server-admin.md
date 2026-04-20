# Server Administration Troubleshooting

## Systemd Service Won't Start

**Steps:**
1. `systemctl status <service>` -- check status and recent logs
2. `journalctl -u <service> -n 50 --no-pager` -- detailed logs
3. `systemctl cat <service>` -- verify unit file syntax
4. `systemd-analyze verify <service>` -- validate unit file
5. Common causes: wrong ExecStart path, missing User/Group, dependency not met
6. Check `After=` and `Requires=` dependencies are running
7. If "start limit hit": `systemctl reset-failed <service>` then retry

## Cron Not Running

**Steps:**
1. Check cron service: `systemctl status cron` (or `crond`)
2. Check crontab: `crontab -l` (user) or `cat /etc/crontab` (system)
3. Check cron logs: `grep CRON /var/log/syslog` or `journalctl -u cron`
4. Verify PATH -- cron has minimal PATH, use absolute paths
5. Check permissions on cron script: must be executable
6. Ensure no `%` in cron command (escape as `\%`)
7. Check `/etc/cron.allow` and `/etc/cron.deny`

## Disk Full

**Steps:**
1. `df -h` -- identify full filesystem
2. `du -sh /* 2>/dev/null | sort -rh | head -20` -- find largest directories
3. Common culprits: `/var/log`, `/tmp`, Docker images, old kernels
4. Quick fixes:
   - `journalctl --vacuum-size=500M` -- trim journal logs
   - `docker system prune -a` -- clean Docker
   - `apt autoremove` -- remove old kernels (Debian/Ubuntu)
5. Find large files: `find / -xdev -type f -size +100M -exec ls -lh {} \;`

## Inode Exhaustion

**Symptoms:** "No space left on device" but `df -h` shows free space.
**Steps:**
1. `df -i` -- check inode usage
2. Find directories with many small files: `find / -xdev -printf '%h\n' | sort | uniq -c | sort -rn | head -20`
3. Common causes: mail queue, session files, cache directories
4. Clean up: remove stale temp/cache/session files

## Time Sync (NTP/Chrony)

**Symptoms:** Clock drift, TLS cert errors due to wrong time, log timestamps wrong.
**Steps:**
1. Check current time: `timedatectl`
2. For chrony: `chronyc tracking` and `chronyc sources`
3. For NTP: `ntpq -p`
4. Force sync: `chronyc makestep` or `ntpdate pool.ntp.org`
5. Ensure NTP service enabled: `timedatectl set-ntp true`

## Package Dependency Hell

**Debian/Ubuntu:**
1. `apt --fix-broken install`
2. `dpkg --configure -a`
3. Pin problematic package: `apt-mark hold <package>`
4. Last resort: `aptitude` often finds better resolution paths

**RHEL/CentOS:**
1. `yum check` / `dnf check`
2. `yum history undo <id>` -- revert a transaction
3. `rpm -Va` -- verify all packages

## Kernel Panic Recovery

**Steps:**
1. Boot into previous kernel from GRUB menu
2. Check `/var/log/kern.log` or `journalctl -k -b -1` for panic details
3. Common causes: bad kernel update, driver issue, filesystem corruption
4. Fix GRUB default: edit `/etc/default/grub` -> `GRUB_DEFAULT=<index>`
5. `fsck` from recovery mode if filesystem corruption suspected
6. Remove bad kernel: `apt remove linux-image-<version>`

## SSH Key Issues

**Can't log in with SSH key:**
1. Check permissions: `~/.ssh/` must be `700`, `authorized_keys` must be `600`
2. Check ownership: must be owned by the target user
3. Verify key type is accepted: `PubkeyAcceptedAlgorithms` in `sshd_config`
4. Check `AuthorizedKeysFile` path in sshd_config
5. Debug: `ssh -vvv user@host` on client side
6. Server side: `journalctl -u sshd -f` during connection attempt
7. SELinux: `restorecon -Rv ~/.ssh/`

## Sudo Permission Denied

**Steps:**
1. Check user groups: `id <user>` -- should be in `sudo` or `wheel` group
2. Check sudoers: `visudo` or files in `/etc/sudoers.d/`
3. Verify no syntax errors: `visudo -c`
4. If locked out: boot into recovery/single-user mode
5. Check `Defaults requiretty` -- may block non-interactive sudo
6. For specific command access: add `<user> ALL=(ALL) NOPASSWD: /path/to/command`
