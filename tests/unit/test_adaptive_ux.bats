#!/usr/bin/env bats
# OTTO - Adaptive UX tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_ROOT="${OTTO_DIR}"
    export OTTO_HOME="$(mktemp -d)"
    export HOME="${OTTO_HOME}"

    # Override UX state paths to use temp dir
    export UX_CONFIG_DIR="${OTTO_HOME}/.config/otto"
    export UX_STATE_FILE="${UX_CONFIG_DIR}/ux-state.json"
    export UX_HISTORY_FILE="${UX_CONFIG_DIR}/interaction-history.log"

    source "${OTTO_DIR}/scripts/core/adaptive-ux.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "ux_get_level returns valid level" {
    run ux_get_level
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(beginner|intermediate|advanced|expert)$ ]]
}

@test "ux_should_explain returns true for beginner" {
    ux_set_level "beginner" > /dev/null
    run ux_should_explain
    [ "$status" -eq 0 ]
}

@test "ux_should_explain returns false for expert" {
    ux_set_level "expert" > /dev/null
    run ux_should_explain
    [ "$status" -ne 0 ]
}

@test "ux_detect_level runs without error" {
    run ux_detect_level
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(beginner|intermediate|advanced|expert)$ ]]
}

@test "ux_set_level rejects invalid level" {
    run ux_set_level "superuser"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid level"* ]]
}
