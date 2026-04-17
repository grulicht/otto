#!/usr/bin/env bash
# OTTO - Fetch local server health metrics
# Outputs structured JSON to stdout
# Uses: standard Linux commands (free, df, uptime, etc.)
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

# Hostname
hostname_val=$(hostname 2>/dev/null || echo "unknown")

# Uptime
uptime_val=$(uptime -p 2>/dev/null || uptime 2>/dev/null | sed 's/.*up /up /' || echo "unknown")

# CPU usage percentage
cpu_percent=0
if [[ "${OS}" == "linux" ]]; then
    # Use /proc/stat for a 1-second sample
    if [[ -f /proc/stat ]]; then
        read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 _ < /proc/stat
        sleep 1
        read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 _ < /proc/stat

        total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1))
        total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2))
        idle_diff=$((idle2 - idle1))
        total_diff=$((total2 - total1))

        if [[ "${total_diff}" -gt 0 ]]; then
            cpu_percent=$(( (total_diff - idle_diff) * 100 / total_diff ))
        fi
    fi
elif [[ "${OS}" == "macos" ]]; then
    cpu_percent=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ {gsub(/%/,""); print int($3 + $5)}') || cpu_percent=0
fi

# Memory usage percentage
memory_percent=0
if [[ "${OS}" == "linux" ]]; then
    if command -v free &>/dev/null; then
        memory_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}' 2>/dev/null) || memory_percent=0
    fi
elif [[ "${OS}" == "macos" ]]; then
    # macOS: parse vm_stat
    pages_active=$(vm_stat 2>/dev/null | awk '/Pages active/ {gsub(/\./,""); print $3}') || pages_active=0
    pages_wired=$(vm_stat 2>/dev/null | awk '/Pages wired/ {gsub(/\./,""); print $4}') || pages_wired=0
    pages_compressed=$(vm_stat 2>/dev/null | awk '/Pages occupied by compressor/ {gsub(/\./,""); print $5}') || pages_compressed=0
    total_mem=$(sysctl -n hw.memsize 2>/dev/null) || total_mem=1
    page_size=$(vm_stat 2>/dev/null | head -1 | awk '{print $8}') || page_size=4096
    used_bytes=$(( (pages_active + pages_wired + pages_compressed) * page_size ))
    if [[ "${total_mem}" -gt 0 ]]; then
        memory_percent=$(( used_bytes * 100 / total_mem ))
    fi
fi

# Disk usage (root partition)
disk_percent=0
if command -v df &>/dev/null; then
    disk_percent=$(df / 2>/dev/null | awk 'NR==2 {gsub(/%/,""); print $5}') || disk_percent=0
fi

# Load average
load_avg="[]"
if [[ -f /proc/loadavg ]]; then
    load_avg=$(awk '{printf "[%s,%s,%s]", $1, $2, $3}' /proc/loadavg 2>/dev/null) || load_avg="[]"
elif command -v sysctl &>/dev/null; then
    load_avg=$(sysctl -n vm.loadavg 2>/dev/null | awk '{printf "[%s,%s,%s]", $2, $3, $4}') || load_avg="[]"
fi

# Zombie processes
processes_zombie=0
if [[ "${OS}" == "linux" ]]; then
    processes_zombie=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {count++} END {print count+0}') || processes_zombie=0
elif [[ "${OS}" == "macos" ]]; then
    processes_zombie=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {count++} END {print count+0}') || processes_zombie=0
fi

# Assemble final JSON
jq -n \
    --arg hostname "${hostname_val}" \
    --arg uptime "${uptime_val}" \
    --argjson cpu_percent "${cpu_percent}" \
    --argjson memory_percent "${memory_percent}" \
    --argjson disk_percent "${disk_percent}" \
    --argjson load_avg "${load_avg}" \
    --argjson processes_zombie "${processes_zombie}" \
    '{
        hostname: $hostname,
        uptime: $uptime,
        cpu_percent: $cpu_percent,
        memory_percent: $memory_percent,
        disk_percent: $disk_percent,
        load_avg: $load_avg,
        processes_zombie: $processes_zombie
    }'
