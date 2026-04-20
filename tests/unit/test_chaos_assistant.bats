#!/usr/bin/env bats
# OTTO - Chaos assistant tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/chaos"

    source "${OTTO_DIR}/scripts/core/chaos-assistant.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "chaos_list_experiments returns valid JSON array" {
    run chaos_list_experiments
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'type == "array"'
}

@test "chaos_list_experiments returns at least 3 experiments" {
    run chaos_list_experiments
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" -ge 3 ]
}

@test "chaos_list_experiments includes pod-kill" {
    run chaos_list_experiments
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.[] | select(.name == "pod-kill")] | length > 0'
}

@test "chaos_list_experiments each entry has name, description, risk" {
    run chaos_list_experiments
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.[0] | has("name", "description", "risk")'
}

@test "chaos_list_experiments risk levels are valid" {
    run chaos_list_experiments
    [ "$status" -eq 0 ]
    local invalid
    invalid=$(echo "$output" | jq '[.[] | select(.risk != "low" and .risk != "medium" and .risk != "high")] | length')
    [ "$invalid" -eq 0 ]
}
