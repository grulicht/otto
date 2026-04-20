#!/usr/bin/env bats
# OTTO - Plugin manager tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/plugins"

    source "${OTTO_DIR}/scripts/core/plugin-manager.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "plugin_validate passes for valid plugin directory" {
    local plugin_dir="${OTTO_HOME}/plugins/test-plugin"
    mkdir -p "$plugin_dir"
    cat > "${plugin_dir}/plugin.yaml" << 'EOF'
name: test-plugin
version: 1.0.0
description: A test plugin
type: monitoring
EOF

    run plugin_validate "$plugin_dir"
    [ "$status" -eq 0 ]
}

@test "plugin_validate fails without plugin.yaml" {
    local plugin_dir="${OTTO_HOME}/plugins/no-yaml"
    mkdir -p "$plugin_dir"

    run plugin_validate "$plugin_dir"
    [ "$status" -ne 0 ]
}

@test "plugin_validate fails for nonexistent directory" {
    run plugin_validate "${OTTO_HOME}/plugins/nonexistent"
    [ "$status" -ne 0 ]
}

@test "plugin_validate fails when name field is missing" {
    local plugin_dir="${OTTO_HOME}/plugins/no-name"
    mkdir -p "$plugin_dir"
    cat > "${plugin_dir}/plugin.yaml" << 'EOF'
version: 1.0.0
description: Missing name field
EOF

    run plugin_validate "$plugin_dir"
    [ "$status" -ne 0 ]
}

@test "plugin_validate fails when version field is missing" {
    local plugin_dir="${OTTO_HOME}/plugins/no-version"
    mkdir -p "$plugin_dir"
    cat > "${plugin_dir}/plugin.yaml" << 'EOF'
name: bad-plugin
description: Missing version
EOF

    run plugin_validate "$plugin_dir"
    [ "$status" -ne 0 ]
}

@test "plugin_list runs without error when no plugins installed" {
    run plugin_list
    [ "$status" -eq 0 ]
}

@test "plugin_list shows installed plugin" {
    local plugin_dir="${OTTO_HOME}/plugins/my-plugin"
    mkdir -p "$plugin_dir"
    cat > "${plugin_dir}/plugin.yaml" << 'EOF'
name: my-plugin
version: 2.0.0
description: My test plugin
type: general
EOF

    run plugin_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-plugin"* ]]
    [[ "$output" == *"2.0.0"* ]]
}
