#!/usr/bin/env bash
# OTTO - Fetch Hetzner Cloud infrastructure status
# Outputs structured JSON to stdout
# Uses: hcloud CLI or curl + HETZNER_TOKEN
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"servers":[],"volumes":[],"networks":[],"floating_ips":[]}'

HETZNER_TOKEN="${HETZNER_TOKEN:-}"
USE_CLI=false

if command -v hcloud &>/dev/null && hcloud server list &>/dev/null 2>&1; then
    USE_CLI=true
elif [[ -n "${HETZNER_TOKEN}" ]] && command -v curl &>/dev/null && command -v jq &>/dev/null; then
    USE_CLI=false
else
    log_debug "Neither hcloud CLI nor HETZNER_TOKEN available, skipping Hetzner fetch"
    echo "${empty_result}"
    exit 0
fi

hetzner_api_get() {
    curl -s --fail -H "Authorization: Bearer ${HETZNER_TOKEN}" "https://api.hetzner.cloud/v1$1" 2>/dev/null
}

servers="[]"
volumes="[]"
networks="[]"
floating_ips="[]"

if [[ "${USE_CLI}" == "true" ]]; then
    if output=$(hcloud server list -o json 2>/dev/null); then
        servers=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            name: .name,
            status: .status,
            server_type: .server_type.name,
            datacenter: .datacenter.name,
            ip: .public_net.ipv4.ip,
            ipv6: .public_net.ipv6.ip,
            created: .created
        }]' 2>/dev/null) || servers="[]"
    fi

    if output=$(hcloud volume list -o json 2>/dev/null); then
        volumes=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            name: .name,
            size: .size,
            server: (.server // null),
            location: .location.name,
            status: .status,
            created: .created
        }]' 2>/dev/null) || volumes="[]"
    fi

    if output=$(hcloud network list -o json 2>/dev/null); then
        networks=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            name: .name,
            ip_range: .ip_range,
            subnets: [.subnets[]?.ip_range],
            server_count: (.servers | length),
            created: .created
        }]' 2>/dev/null) || networks="[]"
    fi

    if output=$(hcloud floating-ip list -o json 2>/dev/null); then
        floating_ips=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            ip: .ip,
            type: .type,
            server: (.server // null),
            location: .home_location.name,
            blocked: .blocked,
            created: .created
        }]' 2>/dev/null) || floating_ips="[]"
    fi
else
    if response=$(hetzner_api_get "/servers?per_page=50"); then
        servers=$(echo "${response}" | jq '[.servers[]? | {
            id: .id,
            name: .name,
            status: .status,
            server_type: .server_type.name,
            datacenter: .datacenter.name,
            ip: .public_net.ipv4.ip,
            ipv6: .public_net.ipv6.ip,
            created: .created
        }]' 2>/dev/null) || servers="[]"
    fi

    if response=$(hetzner_api_get "/volumes?per_page=50"); then
        volumes=$(echo "${response}" | jq '[.volumes[]? | {
            id: .id,
            name: .name,
            size: .size,
            server: (.server // null),
            location: .location.name,
            status: .status,
            created: .created
        }]' 2>/dev/null) || volumes="[]"
    fi

    if response=$(hetzner_api_get "/networks?per_page=50"); then
        networks=$(echo "${response}" | jq '[.networks[]? | {
            id: .id,
            name: .name,
            ip_range: .ip_range,
            subnets: [.subnets[]?.ip_range],
            server_count: (.servers | length),
            created: .created
        }]' 2>/dev/null) || networks="[]"
    fi

    if response=$(hetzner_api_get "/floating_ips?per_page=50"); then
        floating_ips=$(echo "${response}" | jq '[.floating_ips[]? | {
            id: .id,
            ip: .ip,
            type: .type,
            server: (.server // null),
            location: .home_location.name,
            blocked: .blocked,
            created: .created
        }]' 2>/dev/null) || floating_ips="[]"
    fi
fi

jq -n \
    --argjson servers "${servers}" \
    --argjson volumes "${volumes}" \
    --argjson networks "${networks}" \
    --argjson floating_ips "${floating_ips}" \
    '{
        servers: $servers,
        volumes: $volumes,
        networks: $networks,
        floating_ips: $floating_ips
    }'
