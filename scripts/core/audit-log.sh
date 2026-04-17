#!/usr/bin/env bash
# OTTO - Audit trail logging and reporting
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_AUDIT_LOG_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_AUDIT_LOG_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# Audit log location
OTTO_STATE_DIR="${OTTO_HOME}/state"
OTTO_AUDIT_FILE="${OTTO_STATE_DIR}/audit.jsonl"

# --- Public API ---

# Write an audit log entry.
#   $1 - Actor (username, "otto", or agent name)
#   $2 - Action (deploy, rollback, config_change, scale, delete, etc.)
#   $3 - Target resource
#   $4 - Details (human-readable description)
#   $5 - Result (success, failure, denied)
audit_log() {
    local actor="$1"
    local action="$2"
    local target="${3:-}"
    local details="${4:-}"
    local result="${5:-success}"

    mkdir -p "${OTTO_STATE_DIR}"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local environment
    environment=$(config_get ".current_environment" "unknown" 2>/dev/null || echo "unknown")

    local permission_level
    permission_level=$(config_get ".permissions.default_mode" "suggest" 2>/dev/null || echo "suggest")

    local escaped_details
    escaped_details=$(printf '%s' "${details}" | jq -Rs '.')

    local escaped_target
    escaped_target=$(printf '%s' "${target}" | jq -Rs '.')

    printf '{"ts":"%s","actor":"%s","action":"%s","target":%s,"environment":"%s","details":%s,"result":"%s","permission_level":"%s"}\n' \
        "${timestamp}" "${actor}" "${action}" "${escaped_target}" \
        "${environment}" "${escaped_details}" "${result}" "${permission_level}" \
        >> "${OTTO_AUDIT_FILE}"

    log_debug "Audit: ${actor} ${action} ${target} -> ${result}"
}

