#!/usr/bin/env bats
# OTTO - Heartbeat tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    # Create minimal config so config_load works
    mkdir -p "${OTTO_HOME}"
    cp "${OTTO_DIR}/config/default.yaml" "${OTTO_HOME}/config.yaml" 2>/dev/null || true

    source "${OTTO_DIR}/scripts/core/heartbeat.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "heartbeat_init creates state file" {
    heartbeat_init
    [ -f "${OTTO_HOME}/state/state.json" ]
}

@test "heartbeat_init sets mode to normal" {
    heartbeat_init
    run heartbeat_get_mode
    [ "$status" -eq 0 ]
    [ "$output" = "normal" ]
}

@test "heartbeat_get_mode returns valid mode" {
    heartbeat_init
    run heartbeat_get_mode
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(active|normal|idle|turbo|night)$ ]]
}

@test "heartbeat_get_interval returns a number" {
    heartbeat_init
    run heartbeat_get_interval
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "heartbeat_get_interval returns positive value" {
    heartbeat_init
    run heartbeat_get_interval
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "heartbeat_set_mode changes mode" {
    heartbeat_init
    heartbeat_set_mode "active"
    run heartbeat_get_mode
    [ "$status" -eq 0 ]
    [ "$output" = "active" ]
}

@test "heartbeat_turbo_start sets turbo mode" {
    heartbeat_init
    heartbeat_turbo_start
    run heartbeat_get_mode
    [ "$status" -eq 0 ]
    [ "$output" = "turbo" ]
}
