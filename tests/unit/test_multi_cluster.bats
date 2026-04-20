#!/usr/bin/env bats
# OTTO - Multi-cluster management tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"

    source "${OTTO_DIR}/scripts/core/multi-cluster.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "cluster_list runs without crash when kubectl available" {
    if ! command -v kubectl &>/dev/null; then
        skip "kubectl not available"
    fi
    run cluster_list
    # Should exit 0 or 1 (1 if no contexts), but not crash
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "cluster_list fails gracefully without kubectl" {
    # Temporarily hide kubectl
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    if command -v kubectl &>/dev/null; then
        PATH="$original_path"
        skip "Cannot hide kubectl from PATH"
    fi
    run cluster_list
    [ "$status" -ne 0 ]
    PATH="$original_path"
}
