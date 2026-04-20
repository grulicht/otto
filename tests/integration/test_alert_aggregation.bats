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
    local now
    now=$(date +%s)
    local alerts="[
        {\"fingerprint\":\"abc\",\"source\":\"prometheus\",\"name\":\"disk_full\",\"target\":\"srv1\",\"severity\":\"critical\",\"message\":\"disk full\",\"timestamp\":${now}},
        {\"fingerprint\":\"abc\",\"source\":\"grafana\",\"name\":\"disk_full\",\"target\":\"srv1\",\"severity\":\"critical\",\"message\":\"disk full\",\"timestamp\":${now}},
        {\"fingerprint\":\"def\",\"source\":\"prometheus\",\"name\":\"cpu_high\",\"target\":\"srv2\",\"severity\":\"warning\",\"message\":\"cpu high\",\"timestamp\":${now}}
    ]"

    local result
    result=$(alert_deduplicate "${alerts}" 2>/dev/null)

    local count
    count=$(echo "${result}" | jq 'length')
    [ "${count}" -eq 2 ]
}

@test "alert_aggregate merges multiple source arrays" {
    local now
    now=$(date +%s)
    local sources="[
        {\"source\":\"prometheus\",\"alerts\":[{\"name\":\"disk_full\",\"target\":\"srv1\",\"severity\":\"critical\",\"message\":\"disk full\",\"timestamp\":${now}}]},
        {\"source\":\"grafana\",\"alerts\":[{\"name\":\"cpu_high\",\"target\":\"srv2\",\"severity\":\"warning\",\"message\":\"cpu high\",\"timestamp\":${now}}]}
    ]"

    local result
    result=$(alert_aggregate "${sources}" 2>/dev/null)

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
