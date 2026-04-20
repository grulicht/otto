#!/usr/bin/env bats
# OTTO - Incident memory tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/incidents"

    source "${OTTO_DIR}/scripts/core/incident-memory.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "incident_memory_save creates incident file" {
    local context='{"symptoms":"high cpu","resolution":"scaled up"}'
    incident_memory_save "INC-001" "$context"
    [ -f "${OTTO_HOME}/state/incidents/INC-001.json" ]
}

@test "incident_memory_save stores valid JSON" {
    local context='{"symptoms":"disk full"}'
    incident_memory_save "INC-002" "$context"

    run jq '.' "${OTTO_HOME}/state/incidents/INC-002.json"
    [ "$status" -eq 0 ]
}

@test "incident_memory_load returns saved data" {
    local context='{"symptoms":"memory leak","service":"api"}'
    incident_memory_save "INC-003" "$context"

    run incident_memory_load "INC-003"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.symptoms == "memory leak"'
    echo "$output" | jq -e '.service == "api"'
}

@test "incident_memory_save/load roundtrip preserves incident_id" {
    local context='{"symptoms":"timeout"}'
    incident_memory_save "INC-004" "$context"

    run incident_memory_load "INC-004"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.incident_id == "INC-004"'
}

@test "incident_memory_load adds timestamps" {
    local context='{"symptoms":"crash"}'
    incident_memory_save "INC-005" "$context"

    run incident_memory_load "INC-005"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.created_at != null'
    echo "$output" | jq -e '.updated_at != null'
}

@test "incident_memory_load returns null for missing incident" {
    run incident_memory_load "NONEXISTENT"
    [ "$status" -ne 0 ]
    [ "$output" = "null" ]
}

@test "incident_memory_save merges with existing data" {
    local ctx1='{"symptoms":"high latency"}'
    local ctx2='{"resolution":"fixed config"}'
    incident_memory_save "INC-006" "$ctx1"
    incident_memory_save "INC-006" "$ctx2"

    run incident_memory_load "INC-006"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.symptoms == "high latency"'
    echo "$output" | jq -e '.resolution == "fixed config"'
}
