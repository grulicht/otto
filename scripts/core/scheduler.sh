#!/usr/bin/env bash
# OTTO - Scheduled Checks (Wave 2)
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_SCHEDULER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_SCHEDULER_LOADED=1

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
source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/i18n.sh"

OTTO_STATE_DIR="${OTTO_HOME}/state"
OTTO_SCHEDULER_FILE="${OTTO_STATE_DIR}/scheduler.json"

# --- Internal helpers ---

# Initialize the scheduler state file if it does not exist.
_scheduler_init_state() {
    mkdir -p "${OTTO_STATE_DIR}"
    if [[ ! -f "${OTTO_SCHEDULER_FILE}" ]]; then
        echo '{"checks":[],"last_updated":""}' > "${OTTO_SCHEDULER_FILE}"
    fi
}

# Parse a simple cron expression and determine if it matches the current time.
# Supports: minute hour day-of-month month day-of-week
# Supports: * (any), specific numbers, and */N (every N).
#   $1 - Cron expression (5 fields: min hour dom month dow)
# Returns 0 if the current time matches, 1 otherwise.
_cron_matches_now() {
    local cron_expr="$1"

    local cron_min cron_hour cron_dom cron_mon cron_dow
    read -r cron_min cron_hour cron_dom cron_mon cron_dow <<< "${cron_expr}"

    local now_min now_hour now_dom now_mon now_dow
    now_min=$(date +"%M" | sed 's/^0//')
    now_hour=$(date +"%H" | sed 's/^0//')
    now_dom=$(date +"%d" | sed 's/^0//')
    now_mon=$(date +"%m" | sed 's/^0//')
    now_dow=$(date +"%u")  # 1=Monday, 7=Sunday

    # Convert Sunday: cron uses 0=Sunday, date %u gives 7
    if [[ "${now_dow}" -eq 7 ]]; then
        now_dow=0
    fi

    _cron_field_matches "${cron_min}" "${now_min:-0}" || return 1
    _cron_field_matches "${cron_hour}" "${now_hour:-0}" || return 1
    _cron_field_matches "${cron_dom}" "${now_dom:-1}" || return 1
    _cron_field_matches "${cron_mon}" "${now_mon:-1}" || return 1
    _cron_field_matches "${cron_dow}" "${now_dow}" || return 1

    return 0
}

