#!/usr/bin/env bats
# OTTO - Scheduler tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"

    source "${OTTO_DIR}/scripts/core/scheduler.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "scheduler_add creates a scheduled check entry" {
    scheduler_add "ssl-check" "0 9 * * 1" "ssl-certs"
    [ -f "${OTTO_HOME}/state/scheduler.json" ]

    run jq -r '.checks[0].name' "${OTTO_HOME}/state/scheduler.json"
    [ "$output" = "ssl-check" ]
}

@test "scheduler_add stores cron expression correctly" {
    scheduler_add "disk-check" "*/30 * * * *" "server-health"

    run jq -r '.checks[0].cron' "${OTTO_HOME}/state/scheduler.json"
    [ "$output" = "*/30 * * * *" ]
}

@test "scheduler_add rejects duplicate names" {
    scheduler_add "my-check" "0 * * * *" "test-cmd"
    run scheduler_add "my-check" "0 * * * *" "another-cmd"
    [ "$status" -ne 0 ]
}

@test "scheduler_add fails with missing arguments" {
    run scheduler_add "" "" ""
    [ "$status" -ne 0 ]
}

@test "scheduler_list shows added check" {
    scheduler_add "backup-verify" "0 6 * * *" "backup-status"
    run scheduler_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"backup-verify"* ]]
}

@test "scheduler_list shows empty message when no checks" {
    run scheduler_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No scheduled"* ]] || [[ "$output" == *"check"* ]]
}

@test "scheduler_remove deletes a check" {
    scheduler_add "temp-check" "0 * * * *" "test-cmd"

    # Verify it was added
    run jq '.checks | length' "${OTTO_HOME}/state/scheduler.json"
    [ "$output" = "1" ]

    scheduler_remove "temp-check"

    run jq '.checks | length' "${OTTO_HOME}/state/scheduler.json"
    [ "$output" = "0" ]
}

@test "scheduler_add multiple checks creates multiple entries" {
    scheduler_add "check-a" "0 * * * *" "cmd-a"
    scheduler_add "check-b" "30 * * * *" "cmd-b"

    run jq '.checks | length' "${OTTO_HOME}/state/scheduler.json"
    [ "$output" = "2" ]
}
