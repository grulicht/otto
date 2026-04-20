#!/usr/bin/env bats
# OTTO - Scheduler integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
YAML

    source "${OTTO_DIR}/scripts/core/scheduler.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "scheduler_add + scheduler_list roundtrip" {
    run scheduler_add "test-check" "*/5 * * * *" "server-health"
    [ "$status" -eq 0 ]

    run scheduler_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-check"* ]]
}

@test "scheduler_remove actually removes" {
    scheduler_add "remove-me" "0 * * * *" "server-health" >/dev/null 2>&1

    # Verify it exists
    local exists
    exists=$(jq -r '.checks[] | select(.name == "remove-me") | .name' "${OTTO_HOME}/state/scheduler.json")
    [ "${exists}" = "remove-me" ]

    # Remove it
    run scheduler_remove "remove-me"
    [ "$status" -eq 0 ]

    # Verify it's gone
    exists=$(jq -r '.checks[] | select(.name == "remove-me") | .name' "${OTTO_HOME}/state/scheduler.json" 2>/dev/null || echo "")
    [ -z "${exists}" ]
}

@test "scheduler_check_due with matching cron" {
    # Add a check with "every minute" cron
    scheduler_add "always-due" "* * * * *" "server-health" >/dev/null 2>&1

    run scheduler_check_due
    [ "$status" -eq 0 ]
    [[ "$output" == *"always-due"* ]]
}

@test "scheduler_run_due executes the check" {
    scheduler_add "run-me" "* * * * *" "server-health" >/dev/null 2>&1

    run scheduler_run_due
    [ "$status" -eq 0 ]

    # Verify last_run was updated
    local last_run
    last_run=$(jq -r '.checks[] | select(.name == "run-me") | .last_run' "${OTTO_HOME}/state/scheduler.json")
    [ "${last_run}" != "" ]
    [ "${last_run}" != "null" ]
}
