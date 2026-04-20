#!/usr/bin/env bats
# OTTO - YAML utility tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"

    if ! command -v yq &>/dev/null; then
        skip "yq not installed"
    fi
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "yaml_get reads value from YAML file" {
    cat > "${OTTO_HOME}/test.yaml" <<EOF
server:
  host: localhost
  port: 8080
EOF
    run yaml_get "${OTTO_HOME}/test.yaml" '.server.host'
    [ "$status" -eq 0 ]
    [ "$output" = "localhost" ]
}

@test "yaml_get returns default for missing key" {
    cat > "${OTTO_HOME}/test.yaml" <<EOF
server:
  host: localhost
EOF
    run yaml_get "${OTTO_HOME}/test.yaml" '.server.port' '3000'
    [ "$status" -eq 0 ]
    [ "$output" = "3000" ]
}

@test "yaml_get returns default for missing file" {
    run yaml_get "${OTTO_HOME}/nonexistent.yaml" '.key' 'default'
    [ "$status" -eq 0 ]
    [ "$output" = "default" ]
}

@test "yaml_set updates value in YAML file" {
    cat > "${OTTO_HOME}/test.yaml" <<EOF
server:
  port: 8080
EOF
    yaml_set "${OTTO_HOME}/test.yaml" '.server.port' '9090'
    run yaml_get "${OTTO_HOME}/test.yaml" '.server.port'
    [ "$status" -eq 0 ]
    [ "$output" = "9090" ]
}

@test "yaml_set creates new key" {
    cat > "${OTTO_HOME}/test.yaml" <<EOF
server:
  host: localhost
EOF
    yaml_set "${OTTO_HOME}/test.yaml" '.server.port' '3000'
    run yaml_get "${OTTO_HOME}/test.yaml" '.server.port'
    [ "$status" -eq 0 ]
    [ "$output" = "3000" ]
}
