#!/usr/bin/env bats
# OTTO - Dashboard generator tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "dashboard_generate_terminal outputs dashboard content" {
    source "${OTTO_DIR}/scripts/core/dashboard.sh"
    run dashboard_generate_terminal
    [ "$status" -eq 0 ]
    [[ "$output" == *"OTTO"* ]]
    [[ "$output" == *"Dashboard"* ]] || [[ "$output" == *"Health"* ]]
}

@test "dashboard_generate_terminal shows CPU metric" {
    source "${OTTO_DIR}/scripts/core/dashboard.sh"
    run dashboard_generate_terminal
    [ "$status" -eq 0 ]
    [[ "$output" == *"CPU"* ]]
}

@test "dashboard_generate_terminal shows no alerts when alerts file missing" {
    source "${OTTO_DIR}/scripts/core/dashboard.sh"
    run dashboard_generate_terminal
    [ "$status" -eq 0 ]
    [[ "$output" == *"alert"* ]] || [[ "$output" == *"Alert"* ]]
}

@test "dashboard_generate_html creates file when template exists" {
    source "${OTTO_DIR}/scripts/core/dashboard.sh"
    if [ ! -f "${OTTO_DIR}/scripts/templates/dashboard/index.html" ]; then
        skip "Dashboard template not found"
    fi
    run dashboard_generate_html
    [ "$status" -eq 0 ]
    [ -f "${OTTO_HOME}/state/dashboard.html" ]
}

@test "dashboard_generate_html fails gracefully without template" {
    source "${OTTO_DIR}/scripts/core/dashboard.sh"
    export OTTO_TEMPLATE_DIR="${OTTO_HOME}/nonexistent"
    run dashboard_generate_html
    [ "$status" -ne 0 ]
}
