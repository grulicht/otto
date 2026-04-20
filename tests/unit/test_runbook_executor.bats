#!/usr/bin/env bats
# OTTO - Runbook executor tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/i18n.sh"
    i18n_init 2>/dev/null || true
    source "${OTTO_DIR}/scripts/core/runbook-executor.sh"

    # Create a test runbook in the user runbook dir
    mkdir -p "${OTTO_HOME}/knowledge/runbooks"
    cat > "${OTTO_HOME}/knowledge/runbooks/test-runbook.md" <<'EOF'
# Test Runbook

1. Verify the system is running.

```bash
echo "hello world"
```

2. Check the status.
EOF
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "runbook_list shows available runbooks from knowledge/runbooks/" {
    run runbook_list
    [ "$status" -eq 0 ]
    # Should list runbooks from the OTTO_DIR directory
    [[ "$output" == *"certificate-renewal"* ]] || [[ "$output" == *"test-runbook"* ]]
}

@test "runbook_validate passes for valid runbook file" {
    run runbook_validate "test-runbook"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Valid runbook"* ]]
}

@test "runbook_validate fails for nonexistent runbook" {
    run runbook_validate "nonexistent-runbook"
    [ "$status" -eq 1 ]
}

@test "_runbook_find locates runbook by name" {
    run _runbook_find "test-runbook"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-runbook.md"* ]]
}

@test "_runbook_parse_steps extracts steps from markdown" {
    local file="${OTTO_HOME}/knowledge/runbooks/test-runbook.md"
    run _runbook_parse_steps "${file}"
    [ "$status" -eq 0 ]
    # Should find both text and bash steps
    [[ "$output" == *"|text|"* ]]
    [[ "$output" == *"|bash|"* ]]
}
