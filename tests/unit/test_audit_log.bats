#!/usr/bin/env bats
# OTTO - Audit log tests

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
    source "${OTTO_DIR}/scripts/core/audit-log.sh"

    # Override audit file location
    OTTO_STATE_DIR="${OTTO_HOME}/state"
    OTTO_AUDIT_FILE="${OTTO_STATE_DIR}/audit.jsonl"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "audit_log creates state directory" {
    audit_log "testuser" "deploy" "app-v1" "Deployed app" "success"
    [ -d "${OTTO_STATE_DIR}" ]
}

@test "audit_log writes entry to file" {
    audit_log "testuser" "deploy" "app-v1" "Deployed app" "success"
    [ -f "${OTTO_AUDIT_FILE}" ]
    local lines
    lines=$(wc -l < "${OTTO_AUDIT_FILE}")
    [ "$lines" -eq 1 ]
}

@test "audit_log entry is valid JSON" {
    audit_log "otto" "rollback" "api-server" "Rolled back" "success"
    run jq '.' "${OTTO_AUDIT_FILE}"
    [ "$status" -eq 0 ]
}

@test "audit_log entry contains correct actor" {
    audit_log "admin_user" "scale" "pods" "Scaled up" "success"
    run jq -r '.actor' "${OTTO_AUDIT_FILE}"
    [ "$status" -eq 0 ]
    [ "$output" = "admin_user" ]
}

@test "audit_search finds entry by actor" {
    audit_log "alice" "deploy" "web" "Deploy web" "success"
    audit_log "bob" "rollback" "api" "Rollback api" "failure"
    run audit_search '{"actor": "alice"}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"alice"* ]]
    [[ "$output" != *"bob"* ]]
}

@test "audit_search finds entry by action" {
    audit_log "user1" "deploy" "app1" "Deployed" "success"
    audit_log "user1" "delete" "app2" "Deleted" "success"
    run audit_search '{"action": "deploy"}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"deploy"* ]]
}

@test "audit_search returns nothing for no matches" {
    audit_log "user1" "deploy" "app" "msg" "success"
    local result
    result=$(audit_search '{"actor": "nonexistent_user"}' 2>/dev/null)
    local rc=$?
    [ "$rc" -eq 0 ]
    [[ -z "$result" || "$result" == "[]" ]]
}
