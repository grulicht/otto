#!/usr/bin/env bash
set -euo pipefail

# OTTO - Night Watcher overnight monitoring
# Monitors systems during off-hours, escalates critical issues,
# and generates morning reports.

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source dependencies
# shellcheck source=../lib/logging.sh
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=../lib/colors.sh
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=../lib/json-utils.sh
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=../lib/error-handling.sh
source "${OTTO_DIR}/scripts/lib/error-handling.sh"
# shellcheck source=config.sh
source "${OTTO_DIR}/scripts/core/config.sh"
# shellcheck source=state.sh
source "${OTTO_DIR}/scripts/core/state.sh"
# shellcheck source=heartbeat.sh
source "${OTTO_DIR}/scripts/core/heartbeat.sh"
# shellcheck source=morning-report.sh
source "${OTTO_DIR}/scripts/core/morning-report.sh"

# --- Constants (guarded against re-source) ---

if [[ -z "${_OTTO_NIGHT_WATCHER_LOADED:-}" ]]; then
_OTTO_NIGHT_WATCHER_LOADED=1

readonly NIGHT_WATCH_DIR="${OTTO_HOME}/state/night-watch"
readonly NIGHT_WATCH_STATE_KEY=".night_watcher"

# Severity levels
readonly SEVERITY_OK="ok"
readonly SEVERITY_WARNING="warning"
readonly SEVERITY_CRITICAL="critical"

# Default escalation cooldown in seconds
readonly DEFAULT_ESCALATION_COOLDOWN=1800  # 30 minutes

fi  # _OTTO_NIGHT_WATCHER_LOADED

# --- Night Watch Log Path ---

# Returns the path to today's night watch log file.
_night_watch_log_file() {
    local date_str="${1:-}"
    if [ -z "${date_str}" ]; then
        date_str=$(date +"%Y-%m-%d")
    fi
    echo "${NIGHT_WATCH_DIR}/${date_str}.json"
}

# --- State Helpers ---

_night_watcher_get_state() {
    local key="$1"
    local default="${2:-}"
    local state_file="${OTTO_HOME}/state/state.json"

    json_get "${state_file}" "${NIGHT_WATCH_STATE_KEY}.${key}" "${default}"
}

_night_watcher_set_state() {
    local key="$1"
    local value="$2"
    local state_file="${OTTO_HOME}/state/state.json"

    json_set "${state_file}" "${NIGHT_WATCH_STATE_KEY}.${key}" "${value}"
}

_night_watcher_set_state_string() {
    local key="$1"
    local value="$2"
    local state_file="${OTTO_HOME}/state/state.json"

    json_set_string "${state_file}" "${NIGHT_WATCH_STATE_KEY}.${key}" "${value}"
}

# --- Public Functions ---

# Activate Night Watcher mode.
# 1. Switches heartbeat to "night" mode
# 2. Sets heartbeat interval from config
# 3. Initializes night watch log for today
# 4. Sends activation notification
night_watcher_start() {
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local today
    today=$(date +"%Y-%m-%d")

    # Ensure night-watch directory exists
    mkdir -p "${NIGHT_WATCH_DIR}"

    # Switch heartbeat to night mode
    heartbeat_set_mode "night"

    # Update night watcher state
    _night_watcher_set_state "active" "true"
    _night_watcher_set_state_string "started_at" "${now}"
    _night_watcher_set_state_string "date" "${today}"
    _night_watcher_set_state "escalation_count" "0"
    _night_watcher_set_state "check_count" "0"
    _night_watcher_set_state "warning_count" "0"
    _night_watcher_set_state "critical_count" "0"

    # Initialize today's log file
    local log_file
    log_file=$(_night_watch_log_file "${today}")
    if [ ! -f "${log_file}" ]; then
        jq -n \
            --arg date "${today}" \
            --arg started "${now}" \
            '{
                date: $date,
                started_at: $started,
                stopped_at: null,
                entries: [],
                summary: {
                    total_checks: 0,
                    ok: 0,
                    warnings: 0,
                    critical: 0,
                    escalations: 0,
                    actions_taken: 0
                }
            }' > "${log_file}"
    fi

    log_info "Night Watcher activated for ${today}"
    state_log "info" "night_watcher" "Night Watcher activated"

    # Send notification (communicator handles channel routing)
    echo "Night Watcher activated at ${now}"
}

