#!/usr/bin/env bash
set -euo pipefail

# OTTO - Adaptive heartbeat/loop management
# Manages OTTO's periodic execution cycle with adaptive intervals.
# Integrates with Claude Code's /loop mechanism.

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

# --- Constants (guarded against re-source) ---

if [[ -z "${_OTTO_HEARTBEAT_LOADED:-}" ]]; then
_OTTO_HEARTBEAT_LOADED=1

readonly HEARTBEAT_MODE_ACTIVE="active"
readonly HEARTBEAT_MODE_NORMAL="normal"
readonly HEARTBEAT_MODE_IDLE="idle"
readonly HEARTBEAT_MODE_TURBO="turbo"
readonly HEARTBEAT_MODE_NIGHT="night"

# Default intervals in seconds
readonly HEARTBEAT_INTERVAL_ACTIVE=300    # 5 minutes
readonly HEARTBEAT_INTERVAL_NORMAL=600    # 10 minutes
readonly HEARTBEAT_INTERVAL_IDLE=1800     # 30 minutes
readonly HEARTBEAT_INTERVAL_MAX_IDLE=3600 # 60 minutes
readonly HEARTBEAT_INTERVAL_TURBO=60      # 1 minute
readonly HEARTBEAT_TURBO_DURATION=1800    # 30 minutes

# Idle threshold: no user activity for 30 minutes triggers idle mode
readonly HEARTBEAT_IDLE_THRESHOLD=1800

# Check frequency tiers (run every N ticks)
readonly CHECK_TIER_EVERY=1
readonly CHECK_TIER_LOW=3
readonly CHECK_TIER_MEDIUM=6
readonly CHECK_TIER_HIGH=12

# State file path
readonly HEARTBEAT_STATE_KEY=".heartbeat"

fi  # _OTTO_HEARTBEAT_LOADED

# --- Check Frequency Matrix ---

# Returns the tick frequency for a given check name.
# Every tick (1): monitoring_alerts, communication_inbox
# Every 3 ticks:  cicd_pipelines, kubernetes_pods
# Every 6 ticks:  system_health, database_health, security_events
# Every 12 ticks: ssl_certificates, backup_status, cost_analysis
_heartbeat_check_frequency() {
    local check_name="$1"

    case "${check_name}" in
        monitoring_alerts|communication_inbox)
            echo "${CHECK_TIER_EVERY}"
            ;;
        cicd_pipelines|kubernetes_pods)
            echo "${CHECK_TIER_LOW}"
            ;;
        system_health|database_health|security_events)
            echo "${CHECK_TIER_MEDIUM}"
            ;;
        ssl_certificates|backup_status|cost_analysis)
            echo "${CHECK_TIER_HIGH}"
            ;;
        *)
            # Unknown checks default to medium frequency
            log_debug "Unknown check '${check_name}', defaulting to tier ${CHECK_TIER_MEDIUM}"
            echo "${CHECK_TIER_MEDIUM}"
            ;;
    esac
}

# --- State Helpers ---

_heartbeat_state_file() {
    echo "${OTTO_HOME}/state/state.json"
}

_heartbeat_get_state() {
    local key="$1"
    local default="${2:-}"
    local state_file
    state_file=$(_heartbeat_state_file)

    json_get "${state_file}" "${HEARTBEAT_STATE_KEY}.${key}" "${default}"
}

_heartbeat_set_state() {
    local key="$1"
    local value="$2"
    local state_file
    state_file=$(_heartbeat_state_file)

    json_set "${state_file}" "${HEARTBEAT_STATE_KEY}.${key}" "${value}"
}

_heartbeat_set_state_string() {
    local key="$1"
    local value="$2"
    local state_file
    state_file=$(_heartbeat_state_file)

    json_set_string "${state_file}" "${HEARTBEAT_STATE_KEY}.${key}" "${value}"
}

# --- Public Functions ---

