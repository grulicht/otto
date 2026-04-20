#!/usr/bin/env bats
# OTTO - Knowledge engine tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    export OTTO_ROOT="${OTTO_DIR}"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/core/knowledge-engine.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "knowledge_search finds kubernetes content" {
    run knowledge_search "kubernetes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kubernetes"* ]]
}

@test "knowledge_search finds docker content" {
    run knowledge_search "docker"
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker"* ]]
}

@test "knowledge_search returns error for nonsense query" {
    run knowledge_search "xyzzy_no_match_at_all_12345"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No results"* ]]
}

@test "knowledge_list_topics returns topics" {
    run knowledge_list_topics
    [ "$status" -eq 0 ]
    [[ "$output" == *"best-practices"* ]]
}

@test "knowledge_list_topics includes troubleshooting" {
    run knowledge_list_topics
    [ "$status" -eq 0 ]
    [[ "$output" == *"troubleshooting"* ]]
}

@test "knowledge_get_for_topic finds terraform content" {
    run knowledge_get_for_topic "terraform"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
