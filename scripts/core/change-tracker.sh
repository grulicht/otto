#!/usr/bin/env bash
# OTTO - Diff/Change Tracking (Wave 2)
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_CHANGE_TRACKER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_CHANGE_TRACKER_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/i18n.sh"

OTTO_STATE_DIR="${OTTO_HOME}/state"
OTTO_SNAPSHOT_DIR="${OTTO_STATE_DIR}/snapshots"

# --- Internal helpers ---

# Collect current system state as a JSON object.
_changes_collect_state() {
    local state='{}'
    local tmp
    tmp=$(mktemp)

    # System metrics
    local cpu_pct=0 ram_pct=0 disk_pct=0

    if [[ -f /proc/stat ]] && command -v awk &>/dev/null; then
        cpu_pct=$(awk '/^cpu / { total=$2+$3+$4+$5; idle=$5; printf "%.0f", (total-idle)/total*100 }' /proc/stat 2>/dev/null || echo 0)
    fi

    if command -v free &>/dev/null; then
        ram_pct=$(free | awk '/^Mem:/ { printf "%.0f", $3/$2*100 }' 2>/dev/null || echo 0)
    fi

    if command -v df &>/dev/null; then
        disk_pct=$(df / 2>/dev/null | awk 'NR==2 { gsub(/%/,""); print $5 }' || echo 0)
    fi

    echo "${state}" | jq \
        --argjson cpu "${cpu_pct:-0}" \
        --argjson ram "${ram_pct:-0}" \
        --argjson disk "${disk_pct:-0}" \
        '.system = {"cpu": $cpu, "ram": $ram, "disk": $disk}' > "${tmp}"
    state=$(cat "${tmp}")

    # Alerts
    local alerts_file="${OTTO_STATE_DIR}/alerts.json"
    local alert_count=0
    if [[ -f "${alerts_file}" ]]; then
        alert_count=$(jq 'if type == "array" then length else 0 end' "${alerts_file}" 2>/dev/null || echo 0)
    fi
    echo "${state}" | jq --argjson count "${alert_count}" '.alerts = {"count": $count}' > "${tmp}"
    state=$(cat "${tmp}")

    # Deployments (count from audit log in last 24h)
    local audit_file="${OTTO_STATE_DIR}/audit.jsonl"
    local deploy_count=0
    if [[ -f "${audit_file}" ]]; then
        local since
        since=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
        if [[ -n "${since}" ]]; then
            deploy_count=$(jq -c "select(.action == \"deploy\" and .ts >= \"${since}\")" "${audit_file}" 2>/dev/null | wc -l || echo 0)
        fi
    fi
    echo "${state}" | jq --argjson count "${deploy_count}" '.deployments = {"count_24h": $count}' > "${tmp}"
    state=$(cat "${tmp}")

    # Certificates
    local certs_file="${OTTO_STATE_DIR}/certificates.json"
    local cert_count=0 cert_expiring=0
    if [[ -f "${certs_file}" ]]; then
        cert_count=$(jq 'if type == "array" then length else 0 end' "${certs_file}" 2>/dev/null || echo 0)
        cert_expiring=$(jq '[.[]? | select(.days_remaining != null and (.days_remaining | tonumber) < 30)] | length' "${certs_file}" 2>/dev/null || echo 0)
    fi
    echo "${state}" | jq \
        --argjson count "${cert_count}" \
        --argjson expiring "${cert_expiring}" \
        '.certificates = {"count": $count, "expiring_soon": $expiring}' > "${tmp}"
    state=$(cat "${tmp}")

    # Kubernetes pods (if available)
    if command -v kubectl &>/dev/null; then
        local pod_running=0 pod_total=0 pod_failed=0
        pod_running=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo 0)
        pod_total=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo 0)
        pod_failed=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l || echo 0)
        echo "${state}" | jq \
            --argjson running "${pod_running}" \
            --argjson total "${pod_total}" \
            --argjson failed "${pod_failed}" \
            '.pods = {"running": $running, "total": $total, "failed": $failed}' > "${tmp}"
        state=$(cat "${tmp}")
    fi

    # Night Watcher status
    local nw_active
    nw_active=$(json_get "${OTTO_STATE_DIR}/state.json" ".night_watcher.active" "false")
    echo "${state}" | jq --argjson active "${nw_active}" '.night_watcher = {"active": $active}' > "${tmp}"
    state=$(cat "${tmp}")

    rm -f "${tmp}"
    echo "${state}"
}

