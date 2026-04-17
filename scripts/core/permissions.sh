#!/usr/bin/env bash
# OTTO - Permission checking and enforcement
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_PERMISSIONS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_PERMISSIONS_LOADED=1

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

# Valid permission levels (ordered from most restrictive to least)
readonly -a _OTTO_PERM_LEVELS=(deny suggest confirm auto)

# Timeout for confirm prompts (seconds)
OTTO_CONFIRM_TIMEOUT="${OTTO_CONFIRM_TIMEOUT:-30}"

# --- Public API ---

# Determine the permission level for a given action.
#
# Resolution order (first match wins):
#   1. Domain-specific action rule:  permissions.domains.<domain>.<action>
#   2. Environment-specific rule:    permissions.environments.<environment>.default
#      (or .destructive if the action matches a destructive keyword)
#   3. Global default:               permissions.default_mode
#
#   $1 - Domain (e.g. "kubernetes", "database", "git")
#   $2 - Action (e.g. "apply", "delete", "select")
#   $3 - Environment (e.g. "production", "staging", "development") (optional)
#
# Outputs one of: deny | suggest | confirm | auto
permission_check() {
    local domain="$1"
    local action="$2"
    local environment="${3:-}"

    # 1. Check domain-specific action rule
    local domain_level
    domain_level=$(config_get ".permissions.domains.${domain}.${action}" "")
    if _is_valid_level "${domain_level}"; then
        echo "${domain_level}"
        return 0
    fi

    # 2. Check environment-specific rules
    if [[ -n "${environment}" ]]; then
        # Check if this is a destructive action and the env has a destructive override
        if _is_destructive_action "${action}"; then
            local env_destructive
            env_destructive=$(config_get ".permissions.environments.${environment}.destructive" "")
            if _is_valid_level "${env_destructive}"; then
                echo "${env_destructive}"
                return 0
            fi
        fi

        # Check environment default
        local env_default
        env_default=$(config_get ".permissions.environments.${environment}.default" "")
        if _is_valid_level "${env_default}"; then
            echo "${env_default}"
            return 0
        fi
    fi

    # 3. Fall back to global default
    local global_default
    global_default=$(config_get ".permissions.default_mode" "suggest")
    echo "${global_default}"
}

# Check and enforce the permission for an action.
# Behavior depends on the resolved permission level:
#   deny    -> log and exit 1
#   suggest -> display proposed action, wait for explicit "yes"/"approve"
#   confirm -> display "[Y/n]" prompt with timeout (default Y)
#   auto    -> proceed silently
#
#   $1 - Domain
#   $2 - Action
#   $3 - Environment (optional, pass "" to skip)
#   $4 - Human-readable description of what will happen
#
# Returns 0 if the action is permitted, 1 otherwise.
permission_enforce() {
    local domain="$1"
    local action="$2"
    local environment="${3:-}"
    local description="${4:-${domain}/${action}}"

    local level
    level=$(permission_check "${domain}" "${action}" "${environment}")

    log_debug "Permission check: ${domain}.${action} (env=${environment:-any}) -> ${level}"

    case "${level}" in
        deny)
            _enforce_deny "${domain}" "${action}" "${environment}" "${description}"
            return 1
            ;;
        suggest)
            _enforce_suggest "${domain}" "${action}" "${environment}" "${description}"
            return $?
            ;;
        confirm)
            _enforce_confirm "${domain}" "${action}" "${environment}" "${description}"
            return $?
            ;;
        auto)
            log_debug "Auto-approved: ${description}"
            return 0
            ;;
        *)
            log_warn "Unknown permission level '${level}' for ${domain}.${action}; falling back to suggest"
            _enforce_suggest "${domain}" "${action}" "${environment}" "${description}"
            return $?
            ;;
    esac
}

# Return the name of the current permission profile.
# This is the same as the config profile, since permission rules
# are part of the merged config.
permission_get_profile() {
    config_get_profile
}

# Return the global default permission mode.
permission_get_default() {
    config_get ".permissions.default_mode" "suggest"
}

# Show a human-readable explanation of why a permission is set to its level.
#   $1 - Domain
#   $2 - Action
#   $3 - Environment (optional)
permission_explain() {
    local domain="$1"
    local action="$2"
    local environment="${3:-}"

    local level
    level=$(permission_check "${domain}" "${action}" "${environment}")

    echo -e "${BOLD}Permission explanation${NC}"
    echo -e "${DIM}──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}Domain:${NC}      ${domain}"
    echo -e "  ${CYAN}Action:${NC}      ${action}"
    if [[ -n "${environment}" ]]; then
        echo -e "  ${CYAN}Environment:${NC} ${environment}"
    fi
    echo -e "  ${CYAN}Result:${NC}      $(_colorize_level "${level}")"
    echo ""

    # Trace the resolution path to explain WHY
    echo -e "${BOLD}Resolution path:${NC}"

    # Check domain rule
    local domain_level
    domain_level=$(config_get ".permissions.domains.${domain}.${action}" "")
    if _is_valid_level "${domain_level}"; then
        echo -e "  ${GREEN}[matched]${NC} permissions.domains.${domain}.${action} = ${domain_level}"
        return 0
    else
        echo -e "  ${DIM}[miss]${NC}    permissions.domains.${domain}.${action} (not set)"
    fi

    # Check environment rules
    if [[ -n "${environment}" ]]; then
        if _is_destructive_action "${action}"; then
            local env_destructive
            env_destructive=$(config_get ".permissions.environments.${environment}.destructive" "")
            if _is_valid_level "${env_destructive}"; then
                echo -e "  ${GREEN}[matched]${NC} permissions.environments.${environment}.destructive = ${env_destructive}"
                return 0
            else
                echo -e "  ${DIM}[miss]${NC}    permissions.environments.${environment}.destructive (not set)"
            fi
        fi

        local env_default
        env_default=$(config_get ".permissions.environments.${environment}.default" "")
        if _is_valid_level "${env_default}"; then
            echo -e "  ${GREEN}[matched]${NC} permissions.environments.${environment}.default = ${env_default}"
            return 0
        else
            echo -e "  ${DIM}[miss]${NC}    permissions.environments.${environment}.default (not set)"
        fi
    fi

    # Global default
    echo -e "  ${GREEN}[matched]${NC} permissions.default_mode = ${level} (global default)"
}

