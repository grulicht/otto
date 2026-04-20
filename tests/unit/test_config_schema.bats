#!/usr/bin/env bats
# OTTO - Config schema validation tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/config-schema.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "schema_validate passes on valid config" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    cat > "${OTTO_HOME}/config.yaml" << 'EOF'
language: en
permission_profile: balanced
log_level: info
night_watcher:
  enabled: true
EOF

    run schema_validate "${OTTO_HOME}/config.yaml"
    [ "$status" -eq 0 ]
}

@test "schema_validate fails on invalid permission_profile" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    cat > "${OTTO_HOME}/bad-config.yaml" << 'EOF'
language: en
permission_profile: invalid_value
log_level: info
EOF

    run schema_validate "${OTTO_HOME}/bad-config.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalid"* ]]
}

@test "schema_validate fails on invalid log_level" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    cat > "${OTTO_HOME}/bad-level.yaml" << 'EOF'
language: en
permission_profile: balanced
log_level: verbose
EOF

    run schema_validate "${OTTO_HOME}/bad-level.yaml"
    [ "$status" -ne 0 ]
}

@test "schema_validate fails for missing file" {
    run schema_validate "/nonexistent/config.yaml"
    [ "$status" -ne 0 ]
}

@test "schema_validate fails on invalid YAML syntax" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    cat > "${OTTO_HOME}/broken.yaml" << 'EOF'
language: en
  bad_indent: this is broken yaml
    nested: wrong
EOF

    run schema_validate "${OTTO_HOME}/broken.yaml"
    [ "$status" -ne 0 ]
}