# Initialize heartbeat state.
# Sets default values for last_tick, tick_count, mode, and turbo fields.
heartbeat_init() {
    local state_file
    state_file=$(_heartbeat_state_file)

    # Ensure state directory and file exist
    mkdir -p "$(dirname "${state_file}")"
    if [ ! -f "${state_file}" ]; then
        echo '{}' > "${state_file}"
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    _heartbeat_set_state_string "last_tick" "${now}"
    _heartbeat_set_state "tick_count" "0"
    _heartbeat_set_state_string "mode" "${HEARTBEAT_MODE_NORMAL}"
    _heartbeat_set_state_string "turbo_started" ""
    _heartbeat_set_state_string "last_user_activity" "${now}"
    _heartbeat_set_state_string "initialized_at" "${now}"

    log_info "Heartbeat initialized (mode=${HEARTBEAT_MODE_NORMAL})"
}

# Execute one heartbeat cycle.
# 1. Records tick timestamp
# 2. Determines what needs checking based on elapsed time
# 3. Runs configured checks (those due this tick)
# 4. Collects results from all checks
# 5. Decides next interval based on activity
# Outputs a JSON summary of the tick results.
heartbeat_tick() {
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local now_epoch
    now_epoch=$(date +%s)

    # Increment tick count
    local tick_count
    tick_count=$(_heartbeat_get_state "tick_count" "0")
    tick_count=$((tick_count + 1))

    # Record this tick
    _heartbeat_set_state_string "last_tick" "${now}"
    _heartbeat_set_state "tick_count" "${tick_count}"

    log_info "Heartbeat tick #${tick_count} at ${now}"

    # Auto-expire turbo mode
    _heartbeat_check_turbo_expiry "${now_epoch}"

    # Auto-detect idle mode based on last user activity
    _heartbeat_auto_detect_mode "${now_epoch}"

    local mode
    mode=$(heartbeat_get_mode)
    log_debug "Current mode: ${mode}, tick: ${tick_count}"

    # Determine which checks should run this tick
    local checks_to_run=()
    local all_checks=(
        "monitoring_alerts"
        "communication_inbox"
        "cicd_pipelines"
        "kubernetes_pods"
        "system_health"
        "database_health"
        "security_events"
        "ssl_certificates"
        "backup_status"
        "cost_analysis"
    )

    for check in "${all_checks[@]}"; do
        if heartbeat_should_check "${check}"; then
            checks_to_run+=("${check}")
        fi
    done

    # Log which checks are running
    if [ ${#checks_to_run[@]} -gt 0 ]; then
        log_info "Running checks: ${checks_to_run[*]}"
    else
        log_debug "No checks due this tick"
    fi

    # Calculate next interval
    local next_interval
    next_interval=$(heartbeat_get_interval)

    # Build result JSON
    local checks_json="[]"
    for check in "${checks_to_run[@]}"; do
        checks_json=$(echo "${checks_json}" | jq --arg c "${check}" '. += [$c]')
    done

    local result
    result=$(jq -n \
        --arg tick "${tick_count}" \
        --arg ts "${now}" \
        --arg mode "${mode}" \
        --arg interval "${next_interval}" \
        --argjson checks "${checks_json}" \
        '{
            tick: ($tick | tonumber),
            timestamp: $ts,
            mode: $mode,
            next_interval_seconds: ($interval | tonumber),
            checks_run: $checks
        }')

    # Store last tick result
    local state_file
    state_file=$(_heartbeat_state_file)
    json_set "${state_file}" "${HEARTBEAT_STATE_KEY}.last_tick_result" "${result}"

    echo "${result}"
}

# Calculate next interval based on adaptive logic.
# Returns interval in seconds.
heartbeat_get_interval() {
    local mode
    mode=$(heartbeat_get_mode)

    # Read configured overrides (fall back to constants)
    local interval_active interval_normal interval_idle interval_max_idle
    local interval_turbo
    interval_active=$(config_get ".heartbeat.min_interval" "${HEARTBEAT_INTERVAL_ACTIVE}")
    interval_normal=$(config_get ".heartbeat.interval" "${HEARTBEAT_INTERVAL_NORMAL}")
    interval_idle="${HEARTBEAT_INTERVAL_IDLE}"
    interval_max_idle=$(config_get ".heartbeat.max_interval" "${HEARTBEAT_INTERVAL_MAX_IDLE}")
    interval_turbo=$(config_get ".heartbeat.turbo_interval" "${HEARTBEAT_INTERVAL_TURBO}")

    case "${mode}" in
        "${HEARTBEAT_MODE_ACTIVE}")
            echo "${interval_active}"
            ;;
        "${HEARTBEAT_MODE_NORMAL}")
            echo "${interval_normal}"
            ;;
        "${HEARTBEAT_MODE_IDLE}")
            # Check how long we've been idle for progressive backoff
            local last_activity_str
            last_activity_str=$(_heartbeat_get_state "last_user_activity" "")
            if [ -n "${last_activity_str}" ]; then
                local last_epoch
                last_epoch=$(date -d "${last_activity_str}" +%s 2>/dev/null || echo "0")
                local now_epoch
                now_epoch=$(date +%s)
                local idle_seconds=$((now_epoch - last_epoch))

                # Progressive: after 1 hour idle, go to max_idle interval
                if [ "${idle_seconds}" -gt 3600 ]; then
                    echo "${interval_max_idle}"
                    return 0
                fi
            fi
            echo "${interval_idle}"
            ;;
        "${HEARTBEAT_MODE_TURBO}")
            echo "${interval_turbo}"
            ;;
        "${HEARTBEAT_MODE_NIGHT}")
            local night_interval
            night_interval=$(config_get ".night_watcher.heartbeat_interval" "900")
            echo "${night_interval}"
            ;;
        *)
            log_warn "Unknown heartbeat mode '${mode}', using normal interval"
            echo "${interval_normal}"
            ;;
    esac
}

