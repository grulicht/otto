#!/usr/bin/env bats
# OTTO - Config system tests

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
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "config_init creates OTTO_HOME directory" {
    config_init
    [ -d "${OTTO_HOME}" ]
    [ -d "${OTTO_HOME}/agents" ]
    [ -d "${OTTO_HOME}/state" ]
}

@test "config_load reads default config" {
    config_init
    config_load 2>/dev/null
    run config_get '.user.experience_level' 'unknown'
    [ "$status" -eq 0 ]
    [ "$output" = "auto" ]
}

@test "config_get returns default for missing key" {
    config_init
    config_load 2>/dev/null
    run config_get '.nonexistent.key' 'fallback'
    [ "$status" -eq 0 ]
    [ "$output" = "fallback" ]
}

@test "config_validate passes on default config" {
    config_init
    config_load 2>/dev/null
    run config_validate
    [ "$status" -eq 0 ]
}
