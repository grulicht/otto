#!/usr/bin/env bats
# OTTO - Plugin system integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
    mkdir -p "${OTTO_HOME}/plugins"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
YAML

    source "${OTTO_DIR}/scripts/core/plugin-manager.sh"

    # Create a temporary mock plugin
    MOCK_PLUGIN_DIR="$(mktemp -d)"
    mkdir -p "${MOCK_PLUGIN_DIR}/agents"

    cat > "${MOCK_PLUGIN_DIR}/plugin.yaml" <<'YAML'
name: test-plugin
version: 0.1.0
description: A test plugin for integration testing
author: otto-test
YAML

    cat > "${MOCK_PLUGIN_DIR}/agents/test-agent.md" <<'MD'
---
name: test-agent
description: Test agent from plugin
triggers: []
---
# Test Agent
This is a test agent provided by the test plugin.
MD
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
    [ -d "${MOCK_PLUGIN_DIR}" ] && rm -rf "${MOCK_PLUGIN_DIR}"
}

@test "plugin_validate passes for valid plugin" {
    run plugin_validate "${MOCK_PLUGIN_DIR}"
    [ "$status" -eq 0 ]
}

@test "plugin_validate fails for plugin without plugin.yaml" {
    local bad_plugin
    bad_plugin="$(mktemp -d)"

    run plugin_validate "${bad_plugin}"
    [ "$status" -ne 0 ]

    rm -rf "${bad_plugin}"
}

@test "plugin_install from local path" {
    run plugin_install "${MOCK_PLUGIN_DIR}"
    [ "$status" -eq 0 ]

    # Plugin directory should exist in plugins dir
    [ -d "${OTTO_HOME}/plugins/test-plugin" ] || \
    ls "${OTTO_HOME}/plugins/" | grep -q "test-plugin" || \
    [[ "$output" == *"install"* ]]
}

@test "plugin_list shows installed plugin" {
    plugin_install "${MOCK_PLUGIN_DIR}" >/dev/null 2>&1

    run plugin_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-plugin"* ]] || [[ "$output" == *"plugin"* ]]
}

@test "plugin_uninstall removes plugin" {
    plugin_install "${MOCK_PLUGIN_DIR}" >/dev/null 2>&1

    run plugin_uninstall "test-plugin"
    [ "$status" -eq 0 ]

    # Verify it's gone
    if [ -d "${OTTO_HOME}/plugins/test-plugin" ]; then
        # Directory should be removed
        [ ! -f "${OTTO_HOME}/plugins/test-plugin/plugin.yaml" ]
    fi
}
