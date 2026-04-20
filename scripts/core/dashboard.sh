#!/usr/bin/env bash
# OTTO - Dashboard Generator (Wave 2)
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_DASHBOARD_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_DASHBOARD_LOADED=1

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
OTTO_DASHBOARD_FILE="${OTTO_STATE_DIR}/dashboard.html"
OTTO_TEMPLATE_DIR="${OTTO_DIR}/scripts/templates/dashboard"

# --- Internal helpers ---

# Collect system health metrics.
# Outputs a JSON object with cpu, ram, disk percentages.
_dashboard_collect_health() {
    local cpu_pct=0 ram_pct=0 disk_pct=0

    # CPU usage (1-second sample)
    if command -v mpstat &>/dev/null; then
        cpu_pct=$(mpstat 1 1 2>/dev/null | awk '/Average.*all/ { printf "%.0f", 100 - $NF }')
    elif [[ -f /proc/stat ]]; then
        local idle_before total_before idle_after total_after
        read -r _ user nice system idle _ < <(head -1 /proc/stat)
        total_before=$(( user + nice + system + idle ))
        idle_before="${idle}"
        sleep 1
        read -r _ user nice system idle _ < <(head -1 /proc/stat)
        total_after=$(( user + nice + system + idle ))
        idle_after="${idle}"
        local diff_idle=$(( idle_after - idle_before ))
        local diff_total=$(( total_after - total_before ))
        if [[ "${diff_total}" -gt 0 ]]; then
            cpu_pct=$(( 100 * (diff_total - diff_idle) / diff_total ))
        fi
    fi

    # RAM usage
    if command -v free &>/dev/null; then
        ram_pct=$(free | awk '/^Mem:/ { printf "%.0f", $3/$2 * 100 }')
    fi

    # Disk usage (root partition)
    if command -v df &>/dev/null; then
        disk_pct=$(df / 2>/dev/null | awk 'NR==2 { gsub(/%/,""); print $5 }')
    fi

    printf '{"cpu":%s,"ram":%s,"disk":%s}' \
        "${cpu_pct:-0}" "${ram_pct:-0}" "${disk_pct:-0}"
}

