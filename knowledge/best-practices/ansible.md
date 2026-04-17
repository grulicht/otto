# Ansible Best Practices
tags: ansible, automation, configuration-management, iac

## Directory Structure

Follow the standard Ansible directory layout:

```
project/
  ansible.cfg
  inventory/
    production/
      hosts.yml
      group_vars/
        all.yml
        webservers.yml
      host_vars/
        web1.yml
    staging/
      hosts.yml
      group_vars/
  playbooks/
    site.yml
    webservers.yml
    dbservers.yml
  roles/
    common/
      tasks/main.yml
      handlers/main.yml
      templates/
      files/
      vars/main.yml
      defaults/main.yml
      meta/main.yml
    webserver/
    database/
  collections/
    requirements.yml
  group_vars/
  host_vars/
  library/           # custom modules
  filter_plugins/    # custom filters
```

## Role Organization

- One role per logical service/component
- Keep roles small and focused (single responsibility)
- Use `meta/main.yml` to declare role dependencies
- Prefix internal variables with the role name: `webserver_port`
- Always provide sensible defaults in `defaults/main.yml`
- Use `molecule` for role testing

## Variable Management

- Use `group_vars/all.yml` for global defaults
- Override per environment in inventory `group_vars/`
- Never put secrets in plain text -- use Ansible Vault
- Document all variables in `defaults/main.yml` with comments
- Use meaningful variable names with role prefix

```yaml
# Good
webserver_listen_port: 8080
webserver_max_connections: 1024

# Bad
port: 8080
max: 1024
```

## Vault Usage

- Encrypt sensitive files: `ansible-vault encrypt secrets.yml`
- Use vault IDs for multiple passwords: `--vault-id dev@prompt`
- Store vault password in a file (excluded from git): `--vault-password-file=.vault_pass`
- Encrypt only sensitive variables, not entire files when possible
- Use `ansible-vault encrypt_string` for inline encrypted values

```bash
# Encrypt a string
ansible-vault encrypt_string 'supersecret' --name 'db_password'

# Use in playbook
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...
```

## Idempotency

- Every task should be safe to run multiple times
- Use modules instead of `command`/`shell` when possible
- When using `command`/`shell`, always add `creates` or `changed_when`
- Test idempotency: run playbook twice, second run should have 0 changes

```yaml
# Good - idempotent
- name: Install packages
  apt:
    name: "{{ packages }}"
    state: present

# Bad - not idempotent
- name: Install packages
  command: apt-get install -y nginx

# Acceptable with guard
- name: Initialize database
  command: /usr/local/bin/init-db.sh
  args:
    creates: /var/lib/myapp/.initialized
```

## Testing with Molecule

- Write Molecule tests for every role
- Test on multiple OS versions
- Include verify steps (not just convergence)
- Run in CI/CD pipeline

```bash
# Initialize molecule for a role
cd roles/webserver
molecule init scenario --driver-name docker

# Run full test cycle
molecule test

# Just converge and verify
molecule converge && molecule verify
```

## General Tips

- Always name your tasks descriptively
- Use `handlers` for service restarts (avoid restarting in tasks)
- Use `tags` to allow selective execution
- Use `block/rescue/always` for error handling
- Prefer `include_role` over `include_tasks` for reusability
- Pin collection versions in `requirements.yml`
- Use `--diff --check` for dry runs
- Lint with `ansible-lint` in CI