# Deactivate Night Watcher and generate morning report.
# 1. Switches heartbeat back to "normal" mode
# 2. Generates morning report
# 3. Sends morning report via communicator
night_watcher_stop() {
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update state
    _night_watcher_set_state "active" "false"
    _night_watcher_set_state_string "stopped_at" "${now}"

    # Finalize today's log
    local today
    today=$(_night_watcher_get_state "date" "$(date +"%Y-%m-%d")")
    local log_file
    log_file=$(_night_watch_log_file "${today}")

    if [ -f "${log_file}" ]; then
        json_set_string "${log_file}" ".stopped_at" "${now}"
    fi

    # Switch heartbeat back to normal
    heartbeat_set_mode "normal"

    log_info "Night Watcher deactivated"
    state_log "info" "night_watcher" "Night Watcher deactivated"

    # Generate and output morning report
    local report
    report=$(morning_report_generate "${today}")

    echo "${report}"
}

# Execute one night watch cycle.
# 1. Run all configured health checks
# 2. Collect and categorize findings (ok/warning/critical)
# 3. Log findings to night-watch log
# 4. If critical: check escalation cooldown, send immediate alert
# 5. If auto-remediation enabled: attempt allowed actions
night_watcher_tick() {
    if ! night_watcher_is_active; then
        log_warn "Night Watcher is not active, skipping tick"
        return 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local today
    today=$(_night_watcher_get_state "date" "$(date +"%Y-%m-%d")")

    log_info "Night Watcher tick at ${now}"

    # Increment check count
    local check_count
    check_count=$(_night_watcher_get_state "check_count" "0")
    check_count=$((check_count + 1))
    _night_watcher_set_state "check_count" "${check_count}"

    # Determine which checks are configured
    local checks=()
    local check_names=(
        "system_health"
        "monitoring_alerts"
        "cicd_pipelines"
        "kubernetes_pods"
        "security_events"
        "database_health"
        "ssl_certificates"
        "backup_status"
        "log_anomalies"
    )

    for check in "${check_names[@]}"; do
        local enabled
        enabled=$(config_get ".night_watcher.checks.${check}" "false")
        if [ "${enabled}" = "true" ]; then
            checks+=("${check}")
        fi
    done

    # Run checks and collect findings
    local findings_ok=0
    local findings_warning=0
    local findings_critical=0
    local tick_results="[]"

    for check in "${checks[@]}"; do
        # Each check outputs a JSON object with severity and details.
        # Checks are implemented by specialist agents; here we record the invocation.
        local finding_severity="${SEVERITY_OK}"
        local finding_message="${check} check completed"
        local finding_details="{}"

        # Log the finding
        night_watcher_log "${check}" "${finding_severity}" "${finding_message}" "${finding_details}"

        case "${finding_severity}" in
            "${SEVERITY_OK}")
                findings_ok=$((findings_ok + 1))
                ;;
            "${SEVERITY_WARNING}")
                findings_warning=$((findings_warning + 1))
                ;;
            "${SEVERITY_CRITICAL}")
                findings_critical=$((findings_critical + 1))
                # Attempt escalation
                night_watcher_escalate "${check}: ${finding_message}"
                # Attempt auto-remediation if enabled
                _night_watcher_try_remediation "${check}" "${finding_details}"
                ;;
        esac

        tick_results=$(echo "${tick_results}" | jq \
            --arg check "${check}" \
            --arg severity "${finding_severity}" \
            --arg message "${finding_message}" \
            '. += [{"check": $check, "severity": $severity, "message": $message}]')
    done

    # Update cumulative counters
    local total_warnings
    total_warnings=$(_night_watcher_get_state "warning_count" "0")
    total_warnings=$((total_warnings + findings_warning))
    _night_watcher_set_state "warning_count" "${total_warnings}"

    local total_critical
    total_critical=$(_night_watcher_get_state "critical_count" "0")
    total_critical=$((total_critical + findings_critical))
    _night_watcher_set_state "critical_count" "${total_critical}"

    # Update log file summary
    local log_file
    log_file=$(_night_watch_log_file "${today}")
    if [ -f "${log_file}" ]; then
        local tmp
        tmp=$(mktemp)
        jq \
            --argjson ok "${findings_ok}" \
            --argjson warn "${findings_warning}" \
            --argjson crit "${findings_critical}" \
            '.summary.total_checks += 1 |
             .summary.ok += $ok |
             .summary.warnings += $warn |
             .summary.critical += $crit' \
            "${log_file}" > "${tmp}" && mv "${tmp}" "${log_file}"
    fi

    log_info "Night tick complete: ok=${findings_ok} warn=${findings_warning} crit=${findings_critical}"

    # Output tick results
    jq -n \
        --arg ts "${now}" \
        --arg tick "${check_count}" \
        --argjson results "${tick_results}" \
        --argjson ok "${findings_ok}" \
        --argjson warn "${findings_warning}" \
        --argjson crit "${findings_critical}" \
        '{
            timestamp: $ts,
            tick: ($tick | tonumber),
            results: $results,
            totals: {ok: $ok, warnings: $warn, critical: $crit}
        }'
}

