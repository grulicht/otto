#!/usr/bin/env bats
# OTTO - systemd services fetch script integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "systemd-services.sh runs without error" {
    if ! command -v systemctl &>/dev/null; then
        skip "systemctl not available"
    fi
    run bash "${OTTO_DIR}/scripts/fetch/systemd-services.sh"
    [ "$status" -eq 0 ]
}

@test "systemd-services.sh outputs valid JSON" {
    if ! command -v systemctl &>/dev/null; then
        skip "systemctl not available"
    fi
    run bash "${OTTO_DIR}/scripts/fetch/systemd-services.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' >/dev/null
}

@test "systemd-services.sh output is array or has items" {
    if ! command -v systemctl &>/dev/null; then
        skip "systemctl not available"
    fi
    run bash "${OTTO_DIR}/scripts/fetch/systemd-services.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'type == "array" or has("items") or has("services")'
}
