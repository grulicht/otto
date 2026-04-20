#!/usr/bin/env bats
# OTTO - CLI integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "otto help exits 0" {
    run "${OTTO_DIR}/otto" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"OTTO"* ]]
}

@test "otto help shows available commands" {
    run "${OTTO_DIR}/otto" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"check"* ]]
}

@test "otto version outputs version string" {
    run "${OTTO_DIR}/otto" version
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "otto with no arguments shows help" {
    run "${OTTO_DIR}/otto"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OTTO"* ]]
}

@test "otto agents lists agents" {
    run "${OTTO_DIR}/otto" agents
    [ "$status" -eq 0 ]
    [[ "$output" == *"agent"* ]] || [[ "$output" == *"Agent"* ]] || [[ "$output" == *"orchestrator"* ]]
}

@test "otto detect runs tool detection" {
    run "${OTTO_DIR}/otto" detect
    [ "$status" -eq 0 ]
}

@test "otto config shows configuration" {
    run "${OTTO_DIR}/otto" config
    [ "$status" -eq 0 ]
}
