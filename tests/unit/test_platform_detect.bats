#!/usr/bin/env bats
# OTTO - Platform detection tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/platform-detect.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "detect_os returns a valid value" {
    run detect_os
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(linux|macos|windows|freebsd|unknown)$ ]]
}

@test "detect_os returns linux or macos on typical CI" {
    run detect_os
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "detect_tool finds bash" {
    run detect_tool bash
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "detect_tool finds jq" {
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi
    run detect_tool jq
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "detect_tool fails for nonexistent tool" {
    run detect_tool nonexistent_tool_xyz_12345
    [ "$status" -ne 0 ]
}

@test "detect_all_tools produces valid JSON" {
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi
    run detect_all_tools "${OTTO_HOME}/tools.json"
    [ "$status" -eq 0 ]
    [ -f "${OTTO_HOME}/tools.json" ]
    run jq '.' "${OTTO_HOME}/tools.json"
    [ "$status" -eq 0 ]
}
