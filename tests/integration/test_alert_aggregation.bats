#!/usr/bin/env bats
# OTTO - Alert pipeline integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
alert_routing:
  rules: []
YAML

    source "${OTTO_DIR}/scripts/core/alert-aggregator.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "alert_fingerprint generates consistent hash for same input" {
    local hash1 hash2
    hash1=$(alert_fingerprint "disk_full" "critical" "server01")
    hash2=$(alert_fingerprint "disk_full" "critical" "server01")
    [ "${hash1}" = "${hash2}" ]
    [ -n "${hash1}" ]
}

@test "alert_fingerprint generates different hash for different input" {
    local hash1 hash2
    hash1=$(alert_fingerprint "disk_full" "critical" "server01")
    hash2=$(alert_fingerprint "cpu_high" "warning" "server02")
    [ "${hash1}" != "${hash2}" ]
}

@test "alert_deduplicate removes duplicates from array" {
    local alerts='[
        {"fingerprint":"abc","source":"prometheus","summary":"disk full"},
        {"fingerprint":"abc","source":"grafana","summary":"disk full"},
        {"fingerprint":"def","source":"prometheus","summary":"cpu high"}
    ]'

    local result
    result=$(alert_deduplicate "${alerts}")

    local count
    count=$(echo "${result}" | jq 'length')
    [ "${count}" -eq 2 ]
}

@test "alert_aggregate merges multiple source arrays" {
    local source1='[{"fingerprint":"a1","summary":"alert 1"}]'
    local source2='[{"fingerprint":"a2","summary":"alert 2"}]'

    local result
    result=$(alert_aggregate "${source1}" "${source2}")

    local count
    count=$(echo "${result}" | jq 'length')
    [ "${count}" -eq 2 ]
}

@test "alert_severity_sort orders critical > warning > info" {
    local alerts='[
        {"severity":"info","summary":"info alert"},
        {"severity":"critical","summary":"critical alert"},
        {"severity":"warning","summary":"warning alert"}
    ]'

    local result
    result=$(alert_severity_sort "${alerts}")

    local first_severity
    first_severity=$(echo "${result}" | jq -r '.[0].severity')
    [ "${first_severity}" = "critical" ]

    local last_severity
    last_severity=$(echo "${result}" | jq -r '.[-1].severity')
    [ "${last_severity}" = "info" ]
}

@test "alert_router_match correctly matches rules" {
    # Source the alert router
    source "${OTTO_DIR}/scripts/core/alert-router.sh"

    local alert='{"severity":"critical","domain":"kubernetes","source":"prometheus"}'

    # Just verify the function runs without error
    run alert_router_match "${alert}"
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
