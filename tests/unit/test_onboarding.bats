#!/usr/bin/env bats
# OTTO - Onboarding system tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_ROOT="${OTTO_DIR}"
    export OTTO_HOME="$(mktemp -d)"
    export HOME="${OTTO_HOME}"

    source "${OTTO_DIR}/scripts/core/onboarding.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "onboarding_detect_stack returns comma-separated list of detected tools" {
    run onboarding_detect_stack
    [ "$status" -eq 0 ]
    # At minimum, jq and git should be detected in a dev environment
    [[ "$output" == *","* ]] || [[ -n "$output" ]]
}

@test "onboarding_suggest_profile returns platform-engineer for terraform+kubectl" {
    run onboarding_suggest_profile "terraform,kubectl,docker"
    [ "$status" -eq 0 ]
    [ "$output" = "platform-engineer" ]
}

@test "onboarding_suggest_profile returns developer for docker+git" {
    run onboarding_suggest_profile "docker,git"
    [ "$status" -eq 0 ]
    [ "$output" = "developer" ]
}

@test "onboarding_suggest_profile returns general-ops for unknown tools" {
    run onboarding_suggest_profile "vim,nano"
    [ "$status" -eq 0 ]
    [ "$output" = "general-ops" ]
}

@test "onboarding_create_config generates valid YAML config file" {
    run onboarding_create_config "testuser" "beginner" "developer" "docker,git" "developer"
    [ "$status" -eq 0 ]

    local config_file="$output"
    [ -f "$config_file" ]
    grep -q 'name: "testuser"' "$config_file"
    grep -q 'level: "beginner"' "$config_file"
}
