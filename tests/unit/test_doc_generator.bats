#!/usr/bin/env bats
# OTTO - Doc generator tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/docs/generated"

    source "${OTTO_DIR}/scripts/core/doc-generator.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "docgen_adr generates markdown with title" {
    run docgen_adr "Use PostgreSQL for persistence" \
        "We need a relational database" \
        "We will use PostgreSQL" \
        "Need to manage PostgreSQL backups"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Use PostgreSQL for persistence"* ]]
}

@test "docgen_adr creates file in adr directory" {
    docgen_adr "Switch to Kubernetes" \
        "Need container orchestration" \
        "Adopt Kubernetes" \
        "Team needs training" 2>/dev/null

    local adr_dir="${OTTO_HOME}/docs/generated/adr"
    [ -d "$adr_dir" ]
    local count
    count=$(ls "$adr_dir"/*.md 2>/dev/null | wc -l)
    [ "$count" -ge 1 ]
}

@test "docgen_adr output includes ADR number" {
    run docgen_adr "First Decision" "Context" "Decision" "Consequences"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ADR-1"* ]]
}

@test "docgen_adr output includes standard sections" {
    run docgen_adr "Test Decision" "Some context" "The decision" "Some consequences"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Context"* ]]
    [[ "$output" == *"Decision"* ]]
    [[ "$output" == *"Consequences"* ]]
}

@test "docgen_adr increments ADR number" {
    docgen_adr "First" "c1" "d1" "r1" 2>/dev/null
    run docgen_adr "Second" "c2" "d2" "r2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ADR-2"* ]]
}

@test "docgen_infra_overview generates markdown" {
    run docgen_infra_overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"Infrastructure Overview"* ]]
}
