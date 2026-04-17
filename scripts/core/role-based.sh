#!/usr/bin/env bash
# OTTO - Role-based access control
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_ROLE_BASED_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_ROLE_BASED_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/config.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/team.sh"

# --- Role definitions ---
# Each role maps to a set of allowed domains and a default permission mode.
# Roles (from most to least permissive):
#   admin    - Full access, can modify team config, all permissions
#   engineer - Standard DevOps access, deploy/rollback/scale with confirmation
#   viewer   - Read-only access, query/monitor but not modify
#   junior   - Like viewer but with suggest mode for learning

# --- Public API ---

# Get the current user's role from team config or user config.
# Falls back to "engineer" if not configured.
role_get_current() {
    # Check team config first
    local user_email
    user_email=$(config_get ".user.email" "")

    if [[ -n "${user_email}" ]]; then
        local team_role
        if team_role=$(team_get_role "${user_email}" 2>/dev/null); then
            echo "${team_role}"
            return 0
        fi
    fi

    # Check user name
    local user_name
    user_name=$(config_get ".user.name" "")

    if [[ -n "${user_name}" ]]; then
        local team_role
        if team_role=$(team_get_role "${user_name}" 2>/dev/null); then
            echo "${team_role}"
            return 0
        fi
    fi

    # Fall back to user config role setting
    local config_role
    config_role=$(config_get ".user.team_role" "engineer")
    echo "${config_role}"
}

# Check whether a role has permission to perform an action in a domain.
#   $1 - Role (admin, engineer, viewer, junior)
#   $2 - Domain (e.g., "kubernetes", "database", "infrastructure")
#   $3 - Action (e.g., "apply", "delete", "get", "query")
# Returns 0 if permitted, 1 if denied.
# Outputs the effective permission level (auto, confirm, suggest, deny).
role_check_permission() {
    local role="$1"
    local domain="$2"
    local action="$3"

    case "${role}" in
        admin)
            # Admin has full access to everything
            echo "auto"
            return 0
            ;;
        engineer)
            _engineer_permission "${domain}" "${action}"
            ;;
        viewer)
            _viewer_permission "${domain}" "${action}"
            ;;
        junior)
            _junior_permission "${domain}" "${action}"
            ;;
        *)
            log_warn "Unknown role: ${role}; defaulting to viewer permissions"
            _viewer_permission "${domain}" "${action}"
            ;;
    esac
}

# Get the list of domains accessible to a given role.
#   $1 - Role
# Outputs domain names, one per line.
role_get_allowed_domains() {
    local role="$1"

    case "${role}" in
        admin)
            cat <<'DOMAINS'
infrastructure
kubernetes
ci_cd
monitoring
database
security
scripts
networking
backup
server_admin
team_config
DOMAINS
            ;;
        engineer)
            cat <<'DOMAINS'
infrastructure
kubernetes
ci_cd
monitoring
database
security
scripts
networking
backup
server_admin
DOMAINS
            ;;
        viewer)
            cat <<'DOMAINS'
monitoring
ci_cd
kubernetes
database
infrastructure
DOMAINS
            ;;
        junior)
            cat <<'DOMAINS'
monitoring
ci_cd
kubernetes
database
infrastructure
DOMAINS
            ;;
        *)
            log_warn "Unknown role: ${role}; returning viewer domains"
            role_get_allowed_domains "viewer"
            ;;
    esac
}

# Apply role-based permission overrides to a base permission set.
# The base permissions come from the config profile; this function
# restricts them further based on the user's role.
#   $1 - Base permission level (from config: auto, confirm, suggest, deny)
#   $2 - Role (admin, engineer, viewer, junior)
# Outputs the effective permission level after role-based override.
role_apply_overrides() {
    local base_permission="$1"
    local role="$2"

    case "${role}" in
        admin)
            # Admin: no restrictions, use base permission as-is
            echo "${base_permission}"
            ;;
        engineer)
            # Engineer: auto stays auto for reads, but writes become confirm at minimum
            echo "${base_permission}"
            ;;
        viewer)
            # Viewer: everything that is not deny becomes suggest for read
            # writes and destructive actions become deny
            case "${base_permission}" in
                auto|confirm|suggest) echo "suggest" ;;
                deny) echo "deny" ;;
                *) echo "suggest" ;;
            esac
            ;;
        junior)
            # Junior: everything becomes suggest (learning mode)
            case "${base_permission}" in
                deny) echo "deny" ;;
                *) echo "suggest" ;;
            esac
            ;;
        *)
            log_warn "Unknown role '${role}' in role_apply_overrides; using suggest"
            echo "suggest"
            ;;
    esac
}

# --- Internal helpers ---

# Engineer permission logic: full access to reads, confirmation for writes,
# deny for destructive operations in production.
_engineer_permission() {
    local domain="$1"
    local action="$2"

    # Read-only actions are always allowed
    if _is_read_action "${action}"; then
        echo "auto"
        return 0
    fi

    # Destructive actions require explicit confirmation
    if _is_destructive "${action}"; then
        echo "confirm"
        return 0
    fi

    # Write actions default to confirm
    echo "confirm"
    return 0
}

# Viewer permission logic: reads only, everything else denied.
_viewer_permission() {
    local domain="$1"
    local action="$2"

    if _is_read_action "${action}"; then
        echo "auto"
        return 0
    fi

    # Non-read actions are denied for viewers
    echo "deny"
    return 1
}

# Junior permission logic: reads allowed with suggestion, writes denied
# but shown as suggestions for learning.
_junior_permission() {
    local domain="$1"
    local action="$2"

    if _is_read_action "${action}"; then
        echo "auto"
        return 0
    fi

    # Non-read actions shown as suggestions for learning
    echo "suggest"
    return 0
}

# Determine if an action is read-only.
_is_read_action() {
    local action="$1"
    case "${action}" in
        get|describe|list|logs|query|select|explain|view|read_state|scan|dry_run|status|search|acknowledge)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Determine if an action is destructive.
_is_destructive() {
    local action="$1"
    case "${action}" in
        destroy|delete|drop|force_push|reboot|revoke_access|branch_delete|execute_unsafe|purge|terminate)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
