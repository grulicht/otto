#!/usr/bin/env bats
# OTTO - i18n tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/i18n.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "i18n_load loads English language file" {
    run i18n_load "en"
    [ "$status" -eq 0 ]
}

@test "i18n_get returns English string after loading en" {
    i18n_load "en"
    run i18n_get "APP_NAME"
    [ "$status" -eq 0 ]
    [ "$output" = "OTTO" ]
}

@test "i18n_get returns YES string" {
    i18n_load "en"
    run i18n_get "YES"
    [ "$status" -eq 0 ]
    [ "$output" = "yes" ]
}

@test "i18n_get returns default for unknown key" {
    i18n_load "en"
    run i18n_get "TOTALLY_UNKNOWN_KEY" "my-default"
    [ "$status" -eq 0 ]
    [ "$output" = "my-default" ]
}

@test "i18n_get returns key name when no default and key missing" {
    i18n_load "en"
    run i18n_get "NONEXISTENT_KEY"
    [ "$status" -eq 0 ]
    [ "$output" = "NONEXISTENT_KEY" ]
}

@test "i18n_load falls back to English for unknown language" {
    i18n_load "xx"
    run i18n_get "APP_NAME"
    [ "$status" -eq 0 ]
    [ "$output" = "OTTO" ]
}

@test "i18n_load Czech language file" {
    if [ ! -f "${OTTO_DIR}/i18n/cs.sh" ]; then
        skip "Czech language file not available"
    fi
    run i18n_load "cs"
    [ "$status" -eq 0 ]
}

@test "i18n_get returns status strings" {
    i18n_load "en"
    run i18n_get "STATUS_HEALTHY"
    [ "$status" -eq 0 ]
    [ "$output" = "Healthy" ]
}
