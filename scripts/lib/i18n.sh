#!/usr/bin/env bash
# OTTO - Internationalization (i18n) library
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_I18N_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_I18N_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Current loaded language
_I18N_LANGUAGE="${_I18N_LANGUAGE:-en}"

# Load a language file.
#   $1 - Language code (en, cs, de, es, fr, ja, ...)
# Falls back to English if the requested language file does not exist.
i18n_load() {
    local lang="${1:-en}"
    local lang_file="${OTTO_DIR}/i18n/${lang}.sh"
    local user_lang_file="${OTTO_HOME:-${HOME}/.config/otto}/i18n/${lang}.sh"

    # Try user override first
    if [[ -f "${user_lang_file}" ]]; then
        # shellcheck source=/dev/null
        source "${user_lang_file}"
        _I18N_LANGUAGE="${lang}"
        return 0
    fi

    # Try built-in language file
    if [[ -f "${lang_file}" ]]; then
        # shellcheck source=/dev/null
        source "${lang_file}"
        _I18N_LANGUAGE="${lang}"
        return 0
    fi

    # Fallback to English
    if [[ "${lang}" != "en" ]]; then
        local en_file="${OTTO_DIR}/i18n/en.sh"
        if [[ -f "${en_file}" ]]; then
            # shellcheck source=/dev/null
            source "${en_file}"
            _I18N_LANGUAGE="en"
        fi
    fi
}

# Get a translated string by key name.
#   $1 - Key name (e.g. "DASHBOARD_TITLE") - will be prefixed with I18N_
#   $2 - Default value if the key is not set (optional)
# Outputs the translated string or the default.
i18n_get() {
    local key="$1"
    local default="${2:-${key}}"

    local var_name="I18N_${key}"
    local value="${!var_name:-}"

    if [[ -n "${value}" ]]; then
        echo "${value}"
    else
        echo "${default}"
    fi
}

# Initialize i18n from configuration.
# Reads the language setting from config and loads the appropriate file.
i18n_init() {
    local lang="en"

    # Try to read from config if yaml_get is available
    if command -v yaml_get &>/dev/null 2>&1 || type yaml_get &>/dev/null 2>&1; then
        local config_file="${OTTO_DIR}/config/default.yaml"
        local user_config="${OTTO_HOME:-${HOME}/.config/otto}/config.yaml"

        if [[ -f "${user_config}" ]]; then
            local user_lang
            user_lang=$(yaml_get "${user_config}" ".language" "")
            if [[ -n "${user_lang}" ]]; then
                lang="${user_lang}"
            fi
        fi

        if [[ "${lang}" == "en" ]] && [[ -f "${config_file}" ]]; then
            local default_lang
            default_lang=$(yaml_get "${config_file}" ".language" "en")
            if [[ -n "${default_lang}" ]]; then
                lang="${default_lang}"
            fi
        fi
    fi

    i18n_load "${lang}"
}
