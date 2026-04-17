#!/usr/bin/env bash
# OTTO - Platform and tool detection

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        FreeBSD*) echo "freebsd" ;;
        *)       echo "unknown" ;;
    esac
}

# Detect if a tool is available and return its version
detect_tool() {
    local tool="$1"

    if ! command -v "${tool}" &>/dev/null; then
        return 1
    fi

    local version
    version=$("${tool}" --version 2>/dev/null | head -1 || echo "found")
    echo "${version}"
    return 0
}

# Detect all available DevOps tools and write to JSON
detect_all_tools() {
    local output_file="${1:-${OTTO_HOME}/detected-tools.json}"
    local result="{}"

    declare -A categories=(
        [iac]="terraform tofu ansible ansible-playbook"
        [cicd]="gh glab argocd"
        [containers]="docker podman kubectl helm k3s k0s"
        [cloud]="aws gcloud az doctl hcloud"
        [monitoring]="promtool logcli"
        [security]="vault trivy sops kubeseal"
        [database]="psql mysql mongosh redis-cli"
        [git]="git"
        [webserver]="nginx apache2 httpd caddy"
        [networking]="openssl certbot wg openvpn ssh rsync"
        [backup]="restic borg velero"
        [scripting]="python3 go pwsh make"
    )

    for category in "${!categories[@]}"; do
        for tool in ${categories[${category}]}; do
            if command -v "${tool}" &>/dev/null; then
                result=$(echo "${result}" | jq --arg c "${category}" --arg t "${tool}" '.[$c] += [$t]')
            fi
        done
    done

    echo "${result}" | jq '.' > "${output_file}"
    echo "${result}"
}

# Check if a specific domain has tools available
domain_has_tools() {
    local domain="$1"
    local tools_file="${OTTO_HOME}/detected-tools.json"

    if [ ! -f "${tools_file}" ]; then
        return 1
    fi

    local count
    count=$(jq -r ".${domain} | length // 0" "${tools_file}" 2>/dev/null)
    [ "${count}" -gt 0 ]
}