# Set heartbeat mode.
# Valid modes: active, normal, idle, turbo, night
heartbeat_set_mode() {
    local mode="$1"

    # Validate mode
    case "${mode}" in
        "${HEARTBEAT_MODE_ACTIVE}"|"${HEARTBEAT_MODE_NORMAL}"|"${HEARTBEAT_MODE_IDLE}"|\
        "${HEARTBEAT_MODE_TURBO}"|"${HEARTBEAT_MODE_NIGHT}")
            ;;
        *)
            log_error "Invalid heartbeat mode: ${mode}"
            return 1
            ;;
    esac

    local previous
    previous=$(heartbeat_get_mode)

    _heartbeat_set_state_string "mode" "${mode}"
    _heartbeat_set_state_string "mode_changed_at" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    if [ "${previous}" != "${mode}" ]; then
        log_info "Heartbeat mode changed: ${previous} -> ${mode}"
        state_log "info" "heartbeat" "Mode change: ${previous} -> ${mode}"
    fi
}

# Get current heartbeat mode.
heartbeat_get_mode() {
    _heartbeat_get_state "mode" "${HEARTBEAT_MODE_NORMAL}"
}

# Enable turbo mode for a configured duration (default 30 minutes).
# Turbo mode polls every 60 seconds for rapid feedback loops.
heartbeat_turbo_start() {
    local now_epoch
    now_epoch=$(date +%s)

    _heartbeat_set_state_string "turbo_started" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    _heartbeat_set_state "turbo_started_epoch" "${now_epoch}"

    heartbeat_set_mode "${HEARTBEAT_MODE_TURBO}"

    local duration
    duration=$(config_get ".heartbeat.turbo_duration" "${HEARTBEAT_TURBO_DURATION}")
    local duration_min=$((duration / 60))

    log_info "Turbo mode activated for ${duration_min} minutes (interval: ${HEARTBEAT_INTERVAL_TURBO}s)"
    state_log "info" "heartbeat" "Turbo mode activated for ${duration_min} minutes"
}

