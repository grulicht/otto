#!/usr/bin/env bats
# OTTO - Cost analyzer tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    command -v jq &>/dev/null || skip "jq is required"

    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/core/cost-analyzer.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "cost_summary returns valid JSON structure" {
    # Without cloud CLIs, the function should still produce valid JSON with null clouds
    local json_output
    json_output=$(cost_summary 2>/dev/null)
    local rc=$?
    [ "$rc" -eq 0 ]

    echo "$json_output" | jq -e '.generated_at' > /dev/null
    echo "$json_output" | jq -e '.clouds' > /dev/null
    echo "$json_output" | jq -e '.recommendations' > /dev/null
}

@test "cost_summary contains expected top-level keys" {
    local json_output
    json_output=$(cost_summary 2>/dev/null)
    local rc=$?
    [ "$rc" -eq 0 ]

    local keys
    keys=$(echo "$json_output" | jq -r 'keys[]' | sort | tr '\n' ',')
    [[ "$keys" == *"clouds"* ]]
    [[ "$keys" == *"recommendations"* ]]
    [[ "$keys" == *"total_potential_savings"* ]]
}

@test "cost_recommendations returns JSON with recommendations array" {
    run cost_recommendations
    [ "$status" -eq 0 ]

    local rec_type
    rec_type=$(echo "$output" | jq -r '.recommendations | type')
    [ "$rec_type" = "array" ]

    local savings
    savings=$(echo "$output" | jq '.total_potential_savings')
    [ "$savings" != "null" ]
}

@test "_cost_month_start returns first day of month" {
    run _cost_month_start
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-01$ ]]
}
