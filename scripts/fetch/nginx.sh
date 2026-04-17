#!/usr/bin/env bash
# OTTO - Fetch nginx status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"running":false,"config_test":"unknown","active_connections":0,"vhosts":0,"ssl_certs":[]}'

if ! command -v nginx &>/dev/null; then
    log_debug "nginx not found, skipping nginx fetch"
    echo "${empty_result}"
    exit 0
fi

# Check if running
running=false
if pgrep -x nginx &>/dev/null; then
    running=true
fi

# Config test
config_test="failed"
if nginx -t 2>&1 | grep -q "successful"; then
    config_test="ok"
fi

# Active connections from stub_status
active_connections=0
if stub=$(curl -sf http://127.0.0.1/nginx_status 2>/dev/null || curl -sf http://127.0.0.1:8080/nginx_status 2>/dev/null); then
    active_connections=$(echo "${stub}" | grep -oP 'Active connections:\s*\K\d+' 2>/dev/null) || active_connections=0
fi

# Count vhosts
vhosts=0
for dir in /etc/nginx/sites-enabled /etc/nginx/conf.d; do
    if [[ -d "${dir}" ]]; then
        count=$(find "${dir}" -type f -name '*.conf' -o -type l 2>/dev/null | wc -l | tr -d ' ')
        vhosts=$((vhosts + count))
    fi
done

# SSL certs
ssl_certs="[]"
cert_files=$(grep -rh 'ssl_certificate ' /etc/nginx/ 2>/dev/null | grep -oP '(?<=ssl_certificate\s)\S+' | tr -d ';' | sort -u) || cert_files=""
if [[ -n "${cert_files}" ]] && command -v openssl &>/dev/null; then
    certs_json="["
    first=true
    while IFS= read -r cert; do
        [[ -z "${cert}" ]] && continue
        [[ ! -f "${cert}" ]] && continue
        expiry=$(openssl x509 -enddate -noout -in "${cert}" 2>/dev/null | cut -d= -f2) || continue
        subject=$(openssl x509 -subject -noout -in "${cert}" 2>/dev/null | sed 's/subject=//' | tr -d ' ') || subject="unknown"
        if [[ "${first}" == "true" ]]; then
            first=false
        else
            certs_json+=","
        fi
        certs_json+="{\"file\":\"${cert}\",\"subject\":\"${subject}\",\"expiry\":\"${expiry}\"}"
    done <<< "${cert_files}"
    certs_json+="]"
    ssl_certs=$(echo "${certs_json}" | jq '.' 2>/dev/null) || ssl_certs="[]"
fi

jq -n \
    --argjson running "${running}" \
    --arg config_test "${config_test}" \
    --argjson connections "${active_connections}" \
    --argjson vhosts "${vhosts}" \
    --argjson ssl "${ssl_certs}" \
    '{
        running: $running,
        config_test: $config_test,
        active_connections: $connections,
        vhosts: $vhosts,
        ssl_certs: $ssl
    }'
