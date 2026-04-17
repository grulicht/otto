#!/usr/bin/env bash
# OTTO - Check SSL certificate expiry for domains
# Outputs structured JSON to stdout
# Accepts domains from arguments, OTTO_SSL_DOMAINS env, or config file
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"certificates":[]}'

# Graceful exit if openssl is not installed
if ! command -v openssl &>/dev/null; then
    log_debug "openssl not found, skipping SSL certificate check"
    echo "${empty_result}"
    exit 0
fi

# Gather domains from multiple sources
domains=()

# 1. Command-line arguments
if [[ $# -gt 0 ]]; then
    domains+=("$@")
fi

# 2. OTTO_SSL_DOMAINS environment variable (comma or space separated)
if [[ -n "${OTTO_SSL_DOMAINS:-}" ]]; then
    IFS=', ' read -ra env_domains <<< "${OTTO_SSL_DOMAINS}"
    domains+=("${env_domains[@]}")
fi

# 3. Config file: ~/.config/otto/ssl-domains.txt (one domain per line)
ssl_config="${OTTO_HOME}/ssl-domains.txt"
if [[ -f "${ssl_config}" ]]; then
    while IFS= read -r line; do
        # Skip comments and blank lines
        line="${line%%#*}"
        line=$(echo "${line}" | xargs)
        if [[ -n "${line}" ]]; then
            domains+=("${line}")
        fi
    done < "${ssl_config}"
fi

# Deduplicate domains
if [[ ${#domains[@]} -gt 0 ]]; then
    readarray -t domains < <(printf '%s\n' "${domains[@]}" | sort -u)
fi

if [[ ${#domains[@]} -eq 0 ]]; then
    log_debug "No domains configured for SSL certificate check"
    echo "${empty_result}"
    exit 0
fi

# Warning thresholds (days)
WARN_DAYS="${OTTO_SSL_WARN_DAYS:-30}"
CRIT_DAYS="${OTTO_SSL_CRIT_DAYS:-7}"

# Check each domain
certificates="[]"

for domain in "${domains[@]}"; do
    log_debug "Checking SSL certificate for: ${domain}"

    # Extract host and optional port
    host="${domain%%:*}"
    port="${domain##*:}"
    if [[ "${port}" == "${host}" ]]; then
        port=443
    fi

    cert_info=""
    expires=""
    days_remaining=0
    issuer=""
    status="unknown"

    # Fetch certificate
    if cert_info=$(echo | openssl s_client -servername "${host}" -connect "${host}:${port}" 2>/dev/null); then
        # Extract expiry date
        expires_raw=$(echo "${cert_info}" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//') || expires_raw=""

        if [[ -n "${expires_raw}" ]]; then
            # Convert to ISO 8601
            expires=$(date -d "${expires_raw}" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || \
            expires=$(date -j -f "%b %d %H:%M:%S %Y %Z" "${expires_raw}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || \
            expires="${expires_raw}"

            # Calculate days remaining
            expires_epoch=$(date -d "${expires_raw}" +%s 2>/dev/null) || \
            expires_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "${expires_raw}" +%s 2>/dev/null) || \
            expires_epoch=0

            now_epoch=$(date +%s)
            if [[ "${expires_epoch}" -gt 0 ]]; then
                days_remaining=$(( (expires_epoch - now_epoch) / 86400 ))
            fi

            # Determine status
            if [[ "${days_remaining}" -le 0 ]]; then
                status="critical"
            elif [[ "${days_remaining}" -le "${CRIT_DAYS}" ]]; then
                status="critical"
            elif [[ "${days_remaining}" -le "${WARN_DAYS}" ]]; then
                status="warning"
            else
                status="ok"
            fi
        fi

        # Extract issuer
        issuer=$(echo "${cert_info}" | openssl x509 -noout -issuer 2>/dev/null \
            | sed 's/issuer=//; s/^[[:space:]]*//' \
            | head -1) || issuer="unknown"
    else
        log_warn "Failed to connect to ${host}:${port}"
        status="critical"
        expires="connection_failed"
        days_remaining=-1
        issuer="unknown"
    fi

    # Append to certificates array
    certificates=$(echo "${certificates}" | jq \
        --arg domain "${domain}" \
        --arg expires "${expires}" \
        --argjson days "${days_remaining}" \
        --arg issuer "${issuer}" \
        --arg status "${status}" \
        '. + [{
            domain: $domain,
            expires: $expires,
            days_remaining: $days,
            issuer: $issuer,
            status: $status
        }]' 2>/dev/null) || true
done

# Assemble final JSON
jq -n --argjson certificates "${certificates}" '{ certificates: $certificates }'