# Disable turbo mode and return to normal mode.
heartbeat_turbo_stop() {
    local was_turbo
    was_turbo=$(heartbeat_get_mode)

    _heartbeat_set_state_string "turbo_started" ""

    if [ "${was_turbo}" = "${HEARTBEAT_MODE_TURBO}" ]; then
        heartbeat_set_mode "${HEARTBEAT_MODE_NORMAL}"
        log_info "Turbo mode deactivated"
        state_log "info" "heartbeat" "Turbo mode deactivated"
    fi
}

# Determine whether a specific check should run this tick.
# Not all checks run every tick; frequency is based on the check matrix.
# Returns 0 (true) if the check should run, 1 (false) otherwise.
heartbeat_should_check() {
    local check_name="$1"

    local tick_count
    tick_count=$(_heartbeat_get_state "tick_count" "0")

    # On tick 0 (or uninitialized), run nothing
    if [ "${tick_count}" -eq 0 ]; then
        return 1
    fi

    local frequency
    frequency=$(_heartbeat_check_frequency "${check_name}")

    # In turbo mode, run all checks every tick
    local mode
    mode=$(heartbeat_get_mode)
    if [ "${mode}" = "${HEARTBEAT_MODE_TURBO}" ]; then
        return 0
    fi

    # In night mode, run all checks every tick (night watcher handles its own filtering)
    if [ "${mode}" = "${HEARTBEAT_MODE_NIGHT}" ]; then
        return 0
    fi

    # Check if this tick is a multiple of the check's frequency
    if [ $((tick_count % frequency)) -eq 0 ]; then
        return 0
    fi

    return 1
}

# Return a JSON summary of the current heartbeat state.
heartbeat_summary() {
    local mode tick_count last_tick interval
    local turbo_started last_activity initialized_at

    mode=$(heartbeat_get_mode)
    tick_count=$(_heartbeat_get_state "tick_count" "0")
    last_tick=$(_heartbeat_get_state "last_tick" "never")
    interval=$(heartbeat_get_interval)
    turbo_started=$(_heartbeat_get_state "turbo_started" "")
    last_activity=$(_heartbeat_get_state "last_user_activity" "")
    initialized_at=$(_heartbeat_get_state "initialized_at" "")

    local turbo_remaining=""
    if [ -n "${turbo_started}" ] && [ "${mode}" = "${HEARTBEAT_MODE_TURBO}" ]; then
        local turbo_epoch
        turbo_epoch=$(date -d "${turbo_started}" +%s 2>/dev/null || echo "0")
        local now_epoch
        now_epoch=$(date +%s)
        local duration
        duration=$(config_get ".heartbeat.turbo_duration" "${HEARTBEAT_TURBO_DURATION}")
        local elapsed=$((now_epoch - turbo_epoch))
        local remaining=$((duration - elapsed))
        if [ "${remaining}" -gt 0 ]; then
            turbo_remaining="${remaining}"
        fi
    fi

    jq -n \
        --arg mode "${mode}" \
        --arg tick_count "${tick_count}" \
        --arg last_tick "${last_tick}" \
        --arg interval "${interval}" \
        --arg turbo_started "${turbo_started}" \
        --arg turbo_remaining "${turbo_remaining}" \
        --arg last_activity "${last_activity}" \
        --arg initialized_at "${initialized_at}" \
        '{
            mode: $mode,
            tick_count: ($tick_count | tonumber),
            last_tick: $last_tick,
            next_interval_seconds: ($interval | tonumber),
            turbo_started: (if $turbo_started == "" then null else $turbo_started end),
            turbo_remaining_seconds: (if $turbo_remaining == "" then null else ($turbo_remaining | tonumber) end),
            last_user_activity: (if $last_activity == "" then null else $last_activity end),
            initialized_at: (if $initialized_at == "" then null else $initialized_at end)
        }'
}

