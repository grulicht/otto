#!/usr/bin/env bash
# OTTO - Plugin/Extension System
# Manages installation, validation, and loading of OTTO plugins
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_PLUGIN_MANAGER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_PLUGIN_MANAGER_LOADED=1

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
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

# Plugin directory
OTTO_PLUGINS_DIR="${OTTO_HOME}/plugins"

# Required fields in plugin.yaml
readonly -a _PLUGIN_REQUIRED_FIELDS=(name version)

# --- Public API ---

# List installed plugins from ~/.config/otto/plugins/
# Outputs a table of name, version, description for each installed plugin.
plugin_list() {
    local plugins_dir="${OTTO_PLUGINS_DIR}"

    if [[ ! -d "${plugins_dir}" ]]; then
        log_info "No plugins directory found. Run 'plugin_install' to install your first plugin."
        return 0
    fi

    local found=0
    printf "${COLOR_BOLD}%-25s %-12s %-15s %s${COLOR_RESET}\n" "NAME" "VERSION" "TYPE" "DESCRIPTION"
    printf "%s\n" "$(printf '%.0s-' {1..80})"

    for plugin_dir in "${plugins_dir}"/*/; do
        [[ -d "${plugin_dir}" ]] || continue
        local yaml_file="${plugin_dir}plugin.yaml"
        if [[ ! -f "${yaml_file}" ]]; then
            continue
        fi

        local name version description plugin_type
        name=$(yaml_get "${yaml_file}" "name" "unknown")
        version=$(yaml_get "${yaml_file}" "version" "0.0.0")
        description=$(yaml_get "${yaml_file}" "description" "")
        plugin_type=$(yaml_get "${yaml_file}" "type" "general")

        printf "%-25s %-12s %-15s %s\n" "${name}" "${version}" "${plugin_type}" "${description}"
        found=$((found + 1))
    done

    if [[ ${found} -eq 0 ]]; then
        log_info "No plugins installed."
    else
        log_info "Total: ${found} plugin(s) installed."
    fi
}

# Install plugin from git URL or local path.
# Clones to plugins dir, validates structure (must have plugin.yaml with name, version, type).
#   $1 - Source: git URL or local path
plugin_install() {
    local source="${1:?Usage: plugin_install <git_url_or_path>}"

    mkdir -p "${OTTO_PLUGINS_DIR}"

    local install_dir=""
    local tmp_dir=""

    # Determine if source is a git URL or local path
    if [[ "${source}" =~ ^(https?://|git@|ssh://) ]]; then
        log_info "Installing plugin from git: ${source}"
        local repo_name
        repo_name=$(basename "${source}" .git)
        install_dir="${OTTO_PLUGINS_DIR}/${repo_name}"

        if [[ -d "${install_dir}" ]]; then
            log_error "Plugin directory already exists: ${install_dir}"
            log_info "Use 'plugin_update ${repo_name}' to update, or 'plugin_uninstall ${repo_name}' first."
            return 1
        fi

        if ! git clone --depth 1 "${source}" "${install_dir}" 2>/dev/null; then
            log_error "Failed to clone repository: ${source}"
            return 1
        fi
    elif [[ -d "${source}" ]]; then
        log_info "Installing plugin from local path: ${source}"
        local dir_name
        dir_name=$(basename "${source}")
        install_dir="${OTTO_PLUGINS_DIR}/${dir_name}"

        if [[ -d "${install_dir}" ]]; then
            log_error "Plugin directory already exists: ${install_dir}"
            return 1
        fi

        cp -r "${source}" "${install_dir}"
    else
        log_error "Source is neither a valid git URL nor an existing directory: ${source}"
        return 1
    fi

    # Validate the installed plugin
    if ! plugin_validate "${install_dir}"; then
        log_error "Plugin validation failed. Removing invalid plugin."
        rm -rf "${install_dir}"
        return 1
    fi

    local name
    name=$(yaml_get "${install_dir}/plugin.yaml" "name" "unknown")
    log_info "Plugin '${name}' installed successfully to ${install_dir}"
}

# Remove installed plugin
#   $1 - Plugin name (directory name under plugins/)
plugin_uninstall() {
    local name="${1:?Usage: plugin_uninstall <plugin_name>}"
    local plugin_dir="${OTTO_PLUGINS_DIR}/${name}"

    if [[ ! -d "${plugin_dir}" ]]; then
        log_error "Plugin not found: ${name}"
        return 1
    fi

    local display_name
    display_name=$(yaml_get "${plugin_dir}/plugin.yaml" "name" "${name}")

    rm -rf "${plugin_dir}"
    log_info "Plugin '${display_name}' uninstalled successfully."
}

# Git pull latest version of a plugin
#   $1 - Plugin name (directory name under plugins/)
plugin_update() {
    local name="${1:?Usage: plugin_update <plugin_name>}"
    local plugin_dir="${OTTO_PLUGINS_DIR}/${name}"

    if [[ ! -d "${plugin_dir}" ]]; then
        log_error "Plugin not found: ${name}"
        return 1
    fi

    if [[ ! -d "${plugin_dir}/.git" ]]; then
        log_warn "Plugin '${name}' is not a git repository. Cannot update."
        return 1
    fi

    log_info "Updating plugin '${name}'..."
    if (cd "${plugin_dir}" && git pull --ff-only 2>/dev/null); then
        # Re-validate after update
        if plugin_validate "${plugin_dir}"; then
            log_info "Plugin '${name}' updated successfully."
        else
            log_warn "Plugin '${name}' updated but validation failed. Check plugin structure."
        fi
    else
        log_error "Failed to update plugin '${name}'. Check git remote configuration."
        return 1
    fi
}

# Update all installed plugins
plugin_update_all() {
    local plugins_dir="${OTTO_PLUGINS_DIR}"

    if [[ ! -d "${plugins_dir}" ]]; then
        log_info "No plugins installed."
        return 0
    fi

    local count=0
    local failed=0

    for plugin_dir in "${plugins_dir}"/*/; do
        [[ -d "${plugin_dir}" ]] || continue
        local name
        name=$(basename "${plugin_dir}")

        if [[ -d "${plugin_dir}/.git" ]]; then
            if plugin_update "${name}"; then
                count=$((count + 1))
            else
                failed=$((failed + 1))
            fi
        else
            log_debug "Skipping non-git plugin: ${name}"
        fi
    done

    log_info "Updated ${count} plugin(s). ${failed} failed."
}

