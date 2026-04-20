#!/usr/bin/env bats
# OTTO - Config profiles integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "beginner profile is valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run yq eval '.' "${OTTO_DIR}/config/profiles/beginner.yaml"
    [ "$status" -eq 0 ]
}

@test "balanced profile is valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run yq eval '.' "${OTTO_DIR}/config/profiles/balanced.yaml"
    [ "$status" -eq 0 ]
}

@test "autonomous profile is valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run yq eval '.' "${OTTO_DIR}/config/profiles/autonomous.yaml"
    [ "$status" -eq 0 ]
}

@test "paranoid profile is valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run yq eval '.' "${OTTO_DIR}/config/profiles/paranoid.yaml"
    [ "$status" -eq 0 ]
}

@test "beginner profile has permissions section" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run yq eval '.permissions' "${OTTO_DIR}/config/profiles/beginner.yaml"
    [ "$status" -eq 0 ]
    [ "$output" != "null" ]
}

@test "balanced profile has production environment config" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run yq eval '.permissions.environments.production' "${OTTO_DIR}/config/profiles/balanced.yaml"
    [ "$status" -eq 0 ]
    [ "$output" != "null" ]
}

@test "paranoid profile restricts destructive operations" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    local result
    result=$(yq eval '.permissions.environments.production.destructive // .permissions.default_mode' "${OTTO_DIR}/config/profiles/paranoid.yaml")
    [[ "$result" == "deny" || "$result" == "suggest" ]]
}

@test "default config is valid YAML" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run yq eval '.' "${OTTO_DIR}/config/default.yaml"
    [ "$status" -eq 0 ]
}
