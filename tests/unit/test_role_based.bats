#!/usr/bin/env bats
# OTTO - Role-based access control tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    mkdir -p "${OTTO_HOME}"
    cp "${OTTO_DIR}/config/default.yaml" "${OTTO_HOME}/config.yaml" 2>/dev/null || true

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
    source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"
    source "${OTTO_DIR}/scripts/core/config.sh"
    source "${OTTO_DIR}/scripts/core/team.sh"
    source "${OTTO_DIR}/scripts/core/role-based.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "admin role allows all actions" {
    run role_check_permission "admin" "kubernetes" "apply"
    [ "$status" -eq 0 ]
    [ "$output" = "auto" ]
}

@test "admin role allows destructive actions" {
    run role_check_permission "admin" "infrastructure" "delete"
    [ "$status" -eq 0 ]
    [ "$output" = "auto" ]
}

@test "viewer role allows read actions" {
    run role_check_permission "viewer" "monitoring" "get"
    [ "$status" -eq 0 ]
    [ "$output" = "auto" ]
}

@test "viewer role denies write actions" {
    run role_check_permission "viewer" "kubernetes" "apply"
    [ "$status" -ne 0 ]
    [ "$output" = "deny" ]
}

@test "viewer role denies delete actions" {
    run role_check_permission "viewer" "infrastructure" "delete"
    [ "$status" -ne 0 ]
    [ "$output" = "deny" ]
}

@test "engineer role has some access" {
    run role_check_permission "engineer" "monitoring" "get"
    [ "$status" -eq 0 ]
}

@test "role_get_allowed_domains returns domains for admin" {
    run role_get_allowed_domains "admin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kubernetes"* ]]
    [[ "$output" == *"infrastructure"* ]]
}

@test "role_get_allowed_domains returns fewer domains for viewer" {
    local admin_count viewer_count
    admin_count=$(role_get_allowed_domains "admin" | wc -l)
    viewer_count=$(role_get_allowed_domains "viewer" | wc -l)
    [ "$admin_count" -ge "$viewer_count" ]
}