# Record user activity (resets idle detection).
# Should be called by the orchestrator when user interaction is detected.
heartbeat_record_activity() {
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    _heartbeat_set_state_string "last_user_activity" "${now}"

    # If we were idle, switch back to active
    local mode
    mode=$(heartbeat_get_mode)
    if [ "${mode}" = "${HEARTBEAT_MODE_IDLE}" ]; then
        heartbeat_set_mode "${HEARTBEAT_MODE_ACTIVE}"
    fi
}

# --- Internal Helpers ---

# Check if turbo mode has expired and auto-disable it.
_heartbeat_check_turbo_expiry() {
    local now_epoch="$1"

    local mode
    mode=$(heartbeat_get_mode)
    if [ "${mode}" != "${HEARTBEAT_MODE_TURBO}" ]; then
        return 0
    fi

    local turbo_started
    turbo_started=$(_heartbeat_get_state "turbo_started" "")
    if [ -z "${turbo_started}" ]; then
        # Turbo mode set but no start time -- force stop
        heartbeat_turbo_stop
        return 0
    fi

    local turbo_epoch
    turbo_epoch=$(date -d "${turbo_started}" +%s 2>/dev/null || echo "0")
    local duration
    duration=$(config_get ".heartbeat.turbo_duration" "${HEARTBEAT_TURBO_DURATION}")

    local elapsed=$((now_epoch - turbo_epoch))
    if [ "${elapsed}" -ge "${duration}" ]; then
        log_info "Turbo mode expired after ${duration}s"
        heartbeat_turbo_stop
    fi
}

# Auto-detect whether we should switch to idle mode
# based on time since last user activity.
_heartbeat_auto_detect_mode() {
    local now_epoch="$1"

    local mode
    mode=$(heartbeat_get_mode)

    # Don't override turbo or night mode
    if [ "${mode}" = "${HEARTBEAT_MODE_TURBO}" ] || [ "${mode}" = "${HEARTBEAT_MODE_NIGHT}" ]; then
        return 0
    fi

    local adaptive
    adaptive=$(config_get ".heartbeat.adaptive" "true")
    if [ "${adaptive}" != "true" ]; then
        return 0
    fi

    local last_activity_str
    last_activity_str=$(_heartbeat_get_state "last_user_activity" "")
    if [ -z "${last_activity_str}" ]; then
        return 0
    fi

    local last_epoch
    last_epoch=$(date -d "${last_activity_str}" +%s 2>/dev/null || echo "0")
    local idle_seconds=$((now_epoch - last_epoch))

    if [ "${idle_seconds}" -ge "${HEARTBEAT_IDLE_THRESHOLD}" ] && [ "${mode}" != "${HEARTBEAT_MODE_IDLE}" ]; then
        heartbeat_set_mode "${HEARTBEAT_MODE_IDLE}"
    elif [ "${idle_seconds}" -lt "${HEARTBEAT_IDLE_THRESHOLD}" ] && [ "${mode}" = "${HEARTBEAT_MODE_IDLE}" ]; then
        heartbeat_set_mode "${HEARTBEAT_MODE_ACTIVE}"
    fi
}

# --- CLI Entry Point ---
# When run directly, supports: init, tick, status, mode, turbo-start, turbo-stop
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    action="${1:-status}"
    shift || true

    case "${action}" in
        init)
            heartbeat_init
            ;;
        tick)
            heartbeat_tick
            ;;
        status|summary)
            heartbeat_summary
            ;;
        mode)
            if [ $# -ge 1 ]; then
                heartbeat_set_mode "$1"
            else
                heartbeat_get_mode
            fi
            ;;
        interval)
            heartbeat_get_interval
            ;;
        turbo-start|turbo)
            heartbeat_turbo_start
            ;;
        turbo-stop)
            heartbeat_turbo_stop
            ;;
        activity)
            heartbeat_record_activity
            ;;
        *)
            echo "Usage: heartbeat.sh {init|tick|status|mode [MODE]|interval|turbo-start|turbo-stop|activity}" >&2
            exit 1
            ;;
    esac
fi