# --- Enforcement implementations ---

# Handle deny: log the denial and return failure.
_enforce_deny() {
    local domain="$1"
    local action="$2"
    local environment="${3:-}"
    local description="$4"

    local env_display=""
    if [[ -n "${environment}" ]]; then
        env_display=" (env: ${environment})"
    fi

    echo -e "${RED}${BOLD}DENIED${NC} ${description}${env_display}" >&2
    echo -e "${DIM}  Rule: ${domain}.${action} is set to deny${NC}" >&2
    echo -e "${DIM}  Use 'otto config' to review permission settings${NC}" >&2

    log_warn "Permission denied: ${domain}.${action}${env_display} - ${description}"
}

# Handle suggest: show the proposed action and require explicit approval.
_enforce_suggest() {
    local domain="$1"
    local action="$2"
    local environment="${3:-}"
    local description="$4"

    local env_display=""
    if [[ -n "${environment}" ]]; then
        env_display=" [env: ${environment}]"
    fi

    echo "" >&2
    echo -e "${YELLOW}${BOLD}OTTO suggests the following action:${NC}" >&2
    echo -e "${DIM}──────────────────────────────────────────${NC}" >&2
    echo -e "  ${BOLD}${description}${NC}${env_display}" >&2
    echo -e "  ${DIM}Domain: ${domain} | Action: ${action} | Mode: suggest${NC}" >&2
    echo -e "${DIM}──────────────────────────────────────────${NC}" >&2
    echo "" >&2

    # Non-interactive mode: deny by default
    if [[ ! -t 0 ]]; then
        log_warn "Non-interactive mode: suggest-level action denied (${domain}.${action})"
        echo -e "${RED}Cannot prompt in non-interactive mode; action skipped${NC}" >&2
        return 1
    fi

    local response
    echo -en "  Type ${GREEN}yes${NC} or ${GREEN}approve${NC} to proceed: " >&2
    read -r response

    case "${response}" in
        yes|Yes|YES|approve|Approve|APPROVE)
            log_info "User approved suggest-level action: ${domain}.${action} - ${description}"
            return 0
            ;;
        *)
            log_info "User rejected suggest-level action: ${domain}.${action} - ${description}"
            echo -e "${YELLOW}Action skipped.${NC}" >&2
            return 1
            ;;
    esac
}

# Handle confirm: show a Y/n prompt with a timeout.
_enforce_confirm() {
    local domain="$1"
    local action="$2"
    local environment="${3:-}"
    local description="$4"

    local env_display=""
    if [[ -n "${environment}" ]]; then
        env_display=" [env: ${environment}]"
    fi

    echo "" >&2
    echo -e "  ${BLUE}${BOLD}Confirm:${NC} ${description}${env_display}" >&2

    # Non-interactive mode: default to yes for confirm level
    if [[ ! -t 0 ]]; then
        log_info "Non-interactive mode: confirm-level action auto-approved (${domain}.${action})"
        return 0
    fi

    local response
    echo -en "  Proceed? [${GREEN}Y${NC}/n] (${OTTO_CONFIRM_TIMEOUT}s timeout, default: Y): " >&2

    if read -r -t "${OTTO_CONFIRM_TIMEOUT}" response; then
        case "${response}" in
            ""|y|Y|yes|Yes|YES)
                log_debug "User confirmed: ${domain}.${action}"
                return 0
                ;;
            n|N|no|No|NO)
                log_info "User declined confirm-level action: ${domain}.${action} - ${description}"
                echo -e "  ${YELLOW}Action skipped.${NC}" >&2
                return 1
                ;;
            *)
                log_info "Unrecognized response '${response}'; treating as decline"
                echo -e "  ${YELLOW}Action skipped.${NC}" >&2
                return 1
                ;;
        esac
    else
        # Timeout: default to Y for confirm level
        echo "" >&2
        log_debug "Confirm prompt timed out; defaulting to Y for ${domain}.${action}"
        echo -e "  ${DIM}(timeout - proceeding with default: Y)${NC}" >&2
        return 0
    fi
}

# --- Internal helpers ---

# Check if a string is a valid permission level.
_is_valid_level() {
    local level="$1"
    case "${level}" in
        deny|suggest|confirm|auto) return 0 ;;
        *) return 1 ;;
    esac
}

# Determine if an action name suggests a destructive operation.
# Used to check environment-level "destructive" overrides.
_is_destructive_action() {
    local action="$1"
    case "${action}" in
        destroy|delete|drop|force_push|reboot|revoke_access|branch_delete|execute_unsafe)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Return a color-coded string for a permission level.
_colorize_level() {
    local level="$1"
    case "${level}" in
        deny)    echo -e "${RED}${BOLD}deny${NC}" ;;
        suggest) echo -e "${YELLOW}suggest${NC}" ;;
        confirm) echo -e "${BLUE}confirm${NC}" ;;
        auto)    echo -e "${GREEN}auto${NC}" ;;
        *)       echo "${level}" ;;
    esac
}
