#!/usr/bin/env bash
set -euo pipefail

# OTTO - Morning Report Generator
# Generates comprehensive morning reports from Night Watcher logs.
# Supports brief, detailed, and executive formats.

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source dependencies (guard against double-sourcing)
if ! declare -F log_info &>/dev/null; then
    # shellcheck source=../lib/logging.sh
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    # shellcheck source=../lib/colors.sh
    source "${OTTO_DIR}/scripts/lib/colors.sh"
    # shellcheck source=../lib/json-utils.sh
    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
    # shellcheck source=../lib/error-handling.sh
    source "${OTTO_DIR}/scripts/lib/error-handling.sh"
fi

if ! declare -F config_get &>/dev/null; then
    # shellcheck source=config.sh
    source "${OTTO_DIR}/scripts/core/config.sh"
fi

# --- Constants (guarded against re-source) ---

if [[ -z "${_OTTO_MORNING_REPORT_LOADED:-}" ]]; then
_OTTO_MORNING_REPORT_LOADED=1

readonly NIGHT_WATCH_LOG_DIR="${OTTO_HOME}/state/night-watch"

# Report section headers
readonly SECTION_EXECUTIVE="Executive Summary"
readonly SECTION_HEALTH="System Health"
readonly SECTION_DEPLOYMENTS="Deployments & CI/CD"
readonly SECTION_SECURITY="Security"
readonly SECTION_ACTION_ITEMS="Action Items"
readonly SECTION_TRENDS="Trends & Predictions"

fi  # _OTTO_MORNING_REPORT_LOADED

# --- Public Functions ---

# Generate a morning report from the night watch log for a given date.
# 1. Read night-watch/YYYY-MM-DD.json
# 2. Aggregate findings by category
# 3. Calculate stats (total checks, alerts, actions taken)
# 4. Format based on config (brief/detailed/executive)
# 5. Output report text
morning_report_generate() {
    local date_str="${1:-$(date +"%Y-%m-%d")}"
    local log_file="${NIGHT_WATCH_LOG_DIR}/${date_str}.json"

    if [ ! -f "${log_file}" ]; then
        log_warn "No night watch log found for ${date_str}"
        echo "No night watch data available for ${date_str}."
        return 0
    fi

    log_info "Generating morning report for ${date_str}"

    # Extract summary stats
    local total_checks ok_count warn_count crit_count escalation_count actions_count
    total_checks=$(json_get "${log_file}" ".summary.total_checks" "0")
    ok_count=$(json_get "${log_file}" ".summary.ok" "0")
    warn_count=$(json_get "${log_file}" ".summary.warnings" "0")
    crit_count=$(json_get "${log_file}" ".summary.critical" "0")
    escalation_count=$(json_get "${log_file}" ".summary.escalations" "0")
    actions_count=$(json_get "${log_file}" ".summary.actions_taken" "0")

    local started_at stopped_at
    started_at=$(json_get "${log_file}" ".started_at" "unknown")
    stopped_at=$(json_get "${log_file}" ".stopped_at" "unknown")

    # Aggregate findings by category
    local categories_json
    categories_json=$(jq -r '
        .entries
        | group_by(.category)
        | map({
            category: .[0].category,
            total: length,
            ok: [.[] | select(.severity == "ok")] | length,
            warnings: [.[] | select(.severity == "warning")] | length,
            critical: [.[] | select(.severity == "critical")] | length,
            actions: [.[] | select(.action_taken != null)] | length
        })
    ' "${log_file}" 2>/dev/null || echo "[]")

    # Get configured format
    local format
    format=$(config_get ".night_watcher.morning_report.format" "detailed")

    case "${format}" in
        brief)
            _morning_report_format_brief \
                "${date_str}" "${total_checks}" "${ok_count}" "${warn_count}" \
                "${crit_count}" "${escalation_count}" "${actions_count}" \
                "${started_at}" "${stopped_at}"
            ;;
        executive)
            _morning_report_format_executive \
                "${date_str}" "${total_checks}" "${ok_count}" "${warn_count}" \
                "${crit_count}" "${escalation_count}" "${actions_count}" \
                "${started_at}" "${stopped_at}" "${categories_json}" "${log_file}"
            ;;
        detailed|*)
            _morning_report_format_detailed \
                "${date_str}" "${total_checks}" "${ok_count}" "${warn_count}" \
                "${crit_count}" "${escalation_count}" "${actions_count}" \
                "${started_at}" "${stopped_at}" "${categories_json}" "${log_file}"
            ;;
    esac
}

