#!/usr/bin/env bats
# OTTO - State management tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/error-handling.sh"
    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
    source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"
    source "${OTTO_DIR}/scripts/core/config.sh"
    source "${OTTO_DIR}/scripts/core/state.sh"

    config_init 2>/dev/null
    state_init 2>/dev/null
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "state_init creates directory structure" {
    [ -d "${OTTO_HOME}/state" ]
    [ -d "${OTTO_HOME}/state/tasks/triage" ]
    [ -d "${OTTO_HOME}/state/tasks/todo" ]
    [ -d "${OTTO_HOME}/state/tasks/in-progress" ]
    [ -d "${OTTO_HOME}/state/tasks/done" ]
    [ -f "${OTTO_HOME}/state/state.json" ]
}

@test "state_set and state_get work" {
    state_set ".test_key" '"hello"' 2>/dev/null
    run state_get ".test_key" ""
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "state_log appends to log file" {
    state_log "info" "test" "test message" 2>/dev/null
    [ -f "${OTTO_HOME}/state/log.jsonl" ]
    local count
    count=$(wc -l < "${OTTO_HOME}/state/log.jsonl")
    [ "$count" -ge 1 ]
}

@test "task_create creates task file" {
    local task_id
    task_id=$(task_create "Test task" "Description" "high" "orchestrator" 2>/dev/null)
    [ -n "$task_id" ]
    [ -f "${OTTO_HOME}/state/tasks/triage/${task_id}.md" ]
}

@test "task_move moves task between directories" {
    local task_id
    task_id=$(task_create "Move test" "" "medium" "planner" 2>/dev/null)
    task_move "${task_id}" "triage" "todo" 2>/dev/null
    [ ! -f "${OTTO_HOME}/state/tasks/triage/${task_id}.md" ]
    [ -f "${OTTO_HOME}/state/tasks/todo/${task_id}.md" ]
}
