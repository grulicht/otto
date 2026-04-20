#!/usr/bin/env bats
# OTTO - State lock tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/locks"

    source "${OTTO_DIR}/scripts/lib/state-lock.sh"
}

teardown() {
    # Release any held locks
    exec 200>&- 2>/dev/null || true
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "state_lock_acquire creates lock file" {
    state_lock_acquire "test-lock" 5
    [ -f "${OTTO_HOME}/state/locks/test-lock.lock" ]
    state_lock_release "test-lock"
}

@test "state_lock_acquire and release cycle succeeds" {
    run bash -c "
        source '${OTTO_DIR}/scripts/lib/state-lock.sh'
        export OTTO_HOME='${OTTO_HOME}'
        _LOCK_DIR='${OTTO_HOME}/state/locks'
        state_lock_acquire 'cycle-test' 5
        state_lock_release 'cycle-test'
        echo 'done'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"done"* ]]
}

@test "state_lock_release is safe for missing lock" {
    run state_lock_release "never-acquired"
    [ "$status" -eq 0 ]
}

@test "state_with_lock executes command under lock" {
    run state_with_lock "exec-test" echo "hello from lock"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello from lock"* ]]
}

@test "state_with_lock returns command exit code" {
    run state_with_lock "fail-test" false
    [ "$status" -ne 0 ]
}
