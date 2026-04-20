#!/usr/bin/env bats
# OTTO - JSON utility tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "json_get returns value from JSON file" {
    echo '{"name": "otto", "version": "1.0"}' > "${OTTO_HOME}/test.json"
    run json_get "${OTTO_HOME}/test.json" '.name'
    [ "$status" -eq 0 ]
    [ "$output" = "otto" ]
}

@test "json_get returns default for missing key" {
    echo '{"name": "otto"}' > "${OTTO_HOME}/test.json"
    run json_get "${OTTO_HOME}/test.json" '.missing' 'fallback'
    [ "$status" -eq 0 ]
    [ "$output" = "fallback" ]
}

@test "json_get returns default for missing file" {
    run json_get "${OTTO_HOME}/nonexistent.json" '.key' 'default_val'
    [ "$status" -eq 0 ]
    [ "$output" = "default_val" ]
}

@test "json_set creates file and sets value" {
    json_set "${OTTO_HOME}/new.json" '.count' '42'
    run json_get "${OTTO_HOME}/new.json" '.count'
    [ "$status" -eq 0 ]
    [ "$output" = "42" ]
}

@test "json_set overwrites existing value" {
    echo '{"count": 1}' > "${OTTO_HOME}/test.json"
    json_set "${OTTO_HOME}/test.json" '.count' '99'
    run json_get "${OTTO_HOME}/test.json" '.count'
    [ "$status" -eq 0 ]
    [ "$output" = "99" ]
}

@test "json_set_string sets a string value" {
    echo '{}' > "${OTTO_HOME}/test.json"
    json_set_string "${OTTO_HOME}/test.json" '.greeting' 'hello world'
    run json_get "${OTTO_HOME}/test.json" '.greeting'
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "json_append adds to array" {
    echo '{"items": [1, 2]}' > "${OTTO_HOME}/test.json"
    json_append "${OTTO_HOME}/test.json" '.items' '3'
    run json_get "${OTTO_HOME}/test.json" '.items | length'
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "json_append creates array in new file" {
    json_append "${OTTO_HOME}/new.json" '.tags' '"first"'
    run json_get "${OTTO_HOME}/new.json" '.tags[0]'
    [ "$status" -eq 0 ]
    [ "$output" = "first" ]
}

@test "json_has returns 0 for existing key" {
    echo '{"active": true}' > "${OTTO_HOME}/test.json"
    run json_has "${OTTO_HOME}/test.json" '.active'
    [ "$status" -eq 0 ]
}

@test "json_has returns 1 for missing key" {
    echo '{"active": true}' > "${OTTO_HOME}/test.json"
    run json_has "${OTTO_HOME}/test.json" '.missing'
    [ "$status" -ne 0 ]
}

@test "json_has returns 1 for missing file" {
    run json_has "${OTTO_HOME}/nonexistent.json" '.key'
    [ "$status" -ne 0 ]
}