# Brief format: 5-line summary suitable for quick glance or mobile notification.
morning_report_format_brief() {
    local date_str="${1:-$(date +"%Y-%m-%d")}"
    local log_file="${NIGHT_WATCH_LOG_DIR}/${date_str}.json"

    if [ ! -f "${log_file}" ]; then
        echo "No data for ${date_str}."
        return 0
    fi

    local total_checks ok_count warn_count crit_count escalation_count actions_count
    local started_at stopped_at
    total_checks=$(json_get "${log_file}" ".summary.total_checks" "0")
    ok_count=$(json_get "${log_file}" ".summary.ok" "0")
    warn_count=$(json_get "${log_file}" ".summary.warnings" "0")
    crit_count=$(json_get "${log_file}" ".summary.critical" "0")
    escalation_count=$(json_get "${log_file}" ".summary.escalations" "0")
    actions_count=$(json_get "${log_file}" ".summary.actions_taken" "0")
    started_at=$(json_get "${log_file}" ".started_at" "unknown")
    stopped_at=$(json_get "${log_file}" ".stopped_at" "unknown")

    _morning_report_format_brief \
        "${date_str}" "${total_checks}" "${ok_count}" "${warn_count}" \
        "${crit_count}" "${escalation_count}" "${actions_count}" \
        "${started_at}" "${stopped_at}"
}

