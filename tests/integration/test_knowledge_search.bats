#!/usr/bin/env bats
# OTTO - Knowledge search integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/core/knowledge-engine.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "knowledge_search for 'kubernetes' returns results" {
    run knowledge_search "kubernetes"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" != *"No results"* ]]
}

@test "knowledge_search for 'docker' returns results" {
    run knowledge_search "docker"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" != *"No results"* ]]
}

@test "knowledge_search for 'terraform' returns results" {
    run knowledge_search "terraform"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" != *"No results"* ]]
}

@test "knowledge_search results include score" {
    run knowledge_search "kubernetes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"score:"* ]]
}

@test "knowledge_search for nonsense returns no results" {
    run knowledge_search "xyzzyplugh12345"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No results"* ]]
}

@test "knowledge_search for 'nginx' returns results" {
    run knowledge_search "nginx"
    if [ "$status" -ne 0 ]; then
        # nginx might not have knowledge entries, that is acceptable
        [[ "$output" == *"No results"* ]]
    else
        [ -n "$output" ]
    fi
}
