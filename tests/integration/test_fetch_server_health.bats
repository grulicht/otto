#!/usr/bin/env bats
# OTTO - Server health fetch script integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "server-health.sh outputs valid JSON" {
    run bash "${OTTO_DIR}/scripts/fetch/server-health.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' >/dev/null
}

@test "server-health.sh output contains cpu_percent" {
    run bash "${OTTO_DIR}/scripts/fetch/server-health.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.cpu_percent != null or .cpu != null or .items != null'
}

@test "server-health.sh output contains memory_percent" {
    run bash "${OTTO_DIR}/scripts/fetch/server-health.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.memory_percent != null or .memory != null or .ram != null or .items != null'
}

@test "server-health.sh output contains hostname" {
    run bash "${OTTO_DIR}/scripts/fetch/server-health.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hostname != null or .host != null'
}
