#!/usr/bin/env bats
# OTTO - Log rotation tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/log-rotate.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "logrotate_check detects file exceeding size limit" {
    local testfile="${OTTO_HOME}/large.log"
    # Create a file larger than 1 MB
    dd if=/dev/zero of="$testfile" bs=1024 count=1100 2>/dev/null
    run logrotate_check "$testfile" 1
    [ "$status" -eq 0 ]
}

@test "logrotate_check passes for small file" {
    local testfile="${OTTO_HOME}/small.log"
    echo "small content" > "$testfile"
    run logrotate_check "$testfile" 1
    [ "$status" -ne 0 ]
}

@test "logrotate_check returns 1 for missing file" {
    run logrotate_check "${OTTO_HOME}/nonexistent.log" 1
    [ "$status" -ne 0 ]
}

@test "logrotate_rotate creates rotated file" {
    local testfile="${OTTO_HOME}/app.log"
    echo "log line 1" > "$testfile"

    logrotate_rotate "$testfile"

    [ -f "${testfile}.1" ]
    [ -f "$testfile" ]
    # Original should now be empty
    [ ! -s "$testfile" ]
}

@test "logrotate_rotate preserves content in rotated file" {
    local testfile="${OTTO_HOME}/data.log"
    echo "important data" > "$testfile"

    logrotate_rotate "$testfile"

    grep -q "important data" "${testfile}.1"
}

@test "logrotate_rotate shifts existing rotated files" {
    local testfile="${OTTO_HOME}/shift.log"
    echo "current" > "$testfile"
    echo "previous" > "${testfile}.1"

    logrotate_rotate "$testfile"

    [ -f "${testfile}.2" ]
    grep -q "previous" "${testfile}.2"
    grep -q "current" "${testfile}.1"
}

@test "logrotate_rotate is safe for missing file" {
    run logrotate_rotate "${OTTO_HOME}/missing.log"
    [ "$status" -eq 0 ]
}
