#!/usr/bin/env bats
# OTTO - Postmortem generator tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/postmortems"
    mkdir -p "${OTTO_HOME}/state/tasks/triage"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "postmortem_generate creates markdown file for incident" {
    source "${OTTO_DIR}/scripts/core/postmortem.sh"

    # Create a mock incident task file
    cat > "${OTTO_HOME}/state/tasks/triage/INC-001.md" << 'EOF'
---
title: Database connection pool exhaustion
priority: high
created: 2026-01-15T10:00:00Z
updated: 2026-01-15T12:00:00Z
---

Database connection pool ran out of connections causing 503 errors.
EOF

    run postmortem_generate "INC-001"
    [ "$status" -eq 0 ]

    # Find the generated postmortem
    local pm_files
    pm_files=$(ls "${OTTO_HOME}/state/postmortems/"*INC-001.md 2>/dev/null)
    [ -n "$pm_files" ]
}

@test "postmortem_generate includes incident title in output" {
    source "${OTTO_DIR}/scripts/core/postmortem.sh"

    cat > "${OTTO_HOME}/state/tasks/triage/INC-002.md" << 'EOF'
---
title: API timeout
priority: medium
created: 2026-01-15T10:00:00Z
updated: 2026-01-15T12:00:00Z
---

API was timing out.
EOF

    postmortem_generate "INC-002" 2>/dev/null
    local pm_file
    pm_file=$(ls "${OTTO_HOME}/state/postmortems/"*INC-002.md 2>/dev/null | head -1)
    [ -f "$pm_file" ]
    grep -q "API timeout" "$pm_file"
}

@test "postmortem_generate without task file still creates postmortem" {
    source "${OTTO_DIR}/scripts/core/postmortem.sh"
    run postmortem_generate "INC-999"
    [ "$status" -eq 0 ]

    local pm_file
    pm_file=$(ls "${OTTO_HOME}/state/postmortems/"*INC-999.md 2>/dev/null | head -1)
    [ -f "$pm_file" ]
}

@test "postmortem_list shows no postmortems when dir empty" {
    source "${OTTO_DIR}/scripts/core/postmortem.sh"
    # Remove any files
    rm -f "${OTTO_HOME}/state/postmortems/"*.md 2>/dev/null
    run postmortem_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No postmortems"* ]] || [[ "$output" == *"postmortem"* ]]
}

@test "postmortem_list shows generated postmortem" {
    source "${OTTO_DIR}/scripts/core/postmortem.sh"
    postmortem_generate "INC-100" 2>/dev/null
    run postmortem_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"INC-100"* ]]
}
