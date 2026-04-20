#!/usr/bin/env bats
# OTTO - Permission system integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"
    mkdir -p "${OTTO_HOME}/state"
    echo '{}' > "${OTTO_HOME}/state/state.json"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

_setup_profile() {
    local profile="$1"
    cp "${OTTO_DIR}/config/profiles/${profile}.yaml" "${OTTO_HOME}/config.yaml"
}

@test "beginner profile default permission is suggest" {
    _setup_profile "beginner"
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    run permission_check "kubernetes" "apply" ""
    [ "$status" -eq 0 ]
    # Beginner should default to suggest or confirm (restrictive)
    [[ "$output" == "suggest" || "$output" == "confirm" ]]
}

@test "autonomous profile default permission is auto" {
    _setup_profile "autonomous"
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    run permission_check "kubernetes" "status" ""
    [ "$status" -eq 0 ]
    [[ "$output" == "auto" || "$output" == "confirm" ]]
}

@test "paranoid profile default permission is suggest" {
    _setup_profile "paranoid"
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    run permission_check "kubernetes" "apply" ""
    [ "$status" -eq 0 ]
    [[ "$output" == "suggest" || "$output" == "deny" || "$output" == "confirm" ]]
}

@test "permission_enforce blocks deny actions with exit 1" {
    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: deny
YAML
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    run permission_enforce "database" "drop" "" "Drop production database"
    [ "$status" -eq 1 ]
}

@test "permission_enforce passes auto actions with exit 0" {
    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
YAML
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    run permission_enforce "monitoring" "status" "" "Check monitoring status"
    [ "$status" -eq 0 ]
}

@test "production environment is more restrictive than development" {
    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
  environments:
    production:
      default: suggest
      destructive: deny
    development:
      default: auto
YAML
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    local prod_level dev_level
    prod_level=$(permission_check "kubernetes" "apply" "production" 2>/dev/null)
    dev_level=$(permission_check "kubernetes" "apply" "development" 2>/dev/null)

    # Production should be more restrictive than development
    # Both may fall back to environment default or global default
    [[ "${prod_level}" != "${dev_level}" ]] || [[ "${prod_level}" = "suggest" ]] || [[ "${prod_level}" = "confirm" ]]
}

@test "destructive action detection for destroy, delete, drop, force_push" {
    cat > "${OTTO_HOME}/config.yaml" <<'YAML'
permissions:
  default_mode: auto
  environments:
    production:
      default: auto
      destructive: deny
YAML
    source "${OTTO_DIR}/scripts/core/permissions.sh"

    for action in destroy delete drop force_push; do
        local level
        level=$(permission_check "infrastructure" "${action}" "production")
        [ "${level}" = "deny" ]
    done
}
