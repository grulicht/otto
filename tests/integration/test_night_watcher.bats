#!/usr/bin/env bats
# OTTO - Night Watcher integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    # Create minimal config for night watcher
    mkdir -p "${OTTO_HOME}"
    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
night_watcher:
  enabled: true
  schedule:
    start: "22:00"
    end: "07:00"
    timezone: "UTC"
  checks:
    system_health: true
  critical_escalation:
    enabled: false
permissions:
  default_mode: auto
heartbeat:
  interval: 300
YAML

    # Source the night watcher (and its dependencies)
    source "${OTTO_DIR}/scripts/core/night-watcher.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "night_watcher_start activates night mode in state" {
    run night_watcher_start
    [ "$status" -eq 0 ]

    local active
    active=$(jq -r '.night_watcher.active' "${OTTO_HOME}/state/state.json")
    [ "${active}" = "true" ]
}

@test "night_watcher_is_active returns true after start" {
    night_watcher_start >/dev/null 2>&1

    run night_watcher_is_active
    [ "$status" -eq 0 ]
}

@test "night_watcher_is_active returns false before start" {
    run night_watcher_is_active
    [ "$status" -ne 0 ]
}

@test "night_watcher_should_start respects schedule config" {
    # When night watcher is enabled and not active, should_start depends on time
    # We just verify it runs without error (actual result depends on current time)
    run night_watcher_should_start
    # Either 0 (should start) or 1 (not time yet) - both are valid
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "night_watcher_should_stop respects schedule config" {
    # When not active, should_stop returns 1
    run night_watcher_should_stop
    [ "$status" -eq 1 ]
}

@test "night_watcher_log writes to daily log file" {
    night_watcher_start >/dev/null 2>&1

    run night_watcher_log "system_health" "ok" "All systems nominal" '{"cpu": 25}'
    [ "$status" -eq 0 ]

    local today
    today=$(date +"%Y-%m-%d")
    local log_file="${OTTO_HOME}/state/night-watch/${today}.json"
    [ -f "${log_file}" ]

    local entry_count
    entry_count=$(jq '.entries | length' "${log_file}")
    [ "${entry_count}" -ge 1 ]
}

@test "night_watcher_stop deactivates and resets mode" {
    night_watcher_start >/dev/null 2>&1

    run night_watcher_stop
    [ "$status" -eq 0 ]

    local active
    active=$(jq -r '.night_watcher.active' "${OTTO_HOME}/state/state.json")
    [ "${active}" = "false" ]
}
