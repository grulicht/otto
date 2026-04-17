#!/usr/bin/env bash
# OTTO - Configuration loading and validation
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_CONFIG_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_CONFIG_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

# Path to the cached merged configuration
_OTTO_MERGED_CONFIG=""

# --- Public API ---

# Initialize OTTO_HOME directory and set default paths.
# Creates the directory structure if it does not exist.
config_init() {
    log_debug "Initializing OTTO configuration (OTTO_HOME=${OTTO_HOME})"

    mkdir -p "${OTTO_HOME}"
    mkdir -p "${OTTO_HOME}/agents"
    mkdir -p "${OTTO_HOME}/state"
    mkdir -p "${OTTO_HOME}/state/tasks"

    # Pre-create user config from default if missing
    if [[ ! -f "${OTTO_HOME}/config.yaml" ]]; then
        log_debug "No user config found; will use defaults only"
    fi
}

# Load and merge configuration files: default -> profile -> user override.
# The merged result is cached in a temporary file for the lifetime of the process.
config_load() {
    otto_require_command "yq" "pip install yq  OR  brew install yq" || return 1

    local default_config="${OTTO_DIR}/config/default.yaml"

    if [[ ! -f "${default_config}" ]]; then
        log_error "Default configuration not found: ${default_config}"
        return 1
    fi

    # Start with default config
    local merged
    merged=$(mktemp "${TMPDIR:-/tmp}/otto-config.XXXXXX")

    cp "${default_config}" "${merged}"

    # Layer profile config if a profile is set
    local profile_name
    profile_name=$(_resolve_profile_name)

    if [[ -n "${profile_name}" ]]; then
        local profile_file="${OTTO_DIR}/config/profiles/${profile_name}.yaml"
        if [[ -f "${profile_file}" ]]; then
            log_debug "Merging profile: ${profile_name}"
            local tmp_merged
            tmp_merged=$(mktemp "${TMPDIR:-/tmp}/otto-config-merge.XXXXXX")
            yaml_merge "${merged}" "${profile_file}" > "${tmp_merged}"
            mv "${tmp_merged}" "${merged}"
        else
            log_warn "Profile '${profile_name}' not found at ${profile_file}"
        fi
    fi

    # Layer user override config
    local user_config="${OTTO_HOME}/config.yaml"
    if [[ -f "${user_config}" ]]; then
        log_debug "Merging user config: ${user_config}"
        local tmp_merged
        tmp_merged=$(mktemp "${TMPDIR:-/tmp}/otto-config-merge.XXXXXX")
        yaml_merge "${merged}" "${user_config}" > "${tmp_merged}"
        mv "${tmp_merged}" "${merged}"
    fi

    # Cache the merged config
    _otto_config_cache_set "${merged}"

    log_debug "Configuration loaded and merged successfully"
}

# Read a value from the merged configuration.
#   $1 - YAML path (e.g. ".permissions.default_mode")
#   $2 - Default value if the path does not exist (optional)
config_get() {
    local path="$1"
    local default="${2:-}"

    local config_file
    config_file=$(_otto_config_cache_get)

    if [[ -z "${config_file}" ]] || [[ ! -f "${config_file}" ]]; then
        log_debug "Config not loaded yet; loading now"
        config_load
        config_file=$(_otto_config_cache_get)
    fi

    yaml_get "${config_file}" "${path}" "${default}"
}

# Update a value in the user's personal config file.
#   $1 - YAML path (e.g. ".user.experience_level")
#   $2 - Value to set
config_set() {
    local path="$1"
    local value="$2"

    local user_config="${OTTO_HOME}/config.yaml"

    # Create minimal user config if it does not exist
    if [[ ! -f "${user_config}" ]]; then
        mkdir -p "${OTTO_HOME}"
        printf '# OTTO - User Configuration Override\n' > "${user_config}"
    fi

    yaml_set "${user_config}" "${path}" "${value}"
    log_info "Updated user config: ${path} = ${value}"

    # Invalidate cache so next config_get reloads
    _otto_config_cache_invalidate
}

