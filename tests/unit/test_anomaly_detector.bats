#!/usr/bin/env bats
# OTTO - Anomaly detector tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state/baselines"

    source "${OTTO_DIR}/scripts/core/anomaly-detector.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "anomaly_detect_zscore returns valid JSON" {
    run anomaly_detect_zscore '[10, 12, 11, 10, 13, 11, 12, 10]'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' >/dev/null
}

@test "anomaly_detect_zscore flags obvious outlier" {
    run anomaly_detect_zscore '[10, 10, 10, 10, 10, 10, 10, 100]' 2
    [ "$status" -eq 0 ]
    local anomaly_count
    anomaly_count=$(echo "$output" | jq '.anomalies | length')
    [ "$anomaly_count" -ge 1 ]
    echo "$output" | jq -e '.anomalies[0].value == 100'
}

@test "anomaly_detect_zscore returns no anomalies for uniform data" {
    run anomaly_detect_zscore '[5, 5, 5, 5, 5]'
    [ "$status" -eq 0 ]
    local anomaly_count
    anomaly_count=$(echo "$output" | jq '.anomalies | length')
    [ "$anomaly_count" -eq 0 ]
}

@test "anomaly_detect_zscore includes mean and stddev" {
    run anomaly_detect_zscore '[10, 20, 30, 40, 50]'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.mean != null'
    echo "$output" | jq -e '.stddev != null'
}

@test "anomaly_detect_zscore handles small dataset" {
    run anomaly_detect_zscore '[1]'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.error != null'
}

@test "anomaly_detect_mad returns valid JSON" {
    run anomaly_detect_mad '[10, 12, 11, 10, 13, 11, 12, 10]'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' >/dev/null
}

@test "anomaly_detect_mad flags obvious outlier" {
    run anomaly_detect_mad '[5, 5, 5, 5, 5, 5, 5, 50]' 2
    [ "$status" -eq 0 ]
    local anomaly_count
    anomaly_count=$(echo "$output" | jq '.anomalies | length')
    [ "$anomaly_count" -ge 1 ]
}

@test "anomaly_detect_mad includes median" {
    run anomaly_detect_mad '[1, 2, 3, 4, 5]'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.median == 3'
}