# Search the audit log with filters.
#   $1 - JSON string with filter criteria:
#         {"actor": "...", "action": "...", "result": "...",
#          "date_from": "ISO8601", "date_to": "ISO8601",
#          "environment": "..."}
# Outputs matching entries as JSON lines.
audit_search() {
    local filters_json="${1:-{}}"

    if [[ ! -f "${OTTO_AUDIT_FILE}" ]]; then
        log_info "No audit log found"
        return 0
    fi

    local jq_filter="."

    local actor action result date_from date_to environment
    actor=$(echo "${filters_json}" | jq -r '.actor // empty')
    action=$(echo "${filters_json}" | jq -r '.action // empty')
    result=$(echo "${filters_json}" | jq -r '.result // empty')
    date_from=$(echo "${filters_json}" | jq -r '.date_from // empty')
    date_to=$(echo "${filters_json}" | jq -r '.date_to // empty')
    environment=$(echo "${filters_json}" | jq -r '.environment // empty')

    # Build jq filter chain
    local conditions=()

    if [[ -n "${actor}" ]]; then
        conditions+=(".actor == \"${actor}\"")
    fi
    if [[ -n "${action}" ]]; then
        conditions+=(".action == \"${action}\"")
    fi
    if [[ -n "${result}" ]]; then
        conditions+=(".result == \"${result}\"")
    fi
    if [[ -n "${environment}" ]]; then
        conditions+=(".environment == \"${environment}\"")
    fi
    if [[ -n "${date_from}" ]]; then
        conditions+=(".ts >= \"${date_from}\"")
    fi
    if [[ -n "${date_to}" ]]; then
        conditions+=(".ts <= \"${date_to}\"")
    fi

    if [[ ${#conditions[@]} -gt 0 ]]; then
        local combined
        combined=$(printf ' and %s' "${conditions[@]}")
        combined="${combined:5}"  # Remove leading " and "
        jq_filter="select(${combined})"
    fi

    jq -c "${jq_filter}" "${OTTO_AUDIT_FILE}" 2>/dev/null
}

# Export the audit log in a specified format.
#   $1 - Format (json, csv)
#   $2 - Start date (ISO8601, optional)
#   $3 - End date (ISO8601, optional)
# Outputs formatted audit data to stdout.
audit_export() {
    local format="${1:-json}"
    local date_from="${2:-}"
    local date_to="${3:-}"

    if [[ ! -f "${OTTO_AUDIT_FILE}" ]]; then
        log_info "No audit log found"
        return 0
    fi

    # Build date filter
    local date_filter="."
    if [[ -n "${date_from}" ]] && [[ -n "${date_to}" ]]; then
        date_filter="select(.ts >= \"${date_from}\" and .ts <= \"${date_to}\")"
    elif [[ -n "${date_from}" ]]; then
        date_filter="select(.ts >= \"${date_from}\")"
    elif [[ -n "${date_to}" ]]; then
        date_filter="select(.ts <= \"${date_to}\")"
    fi

    case "${format}" in
        json)
            echo "["
            local first=true
            while IFS= read -r line; do
                if [[ "${first}" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                printf '  %s' "${line}"
            done < <(jq -c "${date_filter}" "${OTTO_AUDIT_FILE}" 2>/dev/null)
            echo ""
            echo "]"
            ;;
        csv)
            echo "timestamp,actor,action,target,environment,details,result,permission_level"
            jq -r "${date_filter} | [.ts, .actor, .action, .target, .environment, .details, .result, .permission_level] | @csv" \
                "${OTTO_AUDIT_FILE}" 2>/dev/null
            ;;
        *)
            log_error "Unsupported export format: ${format} (supported: json, csv)"
            return 1
            ;;
    esac
}

# Generate an audit summary for a given period.
#   $1 - Period (daily, weekly, monthly)
# Outputs a human-readable summary.
audit_summary() {
    local period="${1:-daily}"

    if [[ ! -f "${OTTO_AUDIT_FILE}" ]]; then
        log_info "No audit log found"
        return 0
    fi

    local date_from
    case "${period}" in
        daily)
            date_from=$(date -u -d "1 day ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
            ;;
        weekly)
            date_from=$(date -u -d "7 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
            ;;
        monthly)
            date_from=$(date -u -d "30 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-30d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
            ;;
        *)
            log_error "Invalid period: ${period} (expected daily, weekly, monthly)"
            return 1
            ;;
    esac

    echo -e "${BOLD}Audit Summary (${period})${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"

    if [[ -z "${date_from}" ]]; then
        echo "  (unable to calculate date range)"
        return 1
    fi

    echo -e "${DIM}Period: ${date_from} - now${NC}"
    echo ""

    # Total actions
    local total
    total=$(jq -c "select(.ts >= \"${date_from}\")" "${OTTO_AUDIT_FILE}" 2>/dev/null | wc -l)
    echo -e "  ${BOLD}Total actions:${NC} ${total}"

    # Actions by result
    echo -e "  ${BOLD}By result:${NC}"
    local result_counts
    result_counts=$(jq -c "select(.ts >= \"${date_from}\")" "${OTTO_AUDIT_FILE}" 2>/dev/null | \
        jq -r '.result' | sort | uniq -c | sort -rn)
    if [[ -n "${result_counts}" ]]; then
        echo "${result_counts}" | while read -r count result_name; do
            local color=""
            case "${result_name}" in
                success) color="${GREEN}" ;;
                failure) color="${RED}" ;;
                denied)  color="${YELLOW}" ;;
            esac
            printf '    %b%-10s%b %s\n' "${color}" "${result_name}" "${NC}" "${count}"
        done
    fi

    # Actions by actor
    echo -e "  ${BOLD}By actor:${NC}"
    jq -c "select(.ts >= \"${date_from}\")" "${OTTO_AUDIT_FILE}" 2>/dev/null | \
        jq -r '.actor' | sort | uniq -c | sort -rn | head -10 | while read -r count actor_name; do
        printf '    %-20s %s\n' "${actor_name}" "${count}"
    done

    # Actions by type
    echo -e "  ${BOLD}By action:${NC}"
    jq -c "select(.ts >= \"${date_from}\")" "${OTTO_AUDIT_FILE}" 2>/dev/null | \
        jq -r '.action' | sort | uniq -c | sort -rn | head -10 | while read -r count action_name; do
        printf '    %-20s %s\n' "${action_name}" "${count}"
    done

    echo ""
    echo -e "${DIM}──────────────────────────────────────────${NC}"
}

