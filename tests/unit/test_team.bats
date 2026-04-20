#!/usr/bin/env bats
# OTTO - Team management tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    # Create minimal config
    mkdir -p "${OTTO_HOME}"
    cp "${OTTO_DIR}/config/default.yaml" "${OTTO_HOME}/config.yaml" 2>/dev/null || true

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
    source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"
    source "${OTTO_DIR}/scripts/core/config.sh"
    source "${OTTO_DIR}/scripts/core/team.sh"

    # Override team dirs to use temp home
    OTTO_TEAM_DIR="${OTTO_HOME}/team"
    OTTO_TEAM_CONFIG="${OTTO_TEAM_DIR}/config.yaml"
    OTTO_TEAM_KNOWLEDGE_DIR="${OTTO_TEAM_DIR}/knowledge"
    OTTO_TEAM_RUNBOOKS_DIR="${OTTO_TEAM_DIR}/runbooks"
    OTTO_TEAM_ACTIVITY_LOG="${OTTO_TEAM_DIR}/activity.jsonl"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "team_init creates directory structure" {
    team_init "test-team"
    [ -d "${OTTO_TEAM_DIR}" ]
    [ -d "${OTTO_TEAM_KNOWLEDGE_DIR}" ]
    [ -d "${OTTO_TEAM_RUNBOOKS_DIR}" ]
}

@test "team_init creates config file" {
    team_init "test-team"
    [ -f "${OTTO_TEAM_CONFIG}" ]
}

@test "team_init creates activity log" {
    team_init "test-team"
    [ -f "${OTTO_TEAM_ACTIVITY_LOG}" ]
}

@test "team_init config contains team name" {
    team_init "my-devops-team"
    run grep "my-devops-team" "${OTTO_TEAM_CONFIG}"
    [ "$status" -eq 0 ]
}
