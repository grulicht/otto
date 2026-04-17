---
name: ansible
description: Ansible automation platform via CLI for configuration management and orchestration
type: cli
required_env: []
required_tools:
  - ansible
  - ansible-playbook
  - jq
check_command: "ansible --version | head -1"
---

# Ansible

## Connection

OTTO uses the Ansible CLI tools (`ansible`, `ansible-playbook`, `ansible-inventory`,
`ansible-vault`, `ansible-galaxy`) to manage configuration and orchestration.

Ansible connects to managed hosts via SSH (default) or other connection plugins
(WinRM, Docker, local, etc.). Inventory can be static files, dynamic inventory
scripts, or inventory plugins.

```bash
ansible --version             # verify installation
ansible-inventory --list      # show resolved inventory
```

For Ansible Automation Platform (AAP/AWX), use the `awx` CLI or REST API:
```bash
awx --conf.host "${OTTO_AAP_URL}" --conf.token "${OTTO_AAP_TOKEN}" jobs list
```

## Available Data

- **Inventory**: Hosts, groups, and host variables
- **Playbooks**: Available playbooks and their tasks
- **Facts**: Gathered system facts from managed hosts
- **Roles**: Installed roles and collections
- **Vault**: Encrypted secrets management
- **Job history**: Past playbook run results (via AAP/AWX)
- **Configuration**: Ansible configuration and settings

## Common Queries

### List inventory hosts
```bash
ansible-inventory --list --yaml
ansible all -m ping
```

### Gather facts from a host
```bash
ansible <host> -m setup --tree /tmp/facts
ansible <host> -m setup -a 'filter=ansible_distribution*'
```

### Run an ad-hoc command
```bash
ansible <group> -m shell -a 'uptime' --one-line
ansible <group> -m service -a 'name=nginx state=status'
```

### Run a playbook (dry run)
```bash
ansible-playbook playbook.yml --check --diff
```

### Run a playbook
```bash
ansible-playbook playbook.yml -l <host-pattern> --tags <tags>
```

### List installed roles and collections
```bash
ansible-galaxy role list
ansible-galaxy collection list
```

### View vault-encrypted file
```bash
ansible-vault view secrets.yml
```

### Check playbook syntax
```bash
ansible-playbook playbook.yml --syntax-check
```
