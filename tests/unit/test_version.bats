#!/usr/bin/env bats
# OTTO - Version utility tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    source "${OTTO_DIR}/scripts/lib/version.sh"
}

@test "otto_version returns a version string" {
    run otto_version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "otto_version_check passes for current version" {
    run otto_version_check "${OTTO_VERSION}"
    [ "$status" -eq 0 ]
}

@test "otto_version_check passes for older required version" {
    run otto_version_check "0.0.1"
    [ "$status" -eq 0 ]
}

@test "otto_version_check fails for newer required version" {
    run otto_version_check "99.99.99"
    [ "$status" -eq 1 ]
}
