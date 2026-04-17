#!/usr/bin/env bash
# OTTO - Fetch DNS health check for configured domains
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"domains":[]}'

if ! command -v dig &>/dev/null; then
    log_debug "dig not found, skipping DNS check"
    echo "${empty_result}"
    exit 0
fi

# Read domains from config or environment
domains_list="${OTTO_DNS_DOMAINS:-}"
if [[ -z "${domains_list}" ]]; then
    log_debug "No domains configured (set OTTO_DNS_DOMAINS as comma-separated list)"
    echo "${empty_result}"
    exit 0
fi

results="[]"
IFS=',' read -ra domains <<< "${domains_list}"
for domain in "${domains[@]}"; do
    domain=$(echo "${domain}" | tr -d ' ')
    [[ -z "${domain}" ]] && continue

    a_record=$(dig +short A "${domain}" 2>/dev/null | head -1) || a_record=""
    mx_records=$(dig +short MX "${domain}" 2>/dev/null | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null) || mx_records="[]"
    spf=$(dig +short TXT "${domain}" 2>/dev/null | grep -i 'v=spf' | tr -d '"' | head -1) || spf=""
    dkim=false
    if dkim_record=$(dig +short TXT "default._domainkey.${domain}" 2>/dev/null) && [[ -n "${dkim_record}" ]]; then
        dkim=true
    fi
    dmarc=$(dig +short TXT "_dmarc.${domain}" 2>/dev/null | tr -d '"' | head -1) || dmarc=""

    entry=$(jq -n \
        --arg domain "${domain}" \
        --arg a "${a_record}" \
        --argjson mx "${mx_records}" \
        --arg spf "${spf}" \
        --argjson dkim "${dkim}" \
        --arg dmarc "${dmarc}" \
        '{domain: $domain, a_record: $a, mx_records: $mx, spf: $spf, dkim: $dkim, dmarc: $dmarc}')
    results=$(echo "${results}" | jq --argjson e "${entry}" '. + [$e]')
done

jq -n --argjson domains "${results}" '{domains: $domains}'