# Validate plugin structure
# Checks that plugin.yaml exists and contains required fields (name, version).
#   $1 - Path to plugin directory
plugin_validate() {
    local path="${1:?Usage: plugin_validate <plugin_path>}"
    local yaml_file="${path}/plugin.yaml"

    if [[ ! -d "${path}" ]]; then
        log_error "Plugin path does not exist: ${path}"
        return 1
    fi

    if [[ ! -f "${yaml_file}" ]]; then
        log_error "Missing plugin.yaml in: ${path}"
        return 1
    fi

    local errors=0

    for field in "${_PLUGIN_REQUIRED_FIELDS[@]}"; do
        local value
        value=$(yaml_get "${yaml_file}" "${field}" "")
        if [[ -z "${value}" ]]; then
            log_error "Missing required field '${field}' in plugin.yaml"
            errors=$((errors + 1))
        fi
    done

    if [[ ${errors} -gt 0 ]]; then
        return 1
    fi

    log_debug "Plugin validation passed: ${path}"
    return 0
}

# Load all installed plugins
# Copies agents, sources, knowledge, and fetch/action scripts to appropriate OTTO locations.
plugin_load_all() {
    local plugins_dir="${OTTO_PLUGINS_DIR}"

    if [[ ! -d "${plugins_dir}" ]]; then
        log_debug "No plugins directory, nothing to load."
        return 0
    fi

    local loaded=0

    for plugin_dir in "${plugins_dir}"/*/; do
        [[ -d "${plugin_dir}" ]] || continue

        local name
        name=$(yaml_get "${plugin_dir}/plugin.yaml" "name" "$(basename "${plugin_dir}")" 2>/dev/null || basename "${plugin_dir}")

        if ! plugin_validate "${plugin_dir}" 2>/dev/null; then
            log_warn "Skipping invalid plugin: ${name}"
            continue
        fi

        log_debug "Loading plugin: ${name}"

        # Copy agents to user agents directory
        if [[ -d "${plugin_dir}/agents" ]]; then
            mkdir -p "${OTTO_HOME}/agents"
            cp -r "${plugin_dir}/agents/"* "${OTTO_HOME}/agents/" 2>/dev/null || true
            log_debug "  Loaded agents from ${name}"
        fi

        # Copy sources to user config
        if [[ -d "${plugin_dir}/sources" ]]; then
            mkdir -p "${OTTO_HOME}/sources"
            cp -r "${plugin_dir}/sources/"* "${OTTO_HOME}/sources/" 2>/dev/null || true
            log_debug "  Loaded sources from ${name}"
        fi

        # Copy knowledge files
        if [[ -d "${plugin_dir}/knowledge" ]]; then
            mkdir -p "${OTTO_HOME}/knowledge"
            cp -r "${plugin_dir}/knowledge/"* "${OTTO_HOME}/knowledge/" 2>/dev/null || true
            log_debug "  Loaded knowledge from ${name}"
        fi

        # Copy fetch scripts
        if [[ -d "${plugin_dir}/scripts/fetch" ]]; then
            mkdir -p "${OTTO_HOME}/scripts/fetch"
            cp -r "${plugin_dir}/scripts/fetch/"* "${OTTO_HOME}/scripts/fetch/" 2>/dev/null || true
            chmod +x "${OTTO_HOME}/scripts/fetch/"* 2>/dev/null || true
            log_debug "  Loaded fetch scripts from ${name}"
        fi

        # Copy action scripts
        if [[ -d "${plugin_dir}/scripts/actions" ]]; then
            mkdir -p "${OTTO_HOME}/scripts/actions"
            cp -r "${plugin_dir}/scripts/actions/"* "${OTTO_HOME}/scripts/actions/" 2>/dev/null || true
            chmod +x "${OTTO_HOME}/scripts/actions/"* 2>/dev/null || true
            log_debug "  Loaded action scripts from ${name}"
        fi

        loaded=$((loaded + 1))
    done

    log_info "Loaded ${loaded} plugin(s)."
}

# Show detailed plugin information
#   $1 - Plugin name (directory name under plugins/)
plugin_info() {
    local name="${1:?Usage: plugin_info <plugin_name>}"
    local plugin_dir="${OTTO_PLUGINS_DIR}/${name}"

    if [[ ! -d "${plugin_dir}" ]]; then
        log_error "Plugin not found: ${name}"
        return 1
    fi

    local yaml_file="${plugin_dir}/plugin.yaml"
    if [[ ! -f "${yaml_file}" ]]; then
        log_error "Plugin is missing plugin.yaml: ${name}"
        return 1
    fi

    local p_name p_version p_description p_author p_type
    p_name=$(yaml_get "${yaml_file}" "name" "unknown")
    p_version=$(yaml_get "${yaml_file}" "version" "0.0.0")
    p_description=$(yaml_get "${yaml_file}" "description" "No description")
    p_author=$(yaml_get "${yaml_file}" "author" "Unknown")
    p_type=$(yaml_get "${yaml_file}" "type" "general")

    echo ""
    echo "${COLOR_BOLD}Plugin: ${p_name}${COLOR_RESET}"
    echo "  Version:     ${p_version}"
    echo "  Type:        ${p_type}"
    echo "  Author:      ${p_author}"
    echo "  Description: ${p_description}"
    echo "  Location:    ${plugin_dir}"
    echo ""

    # Show contents
    echo "${COLOR_BOLD}Contents:${COLOR_RESET}"
    [[ -d "${plugin_dir}/agents" ]]          && echo "  agents/         $(ls "${plugin_dir}/agents/" 2>/dev/null | wc -l) file(s)"
    [[ -d "${plugin_dir}/sources" ]]         && echo "  sources/        $(ls "${plugin_dir}/sources/" 2>/dev/null | wc -l) file(s)"
    [[ -d "${plugin_dir}/knowledge" ]]       && echo "  knowledge/      $(ls "${plugin_dir}/knowledge/" 2>/dev/null | wc -l) file(s)"
    [[ -d "${plugin_dir}/scripts/fetch" ]]   && echo "  scripts/fetch/  $(ls "${plugin_dir}/scripts/fetch/" 2>/dev/null | wc -l) file(s)"
    [[ -d "${plugin_dir}/scripts/actions" ]] && echo "  scripts/actions/ $(ls "${plugin_dir}/scripts/actions/" 2>/dev/null | wc -l) file(s)"

    # Git info if available
    if [[ -d "${plugin_dir}/.git" ]]; then
        echo ""
        echo "${COLOR_BOLD}Git Info:${COLOR_RESET}"
        local remote branch last_commit
        remote=$(cd "${plugin_dir}" && git remote get-url origin 2>/dev/null || echo "N/A")
        branch=$(cd "${plugin_dir}" && git branch --show-current 2>/dev/null || echo "N/A")
        last_commit=$(cd "${plugin_dir}" && git log -1 --format="%h %s (%cr)" 2>/dev/null || echo "N/A")
        echo "  Remote:      ${remote}"
        echo "  Branch:      ${branch}"
        echo "  Last commit: ${last_commit}"
    fi
    echo ""
}

# --- CLI entrypoint ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    action="${1:-help}"
    shift || true

    case "${action}" in
        list)      plugin_list ;;
        install)   plugin_install "$@" ;;
        uninstall) plugin_uninstall "$@" ;;
        update)
            if [[ $# -eq 0 ]]; then
                plugin_update_all
            else
                plugin_update "$@"
            fi
            ;;
        validate)  plugin_validate "$@" ;;
        load)      plugin_load_all ;;
        info)      plugin_info "$@" ;;
        help|*)
            cat <<EOF
Usage: $(basename "$0") <action> [arguments]

Actions:
    list                    List installed plugins
    install <source>        Install plugin from git URL or local path
    uninstall <name>        Remove installed plugin
    update [name]           Update plugin (or all if no name given)
    validate <path>         Validate plugin structure
    load                    Load all plugins into OTTO
    info <name>             Show plugin details
    help                    Show this help
EOF
            ;;
    esac
fi