# Get the most recent snapshot file path.
_changes_latest_snapshot() {
    if [[ ! -d "${OTTO_SNAPSHOT_DIR}" ]]; then
        echo ""
        return
    fi
    ls -1t "${OTTO_SNAPSHOT_DIR}"/*.json 2>/dev/null | head -1 || echo ""
}

# --- Public API ---

# Take a snapshot of the current system state.
# Stores results in state/snapshots/TIMESTAMP.json.
changes_snapshot() {
    mkdir -p "${OTTO_SNAPSHOT_DIR}"

    local timestamp
    timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
    local snapshot_file="${OTTO_SNAPSHOT_DIR}/${timestamp}.json"

    log_info "Taking state snapshot..."
    local state
    state=$(_changes_collect_state)

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${state}" | jq --arg ts "${now}" '. + {"timestamp": $ts}' > "${snapshot_file}"

    log_info "$(i18n_get CHANGES_SNAPSHOT "Snapshot taken"): ${snapshot_file}"
    echo "${snapshot_file}"
}

# Compare two snapshots and output human-readable changes.
#   $1 - First snapshot file path
#   $2 - Second snapshot file path
changes_diff() {
    local snapshot1="$1"
    local snapshot2="$2"

    if [[ -z "${snapshot1}" ]] || [[ -z "${snapshot2}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): two snapshot paths"
        return 1
    fi

    if [[ ! -f "${snapshot1}" ]] || [[ ! -f "${snapshot2}" ]]; then
        log_error "$(i18n_get ERR_FILE_NOT_FOUND "File not found")"
        return 1
    fi

    local ts1 ts2
    ts1=$(jq -r '.timestamp // "unknown"' "${snapshot1}" 2>/dev/null)
    ts2=$(jq -r '.timestamp // "unknown"' "${snapshot2}" 2>/dev/null)

    echo -e "${BOLD}$(i18n_get CHANGES_TITLE "Change Tracker")${NC}"
    echo -e "${DIM}Comparing: ${ts1} -> ${ts2}${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"

    local has_changes=0

    # System metrics diff
    local cpu1 cpu2 ram1 ram2 disk1 disk2
    cpu1=$(jq -r '.system.cpu // 0' "${snapshot1}" 2>/dev/null)
    cpu2=$(jq -r '.system.cpu // 0' "${snapshot2}" 2>/dev/null)
    ram1=$(jq -r '.system.ram // 0' "${snapshot1}" 2>/dev/null)
    ram2=$(jq -r '.system.ram // 0' "${snapshot2}" 2>/dev/null)
    disk1=$(jq -r '.system.disk // 0' "${snapshot1}" 2>/dev/null)
    disk2=$(jq -r '.system.disk // 0' "${snapshot2}" 2>/dev/null)

    local cpu_diff=$(( cpu2 - cpu1 ))
    local ram_diff=$(( ram2 - ram1 ))
    local disk_diff=$(( disk2 - disk1 ))

    if [[ "${cpu_diff}" -ne 0 ]] || [[ "${ram_diff}" -ne 0 ]] || [[ "${disk_diff}" -ne 0 ]]; then
        has_changes=1
        echo -e "  ${BOLD}System Metrics:${NC}"
        _print_metric_change "  CPU" "${cpu1}" "${cpu2}" "%"
        _print_metric_change "  RAM" "${ram1}" "${ram2}" "%"
        _print_metric_change "  Disk" "${disk1}" "${disk2}" "%"
        echo ""
    fi

    # Alert count diff
    local alerts1 alerts2
    alerts1=$(jq -r '.alerts.count // 0' "${snapshot1}" 2>/dev/null)
    alerts2=$(jq -r '.alerts.count // 0' "${snapshot2}" 2>/dev/null)
    if [[ "${alerts1}" -ne "${alerts2}" ]]; then
        has_changes=1
        local alert_diff=$(( alerts2 - alerts1 ))
        local alert_dir="+"
        local alert_color="${RED}"
        if [[ "${alert_diff}" -lt 0 ]]; then
            alert_dir=""
            alert_color="${GREEN}"
        fi
        echo -e "  ${BOLD}Alerts:${NC} ${alerts1} -> ${alert_color}${alerts2}${NC} (${alert_dir}${alert_diff})"
        echo ""
    fi

    # Deployment count diff
    local deploys1 deploys2
    deploys1=$(jq -r '.deployments.count_24h // 0' "${snapshot1}" 2>/dev/null)
    deploys2=$(jq -r '.deployments.count_24h // 0' "${snapshot2}" 2>/dev/null)
    if [[ "${deploys1}" -ne "${deploys2}" ]]; then
        has_changes=1
        local deploy_diff=$(( deploys2 - deploys1 ))
        echo -e "  ${BOLD}Deployments (24h):${NC} ${deploys1} -> ${deploys2} (+${deploy_diff})"
        echo ""
    fi

    # Cert expiring diff
    local certs_exp1 certs_exp2
    certs_exp1=$(jq -r '.certificates.expiring_soon // 0' "${snapshot1}" 2>/dev/null)
    certs_exp2=$(jq -r '.certificates.expiring_soon // 0' "${snapshot2}" 2>/dev/null)
    if [[ "${certs_exp1}" -ne "${certs_exp2}" ]]; then
        has_changes=1
        echo -e "  ${BOLD}Certificates expiring soon:${NC} ${certs_exp1} -> ${certs_exp2}"
        echo ""
    fi

    if [[ "${has_changes}" -eq 0 ]]; then
        echo -e "  ${GREEN}$(i18n_get CHANGES_NO_CHANGES "No changes detected")${NC}"
    fi
}

# Print a metric change with color-coded direction.
_print_metric_change() {
    local label="$1"
    local old="$2"
    local new="$3"
    local suffix="${4:-}"

    local diff=$(( new - old ))
    if [[ "${diff}" -eq 0 ]]; then
        printf '  %-8s %s%s (unchanged)\n' "${label}" "${new}" "${suffix}"
    elif [[ "${diff}" -gt 0 ]]; then
        printf '  %-8s %s%s -> %b%s%s%b (+%s)\n' "${label}" "${old}" "${suffix}" "${YELLOW}" "${new}" "${suffix}" "${NC}" "${diff}"
    else
        printf '  %-8s %s%s -> %b%s%s%b (%s)\n' "${label}" "${old}" "${suffix}" "${GREEN}" "${new}" "${suffix}" "${NC}" "${diff}"
    fi
}

# Compare current state with the last snapshot.
changes_since_last() {
    local latest
    latest=$(_changes_latest_snapshot)

    if [[ -z "${latest}" ]]; then
        log_info "$(i18n_get CHANGES_NO_SNAPSHOTS "No snapshots found"). Taking first snapshot..."
        changes_snapshot >/dev/null
        echo -e "${DIM}First snapshot taken. Run again later to see changes.${NC}"
        return 0
    fi

    # Take a temporary snapshot for comparison
    local tmp_snapshot
    tmp_snapshot=$(mktemp "${TMPDIR:-/tmp}/otto-snapshot.XXXXXX.json")
    local state
    state=$(_changes_collect_state)
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${state}" | jq --arg ts "${now}" '. + {"timestamp": $ts}' > "${tmp_snapshot}"

    changes_diff "${latest}" "${tmp_snapshot}"

    rm -f "${tmp_snapshot}"
}

# Generate a one-line summary of changes since last snapshot.
changes_summary() {
    local latest
    latest=$(_changes_latest_snapshot)

    if [[ -z "${latest}" ]]; then
        echo "No previous snapshot"
        return 0
    fi

    local state
    state=$(_changes_collect_state)

    local alerts_now alerts_prev deploys_now deploys_prev disk_now disk_prev
    alerts_now=$(echo "${state}" | jq -r '.alerts.count // 0')
    alerts_prev=$(jq -r '.alerts.count // 0' "${latest}" 2>/dev/null)
    deploys_now=$(echo "${state}" | jq -r '.deployments.count_24h // 0')
    deploys_prev=$(jq -r '.deployments.count_24h // 0' "${latest}" 2>/dev/null)
    disk_now=$(echo "${state}" | jq -r '.system.disk // 0')
    disk_prev=$(jq -r '.system.disk // 0' "${latest}" 2>/dev/null)

    local parts=()
    local alert_diff=$(( alerts_now - alerts_prev ))
    if [[ "${alert_diff}" -gt 0 ]]; then
        parts+=("${alert_diff} new alert(s)")
    elif [[ "${alert_diff}" -lt 0 ]]; then
        parts+=("${alert_diff#-} alert(s) resolved")
    fi

    local deploy_diff=$(( deploys_now - deploys_prev ))
    if [[ "${deploy_diff}" -gt 0 ]]; then
        parts+=("${deploy_diff} deployment(s)")
    fi

    local disk_diff=$(( disk_now - disk_prev ))
    if [[ "${disk_diff}" -ne 0 ]]; then
        local sign="+"
        if [[ "${disk_diff}" -lt 0 ]]; then sign=""; fi
        parts+=("disk ${sign}${disk_diff}%")
    fi

    if [[ ${#parts[@]} -eq 0 ]]; then
        echo "$(i18n_get CHANGES_NO_CHANGES "No changes detected")"
    else
        local IFS=", "
        echo "${parts[*]}"
    fi
}

# Show the last N change summaries by comparing consecutive snapshots.
#   $1 - Number of entries to show (default: 10)
changes_history() {
    local count="${1:-10}"

    if [[ ! -d "${OTTO_SNAPSHOT_DIR}" ]]; then
        echo -e "${DIM}$(i18n_get CHANGES_NO_SNAPSHOTS "No snapshots found")${NC}"
        return 0
    fi

    local snapshots
    snapshots=$(ls -1t "${OTTO_SNAPSHOT_DIR}"/*.json 2>/dev/null | head -$(( count + 1 )))

    local snap_count
    snap_count=$(echo "${snapshots}" | wc -l)

    if [[ "${snap_count}" -lt 2 ]]; then
        echo -e "${DIM}Not enough snapshots to show history (need at least 2)${NC}"
        return 0
    fi

    echo -e "${BOLD}$(i18n_get CHANGES_SUMMARY "Change Summary") (last ${count})${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"

    local prev_snap=""
    local shown=0

    while IFS= read -r snap; do
        if [[ -n "${prev_snap}" ]] && [[ "${shown}" -lt "${count}" ]]; then
            local ts
            ts=$(jq -r '.timestamp // "unknown"' "${snap}" 2>/dev/null)

            # Quick inline diff summary
            local alerts1 alerts2 disk1 disk2 deploys1 deploys2
            alerts1=$(jq -r '.alerts.count // 0' "${snap}" 2>/dev/null)
            alerts2=$(jq -r '.alerts.count // 0' "${prev_snap}" 2>/dev/null)
            disk1=$(jq -r '.system.disk // 0' "${snap}" 2>/dev/null)
            disk2=$(jq -r '.system.disk // 0' "${prev_snap}" 2>/dev/null)
            deploys1=$(jq -r '.deployments.count_24h // 0' "${snap}" 2>/dev/null)
            deploys2=$(jq -r '.deployments.count_24h // 0' "${prev_snap}" 2>/dev/null)

            local parts=()
            local ad=$(( alerts2 - alerts1 ))
            if [[ "${ad}" -ne 0 ]]; then parts+=("alerts ${ad:+"+"}${ad}"); fi
            local dd=$(( deploys2 - deploys1 ))
            if [[ "${dd}" -gt 0 ]]; then parts+=("${dd} deploy(s)"); fi
            local diskd=$(( disk2 - disk1 ))
            if [[ "${diskd}" -ne 0 ]]; then parts+=("disk ${diskd:+"+"}${diskd}%"); fi

            local summary
            if [[ ${#parts[@]} -eq 0 ]]; then
                summary="no changes"
            else
                local IFS=", "
                summary="${parts[*]}"
            fi

            printf '  %s  %s\n' "${ts}" "${summary}"
            shown=$(( shown + 1 ))
        fi
        prev_snap="${snap}"
    done <<< "${snapshots}"
}

# --- CLI ---

_changes_usage() {
    echo "Usage: otto changes <command> [args]"
    echo ""
    echo "Commands:"
    echo "  snapshot       Take a state snapshot"
    echo "  diff           Compare last two snapshots"
    echo "  since-last     Compare current state with last snapshot"
    echo "  summary        One-line change summary"
    echo "  history [n]    Show last N change summaries"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    i18n_init 2>/dev/null || true

    case "${1:-}" in
        snapshot)
            changes_snapshot
            ;;
        diff)
            if [[ -n "${2:-}" ]] && [[ -n "${3:-}" ]]; then
                changes_diff "$2" "$3"
            else
                # Compare last two snapshots
                local snaps
                snaps=$(ls -1t "${OTTO_SNAPSHOT_DIR}"/*.json 2>/dev/null | head -2)
                local snap_count
                snap_count=$(echo "${snaps}" | wc -l)
                if [[ "${snap_count}" -lt 2 ]]; then
                    log_error "Need at least 2 snapshots. Provide paths or take more snapshots."
                    exit 1
                fi
                local snap2 snap1
                snap2=$(echo "${snaps}" | head -1)
                snap1=$(echo "${snaps}" | tail -1)
                changes_diff "${snap1}" "${snap2}"
            fi
            ;;
        since-last)
            changes_since_last
            ;;
        summary)
            changes_summary
            ;;
        history)
            changes_history "${2:-10}"
            ;;
        -h|--help|"")
            _changes_usage
            ;;
        *)
            log_error "Unknown command: $1"
            _changes_usage
            exit 1
            ;;
    esac
fi