# Detailed format: full report with all sections.
morning_report_format_detailed() {
    local date_str="${1:-$(date +"%Y-%m-%d")}"
    local log_file="${NIGHT_WATCH_LOG_DIR}/${date_str}.json"

    if [ ! -f "${log_file}" ]; then
        echo "No data for ${date_str}."
        return 0
    fi

    local total_checks ok_count warn_count crit_count escalation_count actions_count
    local started_at stopped_at categories_json
    total_checks=$(json_get "${log_file}" ".summary.total_checks" "0")
    ok_count=$(json_get "${log_file}" ".summary.ok" "0")
    warn_count=$(json_get "${log_file}" ".summary.warnings" "0")
    crit_count=$(json_get "${log_file}" ".summary.critical" "0")
    escalation_count=$(json_get "${log_file}" ".summary.escalations" "0")
    actions_count=$(json_get "${log_file}" ".summary.actions_taken" "0")
    started_at=$(json_get "${log_file}" ".started_at" "unknown")
    stopped_at=$(json_get "${log_file}" ".stopped_at" "unknown")
    categories_json=$(jq -r '
        .entries | group_by(.category)
        | map({category: .[0].category, total: length,
               ok: [.[] | select(.severity == "ok")] | length,
               warnings: [.[] | select(.severity == "warning")] | length,
               critical: [.[] | select(.severity == "critical")] | length,
               actions: [.[] | select(.action_taken != null)] | length})
    ' "${log_file}" 2>/dev/null || echo "[]")

    _morning_report_format_detailed \
        "${date_str}" "${total_checks}" "${ok_count}" "${warn_count}" \
        "${crit_count}" "${escalation_count}" "${actions_count}" \
        "${started_at}" "${stopped_at}" "${categories_json}" "${log_file}"
}

# Executive format: key metrics and action items only.
morning_report_format_executive() {
    local date_str="${1:-$(date +"%Y-%m-%d")}"
    local log_file="${NIGHT_WATCH_LOG_DIR}/${date_str}.json"

    if [ ! -f "${log_file}" ]; then
        echo "No data for ${date_str}."
        return 0
    fi

    local total_checks ok_count warn_count crit_count escalation_count actions_count
    local started_at stopped_at categories_json
    total_checks=$(json_get "${log_file}" ".summary.total_checks" "0")
    ok_count=$(json_get "${log_file}" ".summary.ok" "0")
    warn_count=$(json_get "${log_file}" ".summary.warnings" "0")
    crit_count=$(json_get "${log_file}" ".summary.critical" "0")
    escalation_count=$(json_get "${log_file}" ".summary.escalations" "0")
    actions_count=$(json_get "${log_file}" ".summary.actions_taken" "0")
    started_at=$(json_get "${log_file}" ".started_at" "unknown")
    stopped_at=$(json_get "${log_file}" ".stopped_at" "unknown")
    categories_json=$(jq -r '
        .entries | group_by(.category)
        | map({category: .[0].category, total: length,
               ok: [.[] | select(.severity == "ok")] | length,
               warnings: [.[] | select(.severity == "warning")] | length,
               critical: [.[] | select(.severity == "critical")] | length,
               actions: [.[] | select(.action_taken != null)] | length})
    ' "${log_file}" 2>/dev/null || echo "[]")

    _morning_report_format_executive \
        "${date_str}" "${total_checks}" "${ok_count}" "${warn_count}" \
        "${crit_count}" "${escalation_count}" "${actions_count}" \
        "${started_at}" "${stopped_at}" "${categories_json}" "${log_file}"
}

# --- Format Implementations ---

# Brief: 5-line summary
_morning_report_format_brief() {
    local date_str="$1" total_checks="$2" ok_count="$3" warn_count="$4"
    local crit_count="$5" escalation_count="$6" actions_count="$7"
    local started_at="$8" stopped_at="$9"

    # Determine overall status
    local status="ALL CLEAR"
    if [ "${crit_count}" -gt 0 ]; then
        status="CRITICAL ISSUES"
    elif [ "${warn_count}" -gt 0 ]; then
        status="WARNINGS"
    fi

    cat <<BRIEF
OTTO Morning Report - ${date_str} | ${status}
Watch period: ${started_at} - ${stopped_at}
Checks: ${total_checks} total | OK: ${ok_count} | Warnings: ${warn_count} | Critical: ${crit_count}
Escalations: ${escalation_count} | Auto-actions: ${actions_count}
$([ "${crit_count}" -gt 0 ] && echo "ACTION REQUIRED: ${crit_count} critical finding(s) need attention." || echo "No critical issues overnight. Systems nominal.")
BRIEF
}

# Detailed: full report with all sections
_morning_report_format_detailed() {
    local date_str="$1" total_checks="$2" ok_count="$3" warn_count="$4"
    local crit_count="$5" escalation_count="$6" actions_count="$7"
    local started_at="$8" stopped_at="$9" categories_json="${10}" log_file="${11}"

    # Overall status
    local status="ALL CLEAR"
    local status_icon="[OK]"
    if [ "${crit_count}" -gt 0 ]; then
        status="CRITICAL ISSUES DETECTED"
        status_icon="[!!]"
    elif [ "${warn_count}" -gt 0 ]; then
        status="WARNINGS DETECTED"
        status_icon="[!]"
    fi

    cat <<HEADER
================================================================================
  OTTO Morning Report - ${date_str}
  Status: ${status_icon} ${status}
================================================================================

--- ${SECTION_EXECUTIVE} ---
Watch period: ${started_at} - ${stopped_at}
Total check cycles: ${total_checks}
Results: ${ok_count} OK / ${warn_count} warnings / ${crit_count} critical
Escalations sent: ${escalation_count}
Auto-remediation actions: ${actions_count}

HEADER

    # System Health section
    echo "--- ${SECTION_HEALTH} ---"
    _format_category_section "${categories_json}" "system_health" "System Health"
    _format_category_section "${categories_json}" "database_health" "Database Health"
    _format_category_section "${categories_json}" "monitoring_alerts" "Monitoring Alerts"
    _format_category_section "${categories_json}" "ssl_certificates" "SSL Certificates"
    _format_category_section "${categories_json}" "backup_status" "Backup Status"
    echo ""

    # Deployments section
    echo "--- ${SECTION_DEPLOYMENTS} ---"
    _format_category_section "${categories_json}" "cicd_pipelines" "CI/CD Pipelines"
    _format_category_section "${categories_json}" "kubernetes_pods" "Kubernetes Pods"
    echo ""

    # Security section
    echo "--- ${SECTION_SECURITY} ---"
    _format_category_section "${categories_json}" "security_events" "Security Events"
    echo ""

    # Action Items section
    echo "--- ${SECTION_ACTION_ITEMS} ---"
    _format_action_items "${log_file}"
    echo ""

    # Trends section (if configured)
    local include_trends
    include_trends=$(config_get ".night_watcher.morning_report.include_trends" "true")
    if [ "${include_trends}" = "true" ]; then
        echo "--- ${SECTION_TRENDS} ---"
        _format_trends "${date_str}"
        echo ""
    fi

    echo "================================================================================"
    echo "  Report generated by OTTO Night Watcher"
    echo "================================================================================"
}

# Executive: key metrics and action items only
_morning_report_format_executive() {
    local date_str="$1" total_checks="$2" ok_count="$3" warn_count="$4"
    local crit_count="$5" escalation_count="$6" actions_count="$7"
    local started_at="$8" stopped_at="$9" categories_json="${10}" log_file="${11}"

    # Overall status
    local status="ALL CLEAR"
    if [ "${crit_count}" -gt 0 ]; then
        status="CRITICAL"
    elif [ "${warn_count}" -gt 0 ]; then
        status="WARNINGS"
    fi

    cat <<EXEC
OTTO Executive Report - ${date_str}
Status: ${status} | Checks: ${total_checks} | Critical: ${crit_count} | Warnings: ${warn_count}

Key Metrics:
  Escalations: ${escalation_count}
  Auto-actions: ${actions_count}
  Uptime checks OK: ${ok_count}/${total_checks}

EXEC

    # List categories with issues
    local categories_with_issues
    categories_with_issues=$(echo "${categories_json}" | \
        jq -r '.[] | select(.warnings > 0 or .critical > 0) | "  - \(.category): \(.critical) critical, \(.warnings) warnings"' \
        2>/dev/null || true)

    if [ -n "${categories_with_issues}" ]; then
        echo "Areas Requiring Attention:"
        echo "${categories_with_issues}"
        echo ""
    fi

    # Action items
    echo "--- ${SECTION_ACTION_ITEMS} ---"
    _format_action_items "${log_file}"
}

# --- Report Section Helpers ---

# Format a single category section from aggregated data.
_format_category_section() {
    local categories_json="$1"
    local category="$2"
    local display_name="$3"

    local cat_data
    cat_data=$(echo "${categories_json}" | \
        jq -r ".[] | select(.category == \"${category}\")" 2>/dev/null || echo "")

    if [ -z "${cat_data}" ] || [ "${cat_data}" = "null" ]; then
        echo "  ${display_name}: No data collected"
        return 0
    fi

    local total ok warnings critical
    total=$(echo "${cat_data}" | jq -r '.total // 0')
    ok=$(echo "${cat_data}" | jq -r '.ok // 0')
    warnings=$(echo "${cat_data}" | jq -r '.warnings // 0')
    critical=$(echo "${cat_data}" | jq -r '.critical // 0')

    local status_marker="[OK]"
    if [ "${critical}" -gt 0 ]; then
        status_marker="[!!]"
    elif [ "${warnings}" -gt 0 ]; then
        status_marker="[!]"
    fi

    echo "  ${status_marker} ${display_name}: ${total} checks - ${ok} ok, ${warnings} warn, ${critical} crit"
}

# Format action items from the log file.
# Action items are critical findings and any remediation actions taken.
_format_action_items() {
    local log_file="$1"

    if [ ! -f "${log_file}" ]; then
        echo "  No action items."
        return 0
    fi

    # Extract critical entries that need attention
    local critical_entries
    critical_entries=$(jq -r '
        .entries
        | [.[] | select(.severity == "critical")]
        | if length == 0 then empty
          else .[] | "  [!!] \(.category): \(.message)"
          end
    ' "${log_file}" 2>/dev/null || true)

    # Extract warning entries
    local warning_entries
    warning_entries=$(jq -r '
        .entries
        | [.[] | select(.severity == "warning")]
        | if length == 0 then empty
          else .[] | "  [!]  \(.category): \(.message)"
          end
    ' "${log_file}" 2>/dev/null || true)

    # Extract auto-remediation actions taken
    local actions_taken
    actions_taken=$(jq -r '
        .entries
        | [.[] | select(.action_taken != null)]
        | if length == 0 then empty
          else .[] | "  [->] Auto-action: \(.action_taken) (\(.category))"
          end
    ' "${log_file}" 2>/dev/null || true)

    local has_items=false

    if [ -n "${critical_entries}" ]; then
        echo "${critical_entries}"
        has_items=true
    fi

    if [ -n "${warning_entries}" ]; then
        echo "${warning_entries}"
        has_items=true
    fi

    if [ -n "${actions_taken}" ]; then
        echo "${actions_taken}"
        has_items=true
    fi

    if [ "${has_items}" = "false" ]; then
        echo "  No action items. All systems nominal."
    fi
}

# Format trends by comparing with previous days' logs.
_format_trends() {
    local current_date="$1"

    # Look back up to 7 days for trend data
    local days_back=7
    local trend_data="[]"
    local i

    for ((i = 0; i < days_back; i++)); do
        local check_date
        check_date=$(date -d "${current_date} - ${i} days" +"%Y-%m-%d" 2>/dev/null || true)
        if [ -z "${check_date}" ]; then
            continue
        fi

        local check_file="${NIGHT_WATCH_LOG_DIR}/${check_date}.json"
        if [ -f "${check_file}" ]; then
            local day_summary
            day_summary=$(jq -r \
                --arg d "${check_date}" \
                '{date: $d, total: .summary.total_checks, warnings: .summary.warnings, critical: .summary.critical}' \
                "${check_file}" 2>/dev/null || true)
            if [ -n "${day_summary}" ]; then
                trend_data=$(echo "${trend_data}" | jq --argjson entry "${day_summary}" '. += [$entry]')
            fi
        fi
    done

    local data_points
    data_points=$(echo "${trend_data}" | jq 'length')

    if [ "${data_points}" -le 1 ]; then
        echo "  Insufficient data for trend analysis (need 2+ days)."
        return 0
    fi

    # Display daily summary
    echo "  Last ${data_points} days:"
    echo "${trend_data}" | jq -r '.[] | "    \(.date): \(.total) checks, \(.warnings) warnings, \(.critical) critical"'

    # Calculate averages
    local avg_warnings avg_critical
    avg_warnings=$(echo "${trend_data}" | jq '[.[].warnings] | add / length | floor')
    avg_critical=$(echo "${trend_data}" | jq '[.[].critical] | add / length | floor')

    echo ""
    echo "  Averages: ~${avg_warnings} warnings/night, ~${avg_critical} critical/night"

    # Simple trend direction
    if [ "${data_points}" -ge 2 ]; then
        local latest_warn oldest_warn
        latest_warn=$(echo "${trend_data}" | jq '.[0].warnings')
        oldest_warn=$(echo "${trend_data}" | jq '.[-1].warnings')

        if [ "${latest_warn}" -gt "${oldest_warn}" ]; then
            echo "  Trend: Warnings INCREASING"
        elif [ "${latest_warn}" -lt "${oldest_warn}" ]; then
            echo "  Trend: Warnings DECREASING"
        else
            echo "  Trend: Warnings STABLE"
        fi
    fi
}

# --- CLI Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    format="${1:-auto}"
    date_str="${2:-$(date +"%Y-%m-%d")}"

    case "${format}" in
        auto|generate)
            morning_report_generate "${date_str}"
            ;;
        brief)
            morning_report_format_brief "${date_str}"
            ;;
        detailed)
            morning_report_format_detailed "${date_str}"
            ;;
        executive)
            morning_report_format_executive "${date_str}"
            ;;
        *)
            echo "Usage: morning-report.sh {auto|brief|detailed|executive} [YYYY-MM-DD]" >&2
            exit 1
            ;;
    esac
fi