# Generate a compliance-ready audit report.
# Outputs a structured report suitable for compliance reviews.
audit_compliance_report() {
    if [[ ! -f "${OTTO_AUDIT_FILE}" ]]; then
        log_info "No audit log found"
        return 0
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local total_entries
    total_entries=$(wc -l < "${OTTO_AUDIT_FILE}")

    echo -e "${BOLD}OTTO Compliance Audit Report${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}Generated:${NC}    ${now}"
    echo -e "  ${CYAN}Total entries:${NC} ${total_entries}"
    echo -e "  ${CYAN}Log file:${NC}     ${OTTO_AUDIT_FILE}"
    echo ""

    # Denied actions (potential policy violations)
    echo -e "${BOLD}Denied Actions (potential policy violations):${NC}"
    local denied_count
    denied_count=$(jq -c 'select(.result == "denied")' "${OTTO_AUDIT_FILE}" 2>/dev/null | wc -l)
    echo -e "  Count: ${denied_count}"

    if [[ "${denied_count}" -gt 0 ]]; then
        echo ""
        jq -c 'select(.result == "denied")' "${OTTO_AUDIT_FILE}" 2>/dev/null | \
            jq -r '[.ts, .actor, .action, .target, .environment] | @tsv' | \
            while IFS=$'\t' read -r ts actor action target env; do
                printf '  %s  %-12s  %-15s  %-20s  %s\n' "${ts}" "${actor}" "${action}" "${target}" "${env}"
            done
    fi
    echo ""

    # Failed actions
    echo -e "${BOLD}Failed Actions:${NC}"
    local failed_count
    failed_count=$(jq -c 'select(.result == "failure")' "${OTTO_AUDIT_FILE}" 2>/dev/null | wc -l)
    echo -e "  Count: ${failed_count}"

    if [[ "${failed_count}" -gt 0 ]]; then
        echo ""
        jq -c 'select(.result == "failure")' "${OTTO_AUDIT_FILE}" 2>/dev/null | \
            jq -r '[.ts, .actor, .action, .target, .details] | @tsv' | head -20 | \
            while IFS=$'\t' read -r ts actor action target details; do
                printf '  %s  %-12s  %-15s  %s  %s\n' "${ts}" "${actor}" "${action}" "${target}" "${details}"
            done
    fi
    echo ""

    # Production environment actions
    echo -e "${BOLD}Production Environment Actions:${NC}"
    local prod_count
    prod_count=$(jq -c 'select(.environment == "prod" or .environment == "production")' "${OTTO_AUDIT_FILE}" 2>/dev/null | wc -l)
    echo -e "  Count: ${prod_count}"
    echo ""

    # Permission level distribution
    echo -e "${BOLD}Permission Level Distribution:${NC}"
    jq -r '.permission_level' "${OTTO_AUDIT_FILE}" 2>/dev/null | sort | uniq -c | sort -rn | \
        while read -r count level; do
            printf '  %-10s %s\n' "${level}" "${count}"
        done
    echo ""

    # Unique actors
    echo -e "${BOLD}Unique Actors:${NC}"
    jq -r '.actor' "${OTTO_AUDIT_FILE}" 2>/dev/null | sort -u | while read -r actor_name; do
        local actor_count
        actor_count=$(jq -c "select(.actor == \"${actor_name}\")" "${OTTO_AUDIT_FILE}" 2>/dev/null | wc -l)
        printf '  %-20s %s actions\n' "${actor_name}" "${actor_count}"
    done
    echo ""

    echo -e "${DIM}──────────────────────────────────────────${NC}"
    echo -e "${DIM}End of compliance report${NC}"
}
