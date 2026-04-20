#!/usr/bin/env bats
# OTTO - Change tracker tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/snapshots"

    source "${OTTO_DIR}/scripts/core/change-tracker.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "changes_snapshot creates a snapshot file" {
    run changes_snapshot
    [ "$status" -eq 0 ]

    # Output should contain the file path
    [[ "$output" == *".json"* ]]

    # The snapshots directory should have a file
    local count
    count=$(ls "${OTTO_HOME}/state/snapshots/"*.json 2>/dev/null | wc -l)
    [ "$count" -ge 1 ]
}

@test "changes_snapshot file contains valid JSON" {
    local result
    result=$(changes_snapshot 2>/dev/null)
    local snapshot_file
    snapshot_file=$(echo "$result" | grep -o '/.*\.json' | head -1)

    [ -f "$snapshot_file" ]
    run jq '.' "$snapshot_file"
    [ "$status" -eq 0 ]
}

@test "changes_snapshot file contains timestamp" {
    local result
    result=$(changes_snapshot 2>/dev/null)
    local snapshot_file
    snapshot_file=$(echo "$result" | grep -o '/.*\.json' | head -1)

    run jq -r '.timestamp' "$snapshot_file"
    [ "$status" -eq 0 ]
    [ "$output" != "null" ]
}

@test "changes_snapshot file contains system metrics" {
    local result
    result=$(changes_snapshot 2>/dev/null)
    local snapshot_file
    snapshot_file=$(echo "$result" | grep -o '/.*\.json' | head -1)

    run jq -r '.system.cpu' "$snapshot_file"
    [ "$status" -eq 0 ]
    [ "$output" != "null" ]
}

@test "changes_summary returns a string" {
    run changes_summary
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "changes_summary without snapshot reports no previous snapshot" {
    # Clear snapshots
    rm -f "${OTTO_HOME}/state/snapshots/"*.json 2>/dev/null
    run changes_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"No previous snapshot"* ]]
}
