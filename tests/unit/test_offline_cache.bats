#!/usr/bin/env bats
# OTTO - Offline cache tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/cache"

    source "${OTTO_DIR}/scripts/core/offline-cache.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "cache_save creates cache file" {
    cache_save "test-key" '{"status":"ok"}'
    [ -f "${OTTO_HOME}/state/cache/test-key.json" ]
}

@test "cache_save stores valid JSON" {
    cache_save "json-test" '{"value":42}'
    run jq '.' "${OTTO_HOME}/state/cache/json-test.json"
    [ "$status" -eq 0 ]
}

@test "cache_get retrieves cached data" {
    cache_save "roundtrip" '{"name":"otto"}'
    run cache_get "roundtrip" 3600
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.name == "otto"'
}

@test "cache_get returns error for missing key" {
    run cache_get "nonexistent" 3600
    [ "$status" -ne 0 ]
}

@test "cache_get returns error for expired data" {
    cache_save "old-data" '{"stale":true}'
    # Modify the cached_at to be old
    local cache_file="${OTTO_HOME}/state/cache/old-data.json"
    jq '.cached_at = 1000000' "$cache_file" > "${cache_file}.tmp" && mv "${cache_file}.tmp" "$cache_file"

    run cache_get "old-data" 3600
    [ "$status" -ne 0 ]
}

@test "cache_invalidate removes cached entry" {
    cache_save "to-remove" '{"temp":true}'
    [ -f "${OTTO_HOME}/state/cache/to-remove.json" ]

    cache_invalidate "to-remove"
    [ ! -f "${OTTO_HOME}/state/cache/to-remove.json" ]
}

@test "cache_invalidate is safe for missing key" {
    run cache_invalidate "never-existed"
    [ "$status" -eq 0 ]
}

@test "cache_save/get roundtrip with string data" {
    cache_save "string-data" "plain text value"
    run cache_get "string-data" 3600
    [ "$status" -eq 0 ]
    [[ "$output" == *"plain text value"* ]]
}
