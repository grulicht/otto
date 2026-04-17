#!/usr/bin/env bash
# OTTO - Version management

OTTO_VERSION="0.1.0"

otto_version() {
    echo "${OTTO_VERSION}"
}

otto_version_check() {
    local required="$1"
    local current="${OTTO_VERSION}"

    # Simple semver comparison (major.minor.patch)
    local req_major req_minor req_patch
    IFS='.' read -r req_major req_minor req_patch <<< "${required}"

    local cur_major cur_minor cur_patch
    IFS='.' read -r cur_major cur_minor cur_patch <<< "${current}"

    if [ "${cur_major}" -gt "${req_major}" ]; then return 0; fi
    if [ "${cur_major}" -lt "${req_major}" ]; then return 1; fi
    if [ "${cur_minor}" -gt "${req_minor}" ]; then return 0; fi
    if [ "${cur_minor}" -lt "${req_minor}" ]; then return 1; fi
    if [ "${cur_patch}" -ge "${req_patch}" ]; then return 0; fi
    return 1
}
