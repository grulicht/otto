#!/usr/bin/env bats
# OTTO - Permission system tests

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
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    config_init 2>/dev/null
    config_load 2>/dev/null
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "permission_check returns auto for infrastructure read_state" {
    run permission_check "infrastructure" "read_state" "development"
    [ "$status" -eq 0 ]
    [ "$output" = "auto" ]
}

@test "permission_check returns deny for infrastructure destroy" {
    run permission_check "infrastructure" "destroy" "production"
    [ "$status" -eq 0 ]
    [ "$output" = "deny" ]
}

@test "permission_check returns confirm for kubernetes apply" {
    run permission_check "kubernetes" "apply" "staging"
    [ "$status" -eq 0 ]
    [ "$output" = "confirm" ]
}

@test "permission_enforce denies destructive actions" {
    run permission_enforce "infrastructure" "destroy" "production" "terraform destroy"
    [ "$status" -eq 1 ]
}

@test "permission_enforce auto-approves read actions" {
    run permission_enforce "infrastructure" "read_state" "development" "terraform state list"
    [ "$status" -eq 0 ]
}
