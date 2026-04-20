#!/usr/bin/env bats
# OTTO - Trend analyzer tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    command -v jq &>/dev/null || skip "jq is required"

    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/core/trend-analyzer.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "trend_analyze_metric returns increasing for upward data" {
    local data='[
        {"timestamp": 1000000, "value": 10},
        {"timestamp": 1086400, "value": 20},
        {"timestamp": 1172800, "value": 30},
        {"timestamp": 1259200, "value": 40},
        {"timestamp": 1345600, "value": 50}
    ]'

    run trend_analyze_metric "cpu" "$data"
    [ "$status" -eq 0 ]

    local direction
    direction=$(echo "$output" | jq -r '.direction')
    [ "$direction" = "increasing" ]
}

@test "trend_analyze_metric returns decreasing for downward data" {
    local data='[
        {"timestamp": 1000000, "value": 100},
        {"timestamp": 1086400, "value": 80},
        {"timestamp": 1172800, "value": 60},
        {"timestamp": 1259200, "value": 40},
        {"timestamp": 1345600, "value": 20}
    ]'

    run trend_analyze_metric "memory" "$data"
    [ "$status" -eq 0 ]

    local direction
    direction=$(echo "$output" | jq -r '.direction')
    [ "$direction" = "decreasing" ]
}

@test "trend_analyze_metric returns stable for flat data" {
    local data='[
        {"timestamp": 1000000, "value": 50},
        {"timestamp": 1086400, "value": 50},
        {"timestamp": 1172800, "value": 50},
        {"timestamp": 1259200, "value": 50}
    ]'

    run trend_analyze_metric "disk" "$data"
    [ "$status" -eq 0 ]

    local direction
    direction=$(echo "$output" | jq -r '.direction')
    [ "$direction" = "stable" ]
}

@test "trend_anomaly_detect flags outlier in data set" {
    local data='[
        {"timestamp": 1000000, "value": 10},
        {"timestamp": 1086400, "value": 10},
        {"timestamp": 1172800, "value": 10},
        {"timestamp": 1259200, "value": 10},
        {"timestamp": 1345600, "value": 10},
        {"timestamp": 1432000, "value": 10},
        {"timestamp": 1518400, "value": 10},
        {"timestamp": 1604800, "value": 200}
    ]'

    run trend_anomaly_detect "$data" 2
    [ "$status" -eq 0 ]

    local anomaly_count
    anomaly_count=$(echo "$output" | jq '.anomaly_count')
    [ "$anomaly_count" -ge 1 ]

    local anomaly_type
    anomaly_type=$(echo "$output" | jq -r '.anomalies[0].type')
    [ "$anomaly_type" = "spike" ]
}

@test "trend_anomaly_detect returns empty anomalies for uniform data" {
    local data='[
        {"timestamp": 1000000, "value": 50},
        {"timestamp": 1086400, "value": 50},
        {"timestamp": 1172800, "value": 50},
        {"timestamp": 1259200, "value": 50}
    ]'

    run trend_anomaly_detect "$data" 2
    [ "$status" -eq 0 ]

    local anomaly_count
    anomaly_count=$(echo "$output" | jq '.anomaly_count')
    [ "$anomaly_count" -eq 0 ]
}