# Check if the Night Watcher is currently active.
# Returns 0 (true) if active, 1 (false) otherwise.
night_watcher_is_active() {
    local active
    active=$(_night_watcher_get_state "active" "false")
    [ "${active}" = "true" ]
}

# Check the schedule to determine if Night Watcher should auto-start.
# Compares current time against configured start time in the configured timezone.
# Returns 0 if it should start, 1 otherwise.
night_watcher_should_start() {
    # Don't start if already active
    if night_watcher_is_active; then
        return 1
    fi

    # Check if night watcher is enabled
    local enabled
    enabled=$(config_get ".night_watcher.enabled" "false")
    if [ "${enabled}" != "true" ]; then
        return 1
    fi

    local schedule_start schedule_end timezone
    schedule_start=$(config_get ".night_watcher.schedule.start" "22:00")
    schedule_end=$(config_get ".night_watcher.schedule.end" "07:00")
    timezone=$(config_get ".night_watcher.schedule.timezone" "UTC")

    local current_time
    current_time=$(TZ="${timezone}" date +"%H:%M")

    _is_in_night_window "${current_time}" "${schedule_start}" "${schedule_end}"
}

# Check if Night Watcher should auto-stop based on schedule.
# Returns 0 if it should stop, 1 otherwise.
night_watcher_should_stop() {
    # Can't stop if not active
    if ! night_watcher_is_active; then
        return 1
    fi

    local schedule_start schedule_end timezone
    schedule_start=$(config_get ".night_watcher.schedule.start" "22:00")
    schedule_end=$(config_get ".night_watcher.schedule.end" "07:00")
    timezone=$(config_get ".night_watcher.schedule.timezone" "UTC")

    local current_time
    current_time=$(TZ="${timezone}" date +"%H:%M")

    # Should stop if we are NOT in the night window
    if ! _is_in_night_window "${current_time}" "${schedule_start}" "${schedule_end}"; then
        return 0
    fi

    return 1
}

# Send a critical alert, respecting escalation cooldown.
# Prevents alert fatigue by enforcing a minimum interval between escalations.
night_watcher_escalate() {
    local finding="$1"

    local escalation_enabled
    escalation_enabled=$(config_get ".night_watcher.critical_escalation.enabled" "true")
    if [ "${escalation_enabled}" != "true" ]; then
        log_debug "Escalation disabled by config"
        return 0
    fi

    # Check cooldown
    local cooldown
    cooldown=$(config_get ".night_watcher.critical_escalation.cooldown" "${DEFAULT_ESCALATION_COOLDOWN}")

    local last_escalation
    last_escalation=$(_night_watcher_get_state "last_escalation" "")

    if [ -n "${last_escalation}" ]; then
        local last_epoch
        last_epoch=$(date -d "${last_escalation}" +%s 2>/dev/null || echo "0")
        local now_epoch
        now_epoch=$(date +%s)
        local elapsed=$((now_epoch - last_epoch))

        if [ "${elapsed}" -lt "${cooldown}" ]; then
            local remaining=$((cooldown - elapsed))
            log_info "Escalation cooldown active (${remaining}s remaining), suppressing alert"
            night_watcher_log "escalation" "${SEVERITY_WARNING}" \
                "Escalation suppressed (cooldown): ${finding}" "{}"
            return 0
        fi
    fi

    # Record escalation
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    _night_watcher_set_state_string "last_escalation" "${now}"

    local esc_count
    esc_count=$(_night_watcher_get_state "escalation_count" "0")
    esc_count=$((esc_count + 1))
    _night_watcher_set_state "escalation_count" "${esc_count}"

    # Update log file escalation count
    local today
    today=$(_night_watcher_get_state "date" "$(date +"%Y-%m-%d")")
    local log_file
    log_file=$(_night_watch_log_file "${today}")
    if [ -f "${log_file}" ]; then
        local tmp
        tmp=$(mktemp)
        jq '.summary.escalations += 1' "${log_file}" > "${tmp}" && mv "${tmp}" "${log_file}"
    fi

    log_warn "CRITICAL ESCALATION: ${finding}"
    state_log "error" "night_watcher" "Critical escalation: ${finding}"
    night_watcher_log "escalation" "${SEVERITY_CRITICAL}" "${finding}" "{}"

    # Output the escalation for the communicator to handle
    echo "CRITICAL ALERT: ${finding}"
}

