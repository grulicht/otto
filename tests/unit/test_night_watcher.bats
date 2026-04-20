#!/usr/bin/env bats
# OTTO - Night Watcher unit tests (logic-only, no integration)

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
    source "${OTTO_DIR}/scripts/lib/error-handling.sh"
    source "${OTTO_DIR}/scripts/core/config.sh"
    source "${OTTO_DIR}/scripts/core/state.sh"
    source "${OTTO_DIR}/scripts/core/heartbeat.sh"
    source "${OTTO_DIR}/scripts/core/morning-report.sh"
    source "${OTTO_DIR}/scripts/core/night-watcher.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "night_watcher_is_active returns false when not started" {
    run night_watcher_is_active
    [ "$status" -ne 0 ]
}

@test "night_watcher_log writes entry to daily log file" {
    # Set up state so log knows the date
    local today
    today=$(date +"%Y-%m-%d")
    mkdir -p "${OTTO_HOME}/state/night-watch"

    # Write a date into state for the log function
    json_set_string "${OTTO_HOME}/state/state.json" ".night_watcher.date" "${today}"

    run night_watcher_log "test_category" "ok" "test message" "{}"
    [ "$status" -eq 0 ]

    local log_file="${OTTO_HOME}/state/night-watch/${today}.json"
    [ -f "${log_file}" ]

    local entry_count
    entry_count=$(jq '.entries | length' "${log_file}")
    [ "$entry_count" -ge 1 ]

    local cat
    cat=$(jq -r '.entries[0].category' "${log_file}")
    [ "$cat" = "test_category" ]
}

@test "_is_in_night_window detects time inside window crossing midnight" {
    run _is_in_night_window "23:30" "22:00" "07:00"
    [ "$status" -eq 0 ]
}

@test "_is_in_night_window detects time outside window crossing midnight" {
    run _is_in_night_window "12:00" "22:00" "07:00"
    [ "$status" -ne 0 ]
}

@test "_time_to_minutes converts HH:MM correctly" {
    run _time_to_minutes "02:30"
    [ "$status" -eq 0 ]
    [ "$output" = "150" ]
}
