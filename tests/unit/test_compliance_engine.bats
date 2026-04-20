#!/usr/bin/env bats
# OTTO - Compliance engine tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/compliance"

    source "${OTTO_DIR}/scripts/core/compliance-engine.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "policy_load reads policies from default file" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run policy_load "${OTTO_DIR}/config/policies.yaml"
    [ "$status" -eq 0 ]
    # Output may include log lines; last line should be the count
    local count
    count=$(echo "$output" | tail -1)
    [[ "$count" =~ ^[0-9]+$ ]]
    [ "$count" -gt 0 ]
}

@test "policy_load fails for missing file" {
    run policy_load "/nonexistent/policies.yaml"
    [ "$status" -ne 0 ]
}

@test "policy_list returns JSON array of policies" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run policy_list "${OTTO_DIR}/config/policies.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'type == "array"'
}

@test "policy_list includes policy names" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run policy_list "${OTTO_DIR}/config/policies.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.[0].name != null'
}

@test "policy_list includes severity field" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    run policy_list "${OTTO_DIR}/config/policies.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.[0].severity != null'
}

@test "policy_load with custom policy file" {
    if ! command -v yq &>/dev/null; then
        skip "yq not available"
    fi
    cat > "${OTTO_HOME}/test-policies.yaml" << 'EOF'
policies:
  - name: test-policy
    severity: low
    domain: testing
    check: "echo ok"
    expected: "ok"
EOF

    run policy_load "${OTTO_HOME}/test-policies.yaml"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | tail -1)
    [ "$count" = "1" ]
}