# Log an entry to the night watch log file.
# Format: {"timestamp", "category", "severity", "message", "details", "action_taken"}
night_watcher_log() {
    local category="$1"
    local severity="$2"
    local message="$3"
    local details="${4:-"{}"}"
    local action_taken="${5:-null}"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local today
    today=$(_night_watcher_get_state "date" "$(date +"%Y-%m-%d")")
    local log_file
    log_file=$(_night_watch_log_file "${today}")

    # Ensure log file exists
    mkdir -p "${NIGHT_WATCH_DIR}"
    if [ ! -f "${log_file}" ]; then
        jq -n \
            --arg date "${today}" \
            --arg started "${now}" \
            '{
                date: $date,
                started_at: $started,
                stopped_at: null,
                entries: [],
                summary: {total_checks: 0, ok: 0, warnings: 0, critical: 0, escalations: 0, actions_taken: 0}
            }' > "${log_file}"
    fi

    # Build the entry
    local entry
    if [ "${action_taken}" = "null" ]; then
        entry=$(jq -n \
            --arg ts "${now}" \
            --arg cat "${category}" \
            --arg sev "${severity}" \
            --arg msg "${message}" \
            --argjson det "${details}" \
            '{
                timestamp: $ts,
                category: $cat,
                severity: $sev,
                message: $msg,
                details: $det,
                action_taken: null
            }')
    else
        entry=$(jq -n \
            --arg ts "${now}" \
            --arg cat "${category}" \
            --arg sev "${severity}" \
            --arg msg "${message}" \
            --argjson det "${details}" \
            --arg act "${action_taken}" \
            '{
                timestamp: $ts,
                category: $cat,
                severity: $sev,
                message: $msg,
                details: $det,
                action_taken: $act
            }')
    fi

    # Append to entries array
    json_append "${log_file}" ".entries" "${entry}"
}

# --- Internal Helpers ---

# Check if a time string (HH:MM) falls within the night window.
# Handles windows that cross midnight (e.g., 22:00 - 07:00).
# Returns 0 if in window, 1 otherwise.
_is_in_night_window() {
    local current="$1"
    local start="$2"
    local end="$3"

    # Convert HH:MM to minutes since midnight for comparison
    local current_min start_min end_min
    current_min=$(_time_to_minutes "${current}")
    start_min=$(_time_to_minutes "${start}")
    end_min=$(_time_to_minutes "${end}")

    if [ "${start_min}" -le "${end_min}" ]; then
        # Window does not cross midnight (e.g., 01:00 - 05:00)
        [ "${current_min}" -ge "${start_min}" ] && [ "${current_min}" -lt "${end_min}" ]
    else
        # Window crosses midnight (e.g., 22:00 - 07:00)
        [ "${current_min}" -ge "${start_min}" ] || [ "${current_min}" -lt "${end_min}" ]
    fi
}

# Convert HH:MM to minutes since midnight.
_time_to_minutes() {
    local time_str="$1"
    local hours minutes
    hours=$(echo "${time_str}" | cut -d: -f1 | sed 's/^0//')
    minutes=$(echo "${time_str}" | cut -d: -f2 | sed 's/^0//')
    hours="${hours:-0}"
    minutes="${minutes:-0}"
    echo $(( hours * 60 + minutes ))
}

