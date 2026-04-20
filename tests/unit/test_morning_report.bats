#!/usr/bin/env bats
# OTTO - Morning report tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    mkdir -p "${OTTO_HOME}/state/night-watch"
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
    source "${OTTO_DIR}/scripts/lib/error-handling.sh"
    source "${OTTO_DIR}/scripts/core/config.sh"
    source "${OTTO_DIR}/scripts/core/morning-report.sh"

    # Create a sample log file for today
    TODAY="2025-01-15"
    cat > "${OTTO_HOME}/state/night-watch/${TODAY}.json" <<'EOF'
{
    "date": "2025-01-15",
    "started_at": "2025-01-14T22:00:00Z",
    "stopped_at": "2025-01-15T07:00:00Z",
    "entries": [
        {"timestamp": "2025-01-15T01:00:00Z", "category": "system_health", "severity": "ok", "message": "All systems nominal", "details": {}, "action_taken": null},
        {"timestamp": "2025-01-15T03:00:00Z", "category": "monitoring_alerts", "severity": "warning", "message": "High memory usage", "details": {}, "action_taken": null}
    ],
    "summary": {
        "total_checks": 5,
        "ok": 4,
        "warnings": 1,
        "critical": 0,
        "escalations": 0,
        "actions_taken": 0
    }
}
EOF
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "morning_report_format_brief returns text with status" {
    run morning_report_format_brief "${TODAY}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Morning Report"* ]]
    [[ "$output" == *"WARNINGS"* ]]
    [[ "$output" == *"Checks: 5"* ]]
}

@test "morning_report_format_executive returns text with key metrics" {
    run morning_report_format_executive "${TODAY}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Executive Report"* ]]
    [[ "$output" == *"Key Metrics"* ]]
}

@test "morning_report_generate handles missing log file gracefully" {
    run morning_report_generate "1999-01-01"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No night watch data"* ]]
}

@test "morning_report_format_brief handles missing log file" {
    run morning_report_format_brief "1999-01-01"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No data"* ]]
}
