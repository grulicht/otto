#!/usr/bin/env bats
# OTTO - Capacity planner tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"

    source "${OTTO_DIR}/scripts/core/capacity-planner.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "capacity_disk_prediction returns valid JSON" {
    run capacity_disk_prediction "/"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' >/dev/null
}

@test "capacity_disk_prediction includes mount_point" {
    run capacity_disk_prediction "/"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.mount_point == "/"'
}

@test "capacity_disk_prediction includes usage_percent as number" {
    run capacity_disk_prediction "/"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.usage_percent >= 0'
}

@test "capacity_disk_prediction includes total_gb" {
    run capacity_disk_prediction "/"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.total_gb > 0'
}

@test "capacity_disk_prediction includes severity field" {
    run capacity_disk_prediction "/"
    [ "$status" -eq 0 ]
    local severity
    severity=$(echo "$output" | jq -r '.severity')
    [[ "$severity" == "ok" || "$severity" == "warning" || "$severity" == "critical" ]]
}

@test "capacity_memory_prediction returns valid JSON for localhost" {
    if ! command -v free &>/dev/null; then
        skip "free command not available"
    fi
    run capacity_memory_prediction "localhost"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.total_mb > 0'
    echo "$output" | jq -e '.host == "localhost"'
}