# Validate that the merged configuration contains required fields
# and that values are within accepted ranges.
config_validate() {
    local errors=0

    # Required: permissions.default_mode must be a known value
    local default_mode
    default_mode=$(config_get ".permissions.default_mode" "")
    case "${default_mode}" in
        deny|suggest|confirm|auto) ;;
        "")
            log_error "Missing required config: permissions.default_mode"
            errors=$((errors + 1))
            ;;
        *)
            log_error "Invalid permissions.default_mode: '${default_mode}' (expected deny|suggest|confirm|auto)"
            errors=$((errors + 1))
            ;;
    esac

    # Required: user.experience_level must be valid
    local exp_level
    exp_level=$(config_get ".user.experience_level" "")
    case "${exp_level}" in
        auto|beginner|intermediate|advanced|expert) ;;
        "")
            log_error "Missing required config: user.experience_level"
            errors=$((errors + 1))
            ;;
        *)
            log_error "Invalid user.experience_level: '${exp_level}' (expected beginner|intermediate|advanced|expert|auto)"
            errors=$((errors + 1))
            ;;
    esac

    # Required: user.role must be valid
    local role
    role=$(config_get ".user.role" "")
    case "${role}" in
        devops_engineer|sre|platform_engineer|developer|sysadmin|security_engineer|manager|student) ;;
        "")
            log_error "Missing required config: user.role"
            errors=$((errors + 1))
            ;;
        *)
            log_error "Invalid user.role: '${role}' (expected devops_engineer|sre|platform_engineer|developer|sysadmin|security_engineer|manager|student)"
            errors=$((errors + 1))
            ;;
    esac

    # Heartbeat interval must be a positive integer
    local hb_interval
    hb_interval=$(config_get ".heartbeat.interval" "0")
    if ! [[ "${hb_interval}" =~ ^[0-9]+$ ]] || [[ "${hb_interval}" -le 0 ]]; then
        log_error "Invalid heartbeat.interval: '${hb_interval}' (must be a positive integer)"
        errors=$((errors + 1))
    fi

    # Tasks WIP limit must be a positive integer
    local wip_limit
    wip_limit=$(config_get ".tasks.wip_limit" "0")
    if ! [[ "${wip_limit}" =~ ^[0-9]+$ ]] || [[ "${wip_limit}" -le 0 ]]; then
        log_error "Invalid tasks.wip_limit: '${wip_limit}' (must be a positive integer)"
        errors=$((errors + 1))
    fi

    if [[ "${errors}" -gt 0 ]]; then
        log_error "Configuration validation failed with ${errors} error(s)"
        return 1
    fi

    log_info "Configuration validation passed"
    return 0
}

# Return the name of the currently active profile.
config_get_profile() {
    _resolve_profile_name
}

# Pretty-print the current merged configuration to stdout.
config_show() {
    local config_file
    config_file=$(_otto_config_cache_get)

    if [[ -z "${config_file}" ]] || [[ ! -f "${config_file}" ]]; then
        config_load
        config_file=$(_otto_config_cache_get)
    fi

    echo -e "${BOLD}OTTO Configuration${NC}"
    echo -e "${DIM}──────────────────────────────────────────${NC}"

    local profile_name
    profile_name=$(_resolve_profile_name)
    echo -e "${CYAN}Profile:${NC}      ${profile_name:-"(none)"}"
    echo -e "${CYAN}OTTO_HOME:${NC}    ${OTTO_HOME}"
    echo -e "${CYAN}OTTO_DIR:${NC}     ${OTTO_DIR}"
    echo ""

    local user_config="${OTTO_HOME}/config.yaml"
    if [[ -f "${user_config}" ]]; then
        echo -e "${GREEN}User overrides:${NC} ${user_config}"
    else
        echo -e "${YELLOW}User overrides:${NC} (none)"
    fi
    echo ""

    echo -e "${BOLD}Merged configuration:${NC}"
    echo -e "${DIM}──────────────────────────────────────────${NC}"

    if command -v yq &>/dev/null; then
        yq eval '.' "${config_file}"
    else
        cat "${config_file}"
    fi
}

# --- Internal helpers ---

# Determine the profile name from (in priority order):
#   1. OTTO_PROFILE environment variable
#   2. .profile field in user config
#   3. Empty string (no profile)
_resolve_profile_name() {
    # Environment variable takes precedence
    if [[ -n "${OTTO_PROFILE:-}" ]]; then
        echo "${OTTO_PROFILE}"
        return 0
    fi

    # Check user config for a profile setting
    local user_config="${OTTO_HOME}/config.yaml"
    if [[ -f "${user_config}" ]]; then
        local profile
        profile=$(yaml_get "${user_config}" ".profile" "")
        if [[ -n "${profile}" ]]; then
            echo "${profile}"
            return 0
        fi
    fi

    echo ""
}

# Store the path to the merged config temp file
_otto_config_cache_set() {
    local file="$1"
    _OTTO_MERGED_CONFIG="${file}"
    export _OTTO_MERGED_CONFIG
}

# Retrieve the path to the cached merged config
_otto_config_cache_get() {
    echo "${_OTTO_MERGED_CONFIG:-}"
}

# Invalidate the config cache so the next read triggers a reload
_otto_config_cache_invalidate() {
    if [[ -n "${_OTTO_MERGED_CONFIG:-}" ]] && [[ -f "${_OTTO_MERGED_CONFIG}" ]]; then
        rm -f "${_OTTO_MERGED_CONFIG}"
    fi
    _OTTO_MERGED_CONFIG=""
}
