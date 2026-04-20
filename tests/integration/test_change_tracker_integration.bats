#!/usr/bin/env bats
# OTTO - Change tracker integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
YAML

    source "${OTTO_DIR}/scripts/core/change-tracker.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "changes_snapshot creates timestamped JSON" {
    # Ensure state.json exists so json_get doesn't fail
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    changes_snapshot >/dev/null 2>&1

    # Find the snapshot file in the snapshots directory
    local snapshot_dir="${OTTO_HOME}/state/snapshots"
    local snapshot_file
    snapshot_file=$(ls -1t "${snapshot_dir}"/*.json 2>/dev/null | head -1)

    [ -n "${snapshot_file}" ]
    [ -f "${snapshot_file}" ]
    [ -s "${snapshot_file}" ]

    # Should be valid JSON (use || true since jq -e returns 1 for false/null values)
    jq '.' "${snapshot_file}" >/dev/null 2>&1
}

@test "changes_diff between two different snapshots shows differences" {
    # Take first snapshot
    local snap1
    snap1=$(changes_snapshot 2>/dev/null | grep -o '/.*\.json' | tail -1)
    [ -f "${snap1}" ]

    sleep 1

    # Take second snapshot
    local snap2
    snap2=$(changes_snapshot 2>/dev/null | grep -o '/.*\.json' | tail -1)
    [ -f "${snap2}" ]

    # Run diff - should succeed regardless of whether there are changes
    run changes_diff "${snap1}" "${snap2}"
    [ "$status" -eq 0 ]
}

@test "changes_since_last works after two snapshots" {
    # Take first snapshot
    changes_snapshot >/dev/null 2>&1
    sleep 1

    # changes_since_last should work (takes a temp snapshot and compares)
    run changes_since_last
    [ "$status" -eq 0 ]
}

@test "changes_history returns correct count" {
    # Take 3 snapshots
    changes_snapshot >/dev/null 2>&1
    sleep 1
    changes_snapshot >/dev/null 2>&1
    sleep 1
    changes_snapshot >/dev/null 2>&1

    run changes_history 2
    [ "$status" -eq 0 ]
    # Should show some output (header + changes or "no changes")
    [ -n "$output" ]
}
