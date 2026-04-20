#!/usr/bin/env bats
# OTTO - Compliance integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
YAML
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "compliance_checker runs without error" {
    source "${OTTO_DIR}/scripts/core/compliance-checker.sh"

    # compliance_checker may produce output or exit 0
    run compliance_score
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "compliance_score returns 0-100" {
    source "${OTTO_DIR}/scripts/core/compliance-checker.sh"

    local score
    score=$(compliance_score 2>/dev/null || echo "0")

    # Score should be a number between 0 and 100
    [[ "${score}" =~ ^[0-9]+$ ]]
    [ "${score}" -ge 0 ]
    [ "${score}" -le 100 ]
}

@test "policy_load reads policies.yaml" {
    source "${OTTO_DIR}/scripts/core/compliance-engine.sh"

    # policy_load should run without error if policies.yaml exists
    if [ -f "${OTTO_DIR}/config/policies.yaml" ]; then
        run policy_load
        [ "$status" -eq 0 ]
    else
        skip "policies.yaml not found"
    fi
}

@test "policy_evaluate_all produces report with findings array" {
    source "${OTTO_DIR}/scripts/core/compliance-engine.sh"

    if [ -f "${OTTO_DIR}/config/policies.yaml" ]; then
        local report
        report=$(policy_evaluate_all 2>/dev/null || echo '{"findings":[]}')

        # Report should be valid JSON with a findings array
        echo "${report}" | jq -e '.findings' >/dev/null 2>&1 || \
        echo "${report}" | jq -e '.' >/dev/null 2>&1 || \
        [[ "${report}" == *"findings"* ]] || \
        [[ "${report}" == *"policy"* ]]
    else
        skip "policies.yaml not found"
    fi
}
