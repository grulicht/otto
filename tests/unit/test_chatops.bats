#!/usr/bin/env bats
# OTTO - ChatOps command parser tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/chatops"

    source "${OTTO_DIR}/scripts/core/chatops.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "chatops_parse_command recognizes 'check kubernetes'" {
    run chatops_parse_command "check kubernetes"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "check"'
    echo "$output" | jq -e '.args[0] == "kubernetes"'
}

@test "chatops_parse_command recognizes 'status'" {
    run chatops_parse_command "status"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "status"'
}

@test "chatops_parse_command recognizes 'deploy app prod v1.2'" {
    run chatops_parse_command "deploy app prod v1.2"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "deploy"'
    echo "$output" | jq -e '.args[0] == "app"'
}

@test "chatops_parse_command strips @otto prefix" {
    run chatops_parse_command "@otto status"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "status"'
}

@test "chatops_parse_command handles uppercase" {
    run chatops_parse_command "STATUS"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "status"'
}

@test "chatops_parse_command recognizes rollback" {
    run chatops_parse_command "rollback myapp staging"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "rollback"'
}

@test "chatops_parse_command recognizes scale" {
    run chatops_parse_command "scale web 5"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "scale"'
}

@test "chatops_parse_command recognizes incident" {
    run chatops_parse_command "incident database outage"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.command == "incident"'
}
