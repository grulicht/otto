#!/usr/bin/env bats
# OTTO - Compliance checker tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/core/compliance-checker.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "compliance_score returns 0 with no findings" {
    _compliance_reset
    run compliance_score
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "compliance_score returns 100 when all pass" {
    _compliance_reset
    _compliance_add_finding "test" "info" "check1" "pass" "OK" ""
    _compliance_add_finding "test" "info" "check2" "pass" "OK" ""
    _compliance_add_finding "test" "info" "check3" "pass" "OK" ""
    run compliance_score
    [ "$status" -eq 0 ]
    [ "$output" -eq 100 ]
}

@test "compliance_score returns number between 0 and 100" {
    _compliance_reset
    _compliance_add_finding "test" "info" "check1" "pass" "OK" ""
    _compliance_add_finding "test" "warning" "check2" "fail" "Bad" "Fix it"
    run compliance_score
    [ "$status" -eq 0 ]
    [ "$output" -ge 0 ]
    [ "$output" -le 100 ]
}

@test "compliance_score decreases with failures" {
    _compliance_reset
    _compliance_add_finding "test" "info" "check1" "pass" "OK" ""
    local all_pass
    all_pass=$(compliance_score)

    _compliance_add_finding "test" "warning" "check2" "fail" "Bad" "Fix"
    local with_fail
    with_fail=$(compliance_score)

    [ "$with_fail" -lt "$all_pass" ]
}

@test "compliance_score handles critical failures" {
    _compliance_reset
    _compliance_add_finding "test" "info" "check1" "pass" "OK" ""
    _compliance_add_finding "test" "critical" "check2" "fail" "Critical issue" "Fix now"
    run compliance_score
    [ "$status" -eq 0 ]
    [ "$output" -ge 0 ]
    [ "$output" -le 100 ]
}

@test "_compliance_add_finding accumulates findings" {
    _compliance_reset
    _compliance_add_finding "cat1" "info" "c1" "pass" "OK" ""
    _compliance_add_finding "cat2" "warning" "c2" "fail" "Bad" "Fix"
    local count
    count=$(echo "${_COMPLIANCE_FINDINGS}" | jq 'length')
    [ "$count" -eq 2 ]
}
