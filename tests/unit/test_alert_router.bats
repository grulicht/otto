#!/usr/bin/env bats
# OTTO - Alert router tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"

    source "${OTTO_DIR}/scripts/core/alert-router.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "alert_router_match matches alert with matching severity" {
    local alert='{"severity":"critical","domain":"kubernetes"}'
    local rule='{"match":{"severity":"critical"},"targets":["slack"]}'

    run alert_router_match "$alert" "$rule"
    [ "$status" -eq 0 ]
}

@test "alert_router_match rejects non-matching severity" {
    local alert='{"severity":"warning","domain":"kubernetes"}'
    local rule='{"match":{"severity":"critical"},"targets":["slack"]}'

    run alert_router_match "$alert" "$rule"
    [ "$status" -ne 0 ]
}

@test "alert_router_match matches multi-field rule" {
    local alert='{"severity":"critical","domain":"security"}'
    local rule='{"match":{"severity":"critical","domain":"security"},"targets":["pagerduty"]}'

    run alert_router_match "$alert" "$rule"
    [ "$status" -eq 0 ]
}

@test "alert_router_match fails when one field mismatches" {
    local alert='{"severity":"critical","domain":"backup"}'
    local rule='{"match":{"severity":"critical","domain":"security"},"targets":["pagerduty"]}'

    run alert_router_match "$alert" "$rule"
    [ "$status" -ne 0 ]
}

@test "alert_router_match matches wildcard rule with empty match" {
    local alert='{"severity":"info","domain":"monitoring"}'
    local rule='{"match":{},"targets":["email"]}'

    run alert_router_match "$alert" "$rule"
    [ "$status" -eq 0 ]
}

@test "alert_route returns targets as JSON array" {
    # Create a config with routing rules
    cat > "${OTTO_HOME}/config.yaml" << 'EOF'
alert_routing:
  enabled: true
  default_targets:
    - email
  rules:
    - match:
        severity: critical
      targets:
        - pagerduty
        - slack
EOF

    _ALERT_ROUTING_RULES=""
    alert_router_load_rules

    local alert='{"severity":"critical","domain":"infra"}'
    run alert_route "$alert"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' >/dev/null
    [[ "$output" == *"pagerduty"* ]]
}