# Check if a single cron field matches a value.
#   $1 - Cron field (*, N, */N)
#   $2 - Current value
_cron_field_matches() {
    local field="$1"
    local value="$2"

    # Wildcard
    if [[ "${field}" == "*" ]]; then
        return 0
    fi

    # Step: */N
    if [[ "${field}" =~ ^\*/([0-9]+)$ ]]; then
        local step="${BASH_REMATCH[1]}"
        if [[ $(( value % step )) -eq 0 ]]; then
            return 0
        fi
        return 1
    fi

    # Comma-separated list
    if [[ "${field}" == *","* ]]; then
        local item
        IFS=',' read -ra items <<< "${field}"
        for item in "${items[@]}"; do
            if [[ "${item}" -eq "${value}" ]]; then
                return 0
            fi
        done
        return 1
    fi

    # Range: N-M
    if [[ "${field}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local range_start="${BASH_REMATCH[1]}"
        local range_end="${BASH_REMATCH[2]}"
        if [[ "${value}" -ge "${range_start}" ]] && [[ "${value}" -le "${range_end}" ]]; then
            return 0
        fi
        return 1
    fi

    # Exact match
    if [[ "${field}" -eq "${value}" ]] 2>/dev/null; then
        return 0
    fi

    return 1
}

# Calculate the next run time for a cron expression (approximate, human-readable).
#   $1 - Cron expression
_cron_next_run() {
    local cron_expr="$1"
    local cron_min cron_hour cron_dom cron_mon cron_dow
    read -r cron_min cron_hour cron_dom cron_mon cron_dow <<< "${cron_expr}"

    # Simple approximation for display purposes
    if [[ "${cron_min}" == "*" ]] && [[ "${cron_hour}" == "*" ]]; then
        echo "every minute"
    elif [[ "${cron_hour}" == "*" ]]; then
        echo "hourly at :${cron_min}"
    elif [[ "${cron_dom}" == "*" ]] && [[ "${cron_dow}" == "*" ]]; then
        printf 'daily at %02d:%02d' "${cron_hour}" "${cron_min}"
    elif [[ "${cron_dow}" != "*" ]]; then
        local day_names=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
        local day_name="${day_names[${cron_dow}]:-${cron_dow}}"
        printf '%s at %02d:%02d' "${day_name}" "${cron_hour}" "${cron_min}"
    else
        printf 'day %s at %02d:%02d' "${cron_dom}" "${cron_hour}" "${cron_min}"
    fi
}

# --- Public API ---

# Load scheduled checks from config (scheduled_checks section).
scheduler_load() {
    _scheduler_init_state

    local config_file="${OTTO_DIR}/config/default.yaml"
    local user_config="${OTTO_HOME}/config.yaml"

    # Prefer user config
    local source_config="${config_file}"
    if [[ -f "${user_config}" ]]; then
        source_config="${user_config}"
    fi

    if ! command -v yq &>/dev/null; then
        log_warn "yq not installed, cannot load scheduled checks from config"
        return 0
    fi

    local count
    count=$(yq eval '.scheduled_checks | length' "${source_config}" 2>/dev/null || echo 0)

    if [[ "${count}" -eq 0 ]] || [[ "${count}" == "null" ]]; then
        log_debug "No scheduled checks in config"
        return 0
    fi

    local i
    for (( i=0; i<count; i++ )); do
        local name cron check alert_if
        name=$(yq eval ".scheduled_checks[${i}].name" "${source_config}" 2>/dev/null || echo "")
        cron=$(yq eval ".scheduled_checks[${i}].cron" "${source_config}" 2>/dev/null || echo "")
        check=$(yq eval ".scheduled_checks[${i}].check" "${source_config}" 2>/dev/null || echo "")
        alert_if=$(yq eval ".scheduled_checks[${i}].alert_if" "${source_config}" 2>/dev/null || echo "")

        if [[ -n "${name}" ]] && [[ "${name}" != "null" ]]; then
            # Add to scheduler state if not already present
            local exists
            exists=$(jq -r ".checks[] | select(.name == \"${name}\") | .name" "${OTTO_SCHEDULER_FILE}" 2>/dev/null || echo "")
            if [[ -z "${exists}" ]]; then
                local entry
                entry=$(jq -n \
                    --arg name "${name}" \
                    --arg cron "${cron}" \
                    --arg check "${check}" \
                    --arg alert_if "${alert_if}" \
                    --arg last_run "" \
                    '{"name":$name,"cron":$cron,"check":$check,"alert_if":$alert_if,"last_run":$last_run}')
                json_append "${OTTO_SCHEDULER_FILE}" ".checks" "${entry}"
            fi
        fi
    done

    log_info "Loaded scheduled checks from config"
}

# Check which scheduled items are due based on last run time and cron expression.
# Outputs names of due checks, one per line.
scheduler_check_due() {
    _scheduler_init_state

    local checks
    checks=$(jq -c '.checks[]?' "${OTTO_SCHEDULER_FILE}" 2>/dev/null || true)

    if [[ -z "${checks}" ]]; then
        return 0
    fi

    while IFS= read -r check_json; do
        local name cron_expr last_run
        name=$(echo "${check_json}" | jq -r '.name')
        cron_expr=$(echo "${check_json}" | jq -r '.cron')
        last_run=$(echo "${check_json}" | jq -r '.last_run // empty')

        # Skip if cron doesn't match now
        if ! _cron_matches_now "${cron_expr}"; then
            continue
        fi

        # Skip if already run in the current minute
        local current_minute
        current_minute=$(date +"%Y-%m-%dT%H:%M")
        if [[ -n "${last_run}" ]] && [[ "${last_run}" == "${current_minute}"* ]]; then
            continue
        fi

        echo "${name}"
    done <<< "${checks}"
}

# Execute all due checks and update last run times.
scheduler_run_due() {
    _scheduler_init_state

    log_info "$(i18n_get SCHEDULER_RUNNING "Running due checks")"

    local due_checks
    due_checks=$(scheduler_check_due)

    if [[ -z "${due_checks}" ]]; then
        log_info "No checks are due"
        return 0
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    while IFS= read -r check_name; do
        local check_json
        check_json=$(jq -c ".checks[] | select(.name == \"${check_name}\")" "${OTTO_SCHEDULER_FILE}" 2>/dev/null)

        local check_cmd
        check_cmd=$(echo "${check_json}" | jq -r '.check')
        local alert_if
        alert_if=$(echo "${check_json}" | jq -r '.alert_if // empty')

        log_info "Running scheduled check: ${check_name} (${check_cmd})"

        # Execute the check
        local result=""
        local exit_code=0
        if [[ -x "${OTTO_DIR}/scripts/core/${check_cmd}.sh" ]]; then
            result=$("${OTTO_DIR}/scripts/core/${check_cmd}.sh" 2>&1) || exit_code=$?
        elif command -v "${check_cmd}" &>/dev/null; then
            result=$(${check_cmd} 2>&1) || exit_code=$?
        else
            log_warn "Check command not found: ${check_cmd}"
            result="Command not found: ${check_cmd}"
            exit_code=1
        fi

        # Update last run time
        local tmp
        tmp=$(mktemp)
        jq "(.checks[] | select(.name == \"${check_name}\")).last_run = \"${now}\"" \
            "${OTTO_SCHEDULER_FILE}" > "${tmp}" && mv "${tmp}" "${OTTO_SCHEDULER_FILE}"

        if [[ "${exit_code}" -ne 0 ]]; then
            log_warn "Check ${check_name} failed (exit ${exit_code}): ${result}"
        else
            log_info "Check ${check_name} completed successfully"
        fi

    done <<< "${due_checks}"
}

# List all scheduled checks with their next run time.
scheduler_list() {
    _scheduler_init_state

    echo -e "${BOLD}$(i18n_get SCHEDULER_TITLE "Scheduled Checks")${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"

    local checks
    checks=$(jq -c '.checks[]?' "${OTTO_SCHEDULER_FILE}" 2>/dev/null || true)

    if [[ -z "${checks}" ]]; then
        echo -e "  ${DIM}$(i18n_get SCHEDULER_NONE "No scheduled checks")${NC}"
        return 0
    fi

    printf '  %-20s %-16s %-20s %s\n' \
        "$(i18n_get SCHEDULER_NAME "Name")" \
        "$(i18n_get SCHEDULER_CRON "Schedule")" \
        "$(i18n_get SCHEDULER_NEXT "Next Run")" \
        "$(i18n_get SCHEDULER_LAST "Last Run")"
    echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

    while IFS= read -r check_json; do
        local name cron_expr check_cmd last_run next_run
        name=$(echo "${check_json}" | jq -r '.name')
        cron_expr=$(echo "${check_json}" | jq -r '.cron')
        check_cmd=$(echo "${check_json}" | jq -r '.check')
        last_run=$(echo "${check_json}" | jq -r '.last_run // "never"')
        next_run=$(_cron_next_run "${cron_expr}")

        printf '  %-20s %-16s %-20s %s\n' "${name}" "${cron_expr}" "${next_run}" "${last_run}"
    done <<< "${checks}"
}

# Add a new scheduled check.
#   $1 - Check name
#   $2 - Cron expression (5 fields)
#   $3 - Check command
#   $4 - Alert condition (optional)
scheduler_add() {
    local name="$1"
    local cron="$2"
    local check="$3"
    local alert_if="${4:-}"

    if [[ -z "${name}" ]] || [[ -z "${cron}" ]] || [[ -z "${check}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): name, cron, check"
        return 1
    fi

    _scheduler_init_state

    # Check for duplicate
    local exists
    exists=$(jq -r ".checks[] | select(.name == \"${name}\") | .name" "${OTTO_SCHEDULER_FILE}" 2>/dev/null || echo "")
    if [[ -n "${exists}" ]]; then
        log_error "Check '${name}' already exists. Remove it first."
        return 1
    fi

    local entry
    entry=$(jq -n \
        --arg name "${name}" \
        --arg cron "${cron}" \
        --arg check "${check}" \
        --arg alert_if "${alert_if}" \
        --arg last_run "" \
        '{"name":$name,"cron":$cron,"check":$check,"alert_if":$alert_if,"last_run":$last_run}')

    json_append "${OTTO_SCHEDULER_FILE}" ".checks" "${entry}"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    json_set_string "${OTTO_SCHEDULER_FILE}" ".last_updated" "${now}"

    log_info "$(i18n_get SCHEDULER_ADDED "Check added"): ${name}"
}

# Remove a scheduled check by name.
#   $1 - Check name
scheduler_remove() {
    local name="$1"

    if [[ -z "${name}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): name"
        return 1
    fi

    _scheduler_init_state

    local tmp
    tmp=$(mktemp)
    jq "del(.checks[] | select(.name == \"${name}\"))" \
        "${OTTO_SCHEDULER_FILE}" > "${tmp}" && mv "${tmp}" "${OTTO_SCHEDULER_FILE}"

    log_info "$(i18n_get SCHEDULER_REMOVED "Check removed"): ${name}"
}

# --- CLI ---

_scheduler_usage() {
    echo "Usage: otto scheduler <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list                      List all scheduled checks"
    echo "  run                       Execute all due checks"
    echo "  add <name> <cron> <check> Add a new scheduled check"
    echo "  remove <name>             Remove a scheduled check"
    echo ""
    echo "Examples:"
    echo "  otto scheduler add ssl-weekly '0 9 * * 1' ssl-certs"
    echo "  otto scheduler list"
    echo "  otto scheduler run"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    i18n_init 2>/dev/null || true
    scheduler_load 2>/dev/null || true

    case "${1:-}" in
        list)
            scheduler_list
            ;;
        run)
            scheduler_run_due
            ;;
        add)
            scheduler_add "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        remove)
            scheduler_remove "${2:-}"
            ;;
        -h|--help|"")
            _scheduler_usage
            ;;
        *)
            log_error "Unknown command: $1"
            _scheduler_usage
            exit 1
            ;;
    esac
fi
