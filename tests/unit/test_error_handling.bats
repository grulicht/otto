#!/usr/bin/env bats
# OTTO - Error handling tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/error-handling.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "otto_require_command succeeds for bash" {
    run otto_require_command bash
    [ "$status" -eq 0 ]
}

@test "otto_require_command fails for nonexistent tool" {
    run otto_require_command nonexistent_tool_xyz
    [ "$status" -ne 0 ]
}

@test "otto_require_command shows install hint on failure" {
    run otto_require_command nonexistent_tool_xyz "apt install nonexistent"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nonexistent_tool_xyz"* ]]
}

@test "otto_run_or_default returns output on success" {
    run otto_run_or_default "fallback" echo "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "otto_run_or_default returns default on failure" {
    run otto_run_or_default "fallback" false
    [ "$status" -eq 0 ]
    [ "$output" = "fallback" ]
}