# Collect active alerts from state.
_dashboard_collect_alerts() {
    local alerts_file="${OTTO_STATE_DIR}/alerts.json"
    if [[ -f "${alerts_file}" ]]; then
        jq -c '.' "${alerts_file}" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Collect recent deployments from audit log.
_dashboard_collect_deployments() {
    local audit_file="${OTTO_STATE_DIR}/audit.jsonl"
    if [[ -f "${audit_file}" ]]; then
        grep '"deploy"' "${audit_file}" 2>/dev/null | tail -10 | jq -sc '.' 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Collect certificate status from state.
_dashboard_collect_certs() {
    local certs_file="${OTTO_STATE_DIR}/certificates.json"
    if [[ -f "${certs_file}" ]]; then
        jq -c '.' "${certs_file}" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Collect backup status from state.
_dashboard_collect_backups() {
    local backups_file="${OTTO_STATE_DIR}/backups.json"
    if [[ -f "${backups_file}" ]]; then
        jq -c '.' "${backups_file}" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Collect night watcher status from state.
_dashboard_collect_nightwatch() {
    local nw_active
    nw_active=$(json_get "${OTTO_STATE_DIR}/state.json" ".night_watcher.active" "false")
    local nw_started
    nw_started=$(json_get "${OTTO_STATE_DIR}/state.json" ".night_watcher.started_at" "null")

    local latest_report=""
    local report_dir="${OTTO_STATE_DIR}/night-watch"
    if [[ -d "${report_dir}" ]]; then
        latest_report=$(ls -t "${report_dir}"/*.json 2>/dev/null | head -1 || true)
    fi

    local report_summary="No reports"
    if [[ -n "${latest_report}" ]] && [[ -f "${latest_report}" ]]; then
        report_summary=$(jq -r '.summary // "No summary"' "${latest_report}" 2>/dev/null || echo "No summary")
    fi

    printf '{"active":%s,"started_at":"%s","latest_report":"%s"}' \
        "${nw_active}" "${nw_started}" "${report_summary}"
}

# Format health data as HTML table rows.
_dashboard_health_to_html() {
    local health_json="$1"
    local cpu ram disk
    cpu=$(echo "${health_json}" | jq -r '.cpu')
    ram=$(echo "${health_json}" | jq -r '.ram')
    disk=$(echo "${health_json}" | jq -r '.disk')

    local html=""
    local metric pct color_class
    for metric in "CPU:${cpu}" "Memory:${ram}" "Disk:${disk}"; do
        local label="${metric%%:*}"
        pct="${metric#*:}"

        if [[ "${pct}" -lt 70 ]]; then
            color_class="var(--green)"
        elif [[ "${pct}" -lt 85 ]]; then
            color_class="var(--yellow)"
        else
            color_class="var(--red)"
        fi

        html+="<div style=\"margin-bottom:8px\">"
        html+="<div style=\"display:flex;justify-content:space-between;margin-bottom:2px\">"
        html+="<span>${label}</span><span>${pct}%</span></div>"
        html+="<div class=\"bar-container\"><div class=\"bar-fill\" "
        html+="style=\"width:${pct}%;background:${color_class}\"></div></div></div>"
    done

    echo "${html}"
}

# Format alerts as HTML.
_dashboard_alerts_to_html() {
    local alerts_json="$1"
    local count
    count=$(echo "${alerts_json}" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)

    if [[ "${count}" -eq 0 ]]; then
        echo '<div class="empty-state">No active alerts</div>'
        return
    fi

    local html="<table><tr><th>Severity</th><th>Source</th><th>Message</th><th>Time</th></tr>"
    html+=$(echo "${alerts_json}" | jq -r '.[] | "<tr><td>\(.severity // "unknown")</td><td>\(.source // "-")</td><td>\(.message // "-")</td><td>\(.timestamp // "-")</td></tr>"' 2>/dev/null || true)
    html+="</table>"
    echo "${html}"
}

# Format deployments as HTML.
_dashboard_deployments_to_html() {
    local deploys_json="$1"
    local count
    count=$(echo "${deploys_json}" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)

    if [[ "${count}" -eq 0 ]]; then
        echo '<div class="empty-state">No recent deployments</div>'
        return
    fi

    local html="<table><tr><th>Time</th><th>Actor</th><th>Target</th><th>Result</th></tr>"
    html+=$(echo "${deploys_json}" | jq -r '.[] | "<tr><td>\(.ts // "-")</td><td>\(.actor // "-")</td><td>\(.target // "-")</td><td>\(.result // "-")</td></tr>"' 2>/dev/null || true)
    html+="</table>"
    echo "${html}"
}

# Format certificates as HTML.
_dashboard_certs_to_html() {
    local certs_json="$1"
    local count
    count=$(echo "${certs_json}" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)

    if [[ "${count}" -eq 0 ]]; then
        echo '<div class="empty-state">No certificate data</div>'
        return
    fi

    local html="<table><tr><th>Domain</th><th>Expires</th><th>Days Left</th></tr>"
    html+=$(echo "${certs_json}" | jq -r '.[] | "<tr><td>\(.domain // "-")</td><td>\(.expires // "-")</td><td>\(.days_remaining // "-")</td></tr>"' 2>/dev/null || true)
    html+="</table>"
    echo "${html}"
}

# Format backups as HTML.
_dashboard_backups_to_html() {
    local backups_json="$1"
    local count
    count=$(echo "${backups_json}" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)

    if [[ "${count}" -eq 0 ]]; then
        echo '<div class="empty-state">No backup data</div>'
        return
    fi

    local html="<table><tr><th>Name</th><th>Last Run</th><th>Status</th><th>Size</th></tr>"
    html+=$(echo "${backups_json}" | jq -r '.[] | "<tr><td>\(.name // "-")</td><td>\(.last_run // "-")</td><td>\(.status // "-")</td><td>\(.size // "-")</td></tr>"' 2>/dev/null || true)
    html+="</table>"
    echo "${html}"
}

# Format night watcher status as HTML.
_dashboard_nightwatch_to_html() {
    local nw_json="$1"
    local active started report
    active=$(echo "${nw_json}" | jq -r '.active' 2>/dev/null || echo "false")
    started=$(echo "${nw_json}" | jq -r '.started_at' 2>/dev/null || echo "null")
    report=$(echo "${nw_json}" | jq -r '.latest_report' 2>/dev/null || echo "No reports")

    local status_class="status-unknown"
    local status_label="Inactive"
    if [[ "${active}" == "true" ]]; then
        status_class="status-ok"
        status_label="Active"
    fi

    local html="<table>"
    html+="<tr><td>Status</td><td><span class=\"${status_class}\">${status_label}</span></td></tr>"
    html+="<tr><td>Started</td><td>${started}</td></tr>"
    html+="<tr><td>Latest Report</td><td>${report}</td></tr>"
    html+="</table>"
    echo "${html}"
}

# --- Public API ---

# Generate an HTML status dashboard.
# Runs all fetch scripts and assembles results into state/dashboard.html.
dashboard_generate_html() {
    log_info "Generating HTML dashboard..."

    mkdir -p "${OTTO_STATE_DIR}"

    local template="${OTTO_TEMPLATE_DIR}/index.html"
    if [[ ! -f "${template}" ]]; then
        log_error "Dashboard template not found: ${template}"
        return 1
    fi

    # Collect data
    local health_json alerts_json deploys_json certs_json backups_json nw_json
    health_json=$(_dashboard_collect_health)
    alerts_json=$(_dashboard_collect_alerts)
    deploys_json=$(_dashboard_collect_deployments)
    certs_json=$(_dashboard_collect_certs)
    backups_json=$(_dashboard_collect_backups)
    nw_json=$(_dashboard_collect_nightwatch)

    # Convert to HTML fragments
    local health_html alerts_html deploys_html certs_html backups_html nw_html
    health_html=$(_dashboard_health_to_html "${health_json}")
    alerts_html=$(_dashboard_alerts_to_html "${alerts_json}")
    deploys_html=$(_dashboard_deployments_to_html "${deploys_json}")
    certs_html=$(_dashboard_certs_to_html "${certs_json}")
    backups_html=$(_dashboard_backups_to_html "${backups_json}")
    nw_html=$(_dashboard_nightwatch_to_html "${nw_json}")

    local hostname timestamp
    hostname=$(hostname 2>/dev/null || echo "unknown")
    timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    # Replace placeholders in template
    local output
    output=$(cat "${template}")
    output="${output//\{\{HOSTNAME\}\}/${hostname}}"
    output="${output//\{\{TIMESTAMP\}\}/${timestamp}}"
    output="${output//\{\{HEALTH_GRID\}\}/${health_html}}"
    output="${output//\{\{ALERTS\}\}/${alerts_html}}"
    output="${output//\{\{DEPLOYMENTS\}\}/${deploys_html}}"
    output="${output//\{\{CERTS\}\}/${certs_html}}"
    output="${output//\{\{BACKUPS\}\}/${backups_html}}"
    output="${output//\{\{NIGHTWATCH\}\}/${nw_html}}"

    echo "${output}" > "${OTTO_DASHBOARD_FILE}"

    log_info "Dashboard written to ${OTTO_DASHBOARD_FILE}"
    echo "${OTTO_DASHBOARD_FILE}"
}

# Generate an ASCII-art terminal dashboard with colors.
# Displays system health bars, alert counts, pod status, service status.
dashboard_generate_terminal() {
    local health_json alerts_json
    health_json=$(_dashboard_collect_health)
    alerts_json=$(_dashboard_collect_alerts)

    local cpu ram disk
    cpu=$(echo "${health_json}" | jq -r '.cpu')
    ram=$(echo "${health_json}" | jq -r '.ram')
    disk=$(echo "${health_json}" | jq -r '.disk')

    local hostname timestamp
    hostname=$(hostname 2>/dev/null || echo "unknown")
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    local alert_count
    alert_count=$(echo "${alerts_json}" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)

    echo ""
    echo -e "${BOLD}  OTTO $(i18n_get DASHBOARD_TITLE "System Dashboard")${NC}"
    echo -e "${DIM}  ${hostname} - ${timestamp}${NC}"
    echo -e "${DIM}  ════════════════════════════════════════════════${NC}"
    echo ""

    # Health bars
    echo -e "  ${BOLD}$(i18n_get DASHBOARD_HEALTH "System Health")${NC}"
    echo ""

    local metric pct label
    for metric in "CPU:${cpu}" "RAM:${ram}" "DISK:${disk}"; do
        label="${metric%%:*}"
        pct="${metric#*:}"
        _draw_bar "${label}" "${pct}"
    done
    echo ""

    # Alerts
    echo -e "  ${BOLD}$(i18n_get DASHBOARD_ALERTS "Alerts")${NC}"
    if [[ "${alert_count}" -eq 0 ]]; then
        echo -e "    ${GREEN}$(i18n_get DASHBOARD_NO_ALERTS "No active alerts")${NC}"
    else
        echo -e "    ${YELLOW}${alert_count} active alert(s)${NC}"
        echo "${alerts_json}" | jq -r '.[]? | "    [\(.severity // "?")] \(.message // "unknown")"' 2>/dev/null || true
    fi
    echo ""

    # Pod status (if kubectl available)
    echo -e "  ${BOLD}$(i18n_get DASHBOARD_PODS "Pod Status")${NC}"
    if command -v kubectl &>/dev/null; then
        local running_pods=0 total_pods=0 failed_pods=0
        running_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo 0)
        total_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo 0)
        failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l || echo 0)
        echo -e "    Running: ${GREEN}${running_pods}${NC}  Total: ${total_pods}  Failed: ${RED}${failed_pods}${NC}"
    else
        echo -e "    ${DIM}kubectl not available${NC}"
    fi
    echo ""

    # Services (from systemd if available)
    echo -e "  ${BOLD}$(i18n_get DASHBOARD_SERVICES "Services")${NC}"
    if command -v systemctl &>/dev/null; then
        local active_svc failed_svc
        active_svc=$(systemctl list-units --state=active --type=service --no-legend --no-pager 2>/dev/null | wc -l || echo 0)
        failed_svc=$(systemctl list-units --state=failed --type=service --no-legend --no-pager 2>/dev/null | wc -l || echo 0)
        echo -e "    Active: ${GREEN}${active_svc}${NC}  Failed: ${RED}${failed_svc}${NC}"
    else
        echo -e "    ${DIM}systemctl not available${NC}"
    fi

    echo ""
    echo -e "${DIM}  ════════════════════════════════════════════════${NC}"
}

# Draw a colored progress bar for terminal output.
#   $1 - Label
#   $2 - Percentage (0-100)
_draw_bar() {
    local label="$1"
    local pct="${2:-0}"
    local bar_width=30
    local filled=$(( pct * bar_width / 100 ))
    local empty=$(( bar_width - filled ))

    local bar_color="${GREEN}"
    if [[ "${pct}" -ge 85 ]]; then
        bar_color="${RED}"
    elif [[ "${pct}" -ge 70 ]]; then
        bar_color="${YELLOW}"
    fi

    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    for (( i=0; i<empty; i++ )); do bar+="░"; done

    printf '    %-6s %b%s%b %3s%%\n' "${label}" "${bar_color}" "${bar}" "${NC}" "${pct}"
}

# Open the HTML dashboard in the default browser.
dashboard_open() {
    if [[ ! -f "${OTTO_DASHBOARD_FILE}" ]]; then
        log_info "No dashboard file found, generating..."
        dashboard_generate_html >/dev/null
    fi

    if [[ ! -f "${OTTO_DASHBOARD_FILE}" ]]; then
        log_error "Failed to generate dashboard"
        return 1
    fi

    log_info "Opening dashboard: ${OTTO_DASHBOARD_FILE}"

    if command -v xdg-open &>/dev/null; then
        xdg-open "${OTTO_DASHBOARD_FILE}" &>/dev/null &
    elif command -v open &>/dev/null; then
        open "${OTTO_DASHBOARD_FILE}"
    else
        log_warn "No browser opener found (xdg-open/open). File: ${OTTO_DASHBOARD_FILE}"
        return 1
    fi
}

# --- CLI ---

_dashboard_usage() {
    echo "Usage: otto dashboard <command>"
    echo ""
    echo "Commands:"
    echo "  html       Generate HTML status dashboard"
    echo "  terminal   Show ASCII terminal dashboard"
    echo "  open       Open HTML dashboard in browser"
    echo ""
}

# CLI entry point when run directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Source i18n and initialize
    i18n_init 2>/dev/null || true

    case "${1:-}" in
        html)
            dashboard_generate_html
            ;;
        terminal)
            dashboard_generate_terminal
            ;;
        open)
            dashboard_open
            ;;
        -h|--help|"")
            _dashboard_usage
            ;;
        *)
            log_error "Unknown command: $1"
            _dashboard_usage
            exit 1
            ;;
    esac
fi
