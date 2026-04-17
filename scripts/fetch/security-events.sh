#!/usr/bin/env bash
# OTTO - Check security events on the local system
# Outputs structured JSON to stdout
# Uses: journalctl, lastb, iptables (Linux-specific)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/platform-detect.sh"

OS=$(detect_os)

if [[ "${OS}" != "linux" ]]; then
    log_debug "Security events fetch is Linux-only (detected: ${OS})"
    echo '{"failed_logins":0,"sudo_events":0,"firewall_blocks":0,"last_check":"","note":"linux_only"}'
    exit 0
fi

last_check=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Time window for event lookups (default: last 24 hours)
SINCE="${OTTO_SECURITY_SINCE:-24 hours ago}"

# --- Failed logins ---
failed_logins=0

# Method 1: journalctl (systemd)
if command -v journalctl &>/dev/null; then
    failed_logins=$(journalctl --since "${SINCE}" --no-pager -q \
        _COMM=sshd 2>/dev/null \
        | grep -ci "failed password\|authentication failure\|invalid user" 2>/dev/null) || failed_logins=0
fi

# Method 2: lastb (fallback / supplement)
if command -v lastb &>/dev/null; then
    lastb_count=$(lastb 2>/dev/null | grep -cv "^$\|^btmp" 2>/dev/null) || lastb_count=0
    # Use whichever gives a higher count (they may overlap)
    if [[ "${lastb_count}" -gt "${failed_logins}" ]]; then
        failed_logins="${lastb_count}"
    fi
fi

# Method 3: auth.log fallback (non-systemd systems)
if [[ "${failed_logins}" -eq 0 ]] && [[ -f /var/log/auth.log ]]; then
    failed_logins=$(grep -ci "failed password\|authentication failure" /var/log/auth.log 2>/dev/null) || failed_logins=0
fi

# --- Sudo events ---
sudo_events=0

if command -v journalctl &>/dev/null; then
    sudo_events=$(journalctl --since "${SINCE}" --no-pager -q \
        _COMM=sudo 2>/dev/null \
        | grep -c "COMMAND\|session opened" 2>/dev/null) || sudo_events=0
elif [[ -f /var/log/auth.log ]]; then
    sudo_events=$(grep -c "sudo:" /var/log/auth.log 2>/dev/null) || sudo_events=0
fi

# --- Firewall blocks ---
firewall_blocks=0

# iptables (requires root or CAP_NET_ADMIN)
if command -v iptables &>/dev/null; then
    # Try reading dropped packet counts from INPUT chain
    drop_count=$(iptables -L INPUT -v -n 2>/dev/null \
        | awk '/DROP|REJECT/ {sum += $1} END {print sum+0}') || drop_count=0
    firewall_blocks="${drop_count}"
fi

# nftables fallback
if [[ "${firewall_blocks}" -eq 0 ]] && command -v nft &>/dev/null; then
    nft_drops=$(nft list ruleset 2>/dev/null \
        | grep -c "drop\|reject" 2>/dev/null) || nft_drops=0
    firewall_blocks="${nft_drops}"
fi

# UFW fallback (log-based)
if [[ "${firewall_blocks}" -eq 0 ]] && command -v journalctl &>/dev/null; then
    ufw_blocks=$(journalctl --since "${SINCE}" --no-pager -q 2>/dev/null \
        | grep -ci "\[UFW BLOCK\]" 2>/dev/null) || ufw_blocks=0
    firewall_blocks="${ufw_blocks}"
fi

# Assemble final JSON
jq -n \
    --argjson failed_logins "${failed_logins}" \
    --argjson sudo_events "${sudo_events}" \
    --argjson firewall_blocks "${firewall_blocks}" \
    --arg last_check "${last_check}" \
    '{
        failed_logins: $failed_logins,
        sudo_events: $sudo_events,
        firewall_blocks: $firewall_blocks,
        last_check: $last_check
    }'
