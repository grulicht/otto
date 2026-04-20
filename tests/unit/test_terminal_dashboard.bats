#!/usr/bin/env bats
# OTTO - Terminal dashboard TUI tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    export COLUMNS=60

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/core/terminal-dashboard.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "tui_health_bar outputs bar with percentage" {
    run tui_health_bar "CPU" 75
    [ "$status" -eq 0 ]
    [[ "$output" == *"CPU"* ]]
    [[ "$output" == *"75%"* ]]
}

@test "tui_status_line outputs formatted line with label and status" {
    run tui_status_line "Database" "ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Database"* ]]
    [[ "$output" == *"ok"* ]]
}

@test "tui_box wraps content with border characters" {
    run tui_box "Title" "Hello" 40
    [ "$status" -eq 0 ]
    [[ "$output" == *"Title"* ]]
    [[ "$output" == *"Hello"* ]]
    # Check for box drawing characters
    [[ "$output" == *"┌"* ]]
    [[ "$output" == *"┘"* ]]
}

@test "tui_separator outputs line of correct width" {
    run tui_separator 20
    [ "$status" -eq 0 ]
    local len=${#output}
    [ "$len" -eq 20 ]
}

@test "tui_health_bar uses green color for high percentage" {
    run tui_health_bar "Disk" 95
    [ "$status" -eq 0 ]
    [[ "$output" == *"95%"* ]]
}
