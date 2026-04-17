# Ansible Troubleshooting Guide
tags: ansible, automation, configuration-management

## Connection Failures

**Symptom:** `UNREACHABLE!` or `Failed to connect to the host via ssh`

**Diagnosis:**
1. Verify SSH connectivity: `ssh -vvv user@host`
2. Check inventory host/IP is correct
3. Verify SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
4. Check `ansible_user`, `ansible_ssh_private_key_file` variables
5. Ensure Python is installed on remote: `ansible_python_interpreter=/usr/bin/python3`

**Fix:**
```bash
# Test connectivity
ansible all -m ping -i inventory.yml

# Force specific SSH args
ansible all -m ping -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'
```

## Privilege Escalation Failures

**Symptom:** `Missing sudo password` or `Incorrect sudo password`

**Diagnosis:**
1. Verify `become: true` is set
2. Check `become_method` (sudo, su, pbrun, etc.)
3. Ensure user has sudo rights on target
4. Check if password is required vs passwordless sudo

**Fix:**
```bash
# Prompt for become password
ansible-playbook site.yml --ask-become-pass

# Or set in inventory
# ansible_become_password: "{{ vault_sudo_pass }}"
```

## Variable Precedence Issues

**Symptom:** Unexpected variable values, overridden settings

**Diagnosis:**
Ansible variable precedence (lowest to highest):
1. Role defaults (`roles/x/defaults/main.yml`)
2. Inventory vars
3. Inventory group_vars
4. Inventory host_vars
5. Playbook group_vars
6. Playbook host_vars
7. Host facts
8. Play vars
9. Role vars (`roles/x/vars/main.yml`)
10. Task vars
11. Extra vars (`-e`)

**Fix:**
```bash
# Debug variable origin
ansible -m debug -a "var=my_variable" hostname

# Show all vars for a host
ansible -m setup hostname
```

## Module Not Found

**Symptom:** `ERROR! couldn't resolve module/action 'community.general.xxx'`

**Diagnosis:**
1. Check if collection is installed: `ansible-galaxy collection list`
2. Verify `collections/requirements.yml` is complete
3. Check Ansible version compatibility

**Fix:**
```bash
# Install missing collection
ansible-galaxy collection install community.general

# Install from requirements
ansible-galaxy collection install -r collections/requirements.yml
```

## Vault Decrypt Errors

**Symptom:** `Decryption failed` or `Attempting to decrypt but no vault secrets found`

**Diagnosis:**
1. Verify vault password/file is correct
2. Check file was encrypted with correct vault ID
3. Ensure vault password file permissions are 600

**Fix:**
```bash
# Re-encrypt with correct password
ansible-vault rekey encrypted_file.yml

# Specify vault password file
ansible-playbook site.yml --vault-password-file=~/.vault_pass
```

## Slow Playbook Execution

**Symptom:** Playbooks take excessively long to complete

**Diagnosis:**
1. Check for `gather_facts: true` when facts are not needed
2. Look for serial execution where parallel is possible
3. Check network latency to hosts
4. Review handler usage (should use `listen` for batching)

**Fix:**
```yaml
# Disable fact gathering if not needed
- hosts: all
  gather_facts: false

# Increase parallelism
# In ansible.cfg:
# [defaults]
# forks = 20
# strategy = free

# Use async for long tasks
- name: Long running task
  command: /usr/bin/long_task
  async: 3600
  poll: 10
```
