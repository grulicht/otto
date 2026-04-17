#!/usr/bin/env bash
# OTTO - Fetch Ansible inventory and playbook status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"inventory_hosts":0,"roles":[],"last_playbook_run":"unknown","playbook_files":0}'

if ! command -v ansible &>/dev/null; then
    log_debug "ansible not found, skipping Ansible fetch"
    echo "${empty_result}"
    exit 0
fi

# Count inventory hosts
inventory_hosts=0
if command -v ansible-inventory &>/dev/null; then
    inventory_hosts=$(ansible-inventory --list 2>/dev/null | jq '[.._hosts? // [] | .[]] | unique | length' 2>/dev/null) || inventory_hosts=0
fi

# List roles
roles="[]"
if [[ -d /etc/ansible/roles ]]; then
    roles=$(find /etc/ansible/roles -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null) || roles="[]"
elif [[ -d ./roles ]]; then
    roles=$(find ./roles -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null) || roles="[]"
fi

# Last playbook run from ansible log
last_playbook_run="unknown"
if [[ -f /var/log/ansible.log ]]; then
    last_playbook_run=$(tail -1 /var/log/ansible.log 2>/dev/null | grep -oP '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' 2>/dev/null) || last_playbook_run="unknown"
fi

# Count playbook files
playbook_files=0
if [[ -d /etc/ansible ]]; then
    playbook_files=$(find /etc/ansible -name '*.yml' -o -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ') || playbook_files=0
elif [[ -d . ]]; then
    playbook_files=$(find . -maxdepth 3 -name '*.yml' -o -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ') || playbook_files=0
fi

jq -n \
    --argjson hosts "${inventory_hosts}" \
    --argjson roles "${roles}" \
    --arg last_run "${last_playbook_run}" \
    --argjson playbooks "${playbook_files}" \
    '{
        inventory_hosts: $hosts,
        roles: $roles,
        last_playbook_run: $last_run,
        playbook_files: $playbooks
    }'