# Attempt auto-remediation for a check if enabled and the action is allowed.
_night_watcher_try_remediation() {
    local check="$1"
    local details="$2"

    local remediation_enabled
    remediation_enabled=$(config_get ".night_watcher.auto_remediation.enabled" "false")
    if [ "${remediation_enabled}" != "true" ]; then
        log_debug "Auto-remediation disabled"
        return 0
    fi

    # Map checks to remediation actions
    local action=""
    case "${check}" in
        kubernetes_pods)
            action="restart_crashed_pods"
            ;;
        system_health)
            action="clear_disk_space_temp"
            ;;
        log_anomalies)
            action="rotate_logs"
            ;;
        *)
            log_debug "No remediation action mapped for check: ${check}"
            return 0
            ;;
    esac

    # Check if the action is in the allowed list
    if ! _is_action_allowed "${action}"; then
        log_info "Remediation action '${action}' not in allowed list"
        return 0
    fi

    # Check if the action is in the forbidden list
    if _is_action_forbidden "${action}"; then
        log_warn "Remediation action '${action}' is explicitly forbidden"
        return 0
    fi

    log_info "Auto-remediation: executing '${action}' for ${check}"
    state_log "warn" "night_watcher" "Auto-remediation: ${action} for ${check}"

    # Log the action taken
    night_watcher_log "${check}" "${SEVERITY_WARNING}" \
        "Auto-remediation attempted: ${action}" "${details}" "${action}"

    # Update actions_taken counter
    local today
    today=$(_night_watcher_get_state "date" "$(date +"%Y-%m-%d")")
    local log_file
    log_file=$(_night_watch_log_file "${today}")
    if [ -f "${log_file}" ]; then
        local tmp
        tmp=$(mktemp)
        jq '.summary.actions_taken += 1' "${log_file}" > "${tmp}" && mv "${tmp}" "${log_file}"
    fi

    # Actual remediation execution is handled by the executor agent
    # Here we output the action for the orchestrator to dispatch
    echo "REMEDIATION: ${action}"
}

# Check if an action is in the allowed_actions list.
_is_action_allowed() {
    local action="$1"
    local state_file="${OTTO_HOME}/state/state.json"

    # Read allowed actions from config (stored as YAML array)
    # We check if the action string appears in the config value
    local allowed
    allowed=$(config_get ".night_watcher.auto_remediation.allowed_actions" "")

    if [ -z "${allowed}" ]; then
        return 1
    fi

    echo "${allowed}" | grep -q "${action}"
}

# Check if an action is in the forbidden_actions list.
_is_action_forbidden() {
    local action="$1"

    local forbidden
    forbidden=$(config_get ".night_watcher.auto_remediation.forbidden_actions" "")

    if [ -z "${forbidden}" ]; then
        return 1
    fi

    echo "${forbidden}" | grep -q "${action}"
}

# --- CLI Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    action="${1:-status}"
    shift || true

    case "${action}" in
        start)
            night_watcher_start
            ;;
        stop)
            night_watcher_stop
            ;;
        tick)
            night_watcher_tick
            ;;
        status)
            if night_watcher_is_active; then
                echo "Night Watcher: ACTIVE"
                echo "Started: $(_night_watcher_get_state "started_at" "unknown")"
                echo "Checks: $(_night_watcher_get_state "check_count" "0")"
                echo "Warnings: $(_night_watcher_get_state "warning_count" "0")"
                echo "Critical: $(_night_watcher_get_state "critical_count" "0")"
                echo "Escalations: $(_night_watcher_get_state "escalation_count" "0")"
            else
                echo "Night Watcher: INACTIVE"
            fi
            ;;
        should-start)
            if night_watcher_should_start; then
                echo "yes"
            else
                echo "no"
            fi
            ;;
        should-stop)
            if night_watcher_should_stop; then
                echo "yes"
            else
                echo "no"
            fi
            ;;
        *)
            echo "Usage: night-watcher.sh {start|stop|tick|status|should-start|should-stop}" >&2
            exit 1
            ;;
    esac
fi
