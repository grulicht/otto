#!/usr/bin/env bats
# OTTO - Alert aggregator tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/core/alert-aggregator.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "alert_fingerprint generates consistent hash" {
    run alert_fingerprint "prometheus" "HighCPU" "node1"
    [ "$status" -eq 0 ]
    local first="$output"

    run alert_fingerprint "prometheus" "HighCPU" "node1"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
}

@test "alert_fingerprint generates different hash for different inputs" {
    run alert_fingerprint "prometheus" "HighCPU" "node1"
    [ "$status" -eq 0 ]
    local hash1="$output"

    run alert_fingerprint "prometheus" "HighCPU" "node2"
    [ "$status" -eq 0 ]
    [ "$output" != "$hash1" ]
}

@test "alert_fingerprint output is a valid md5 hex string" {
    run alert_fingerprint "src" "name" "target"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{32}$ ]]
}

@test "alert_deduplicate removes duplicate alerts" {
    local now
    now=$(date +%s)
    local fp
    fp=$(alert_fingerprint "prom" "HighCPU" "node1")

    local alerts_json
    alerts_json=$(cat <<EOF
[
  {"fingerprint": "${fp}", "timestamp": "${now}", "severity": "warning", "source": "prom", "name": "HighCPU", "target": "node1", "message": "CPU high"},
  {"fingerprint": "${fp}", "timestamp": "${now}", "severity": "warning", "source": "prom", "name": "HighCPU", "target": "node1", "message": "CPU high"}
]
EOF
    )

    run alert_deduplicate "$alerts_json"
    [ "$status" -eq 0 ]

    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" -eq 1 ]
}

@test "alert_deduplicate keeps distinct alerts" {
    local now
    now=$(date +%s)
    local fp1 fp2
    fp1=$(alert_fingerprint "prom" "HighCPU" "node1")
    fp2=$(alert_fingerprint "prom" "HighMem" "node1")

    local alerts_json
    alerts_json=$(cat <<EOF
[
  {"fingerprint": "${fp1}", "timestamp": "${now}", "severity": "warning", "source": "prom", "name": "HighCPU", "target": "node1", "message": "CPU high"},
  {"fingerprint": "${fp2}", "timestamp": "${now}", "severity": "critical", "source": "prom", "name": "HighMem", "target": "node1", "message": "Mem high"}
]
EOF
    )

    run alert_deduplicate "$alerts_json"
    [ "$status" -eq 0 ]

    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" -eq 2 ]
}
