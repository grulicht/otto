#!/usr/bin/env bash
# OTTO - Fetch IMAP unread email count
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"unread_count":0,"mailbox":"INBOX","connected":false}'

if [[ -z "${OTTO_IMAP_HOST:-}" || -z "${OTTO_IMAP_USER:-}" || -z "${OTTO_IMAP_PASS:-}" ]]; then
    log_debug "OTTO_IMAP_HOST, OTTO_IMAP_USER, or OTTO_IMAP_PASS not set, skipping email fetch"
    echo "${empty_result}"
    exit 0
fi

IMAP_PORT="${OTTO_IMAP_PORT:-993}"
MAILBOX="${OTTO_IMAP_MAILBOX:-INBOX}"

# Try python3 imaplib first, fall back to curl
if command -v python3 &>/dev/null; then
    unread_count=$(python3 -c "
import imaplib, sys
try:
    m = imaplib.IMAP4_SSL('${OTTO_IMAP_HOST}', ${IMAP_PORT})
    m.login('${OTTO_IMAP_USER}', '${OTTO_IMAP_PASS}')
    m.select('${MAILBOX}', readonly=True)
    _, data = m.search(None, 'UNSEEN')
    count = len(data[0].split()) if data[0] else 0
    print(count)
    m.logout()
except Exception as e:
    print(0, file=sys.stderr)
    print(0)
" 2>/dev/null) || unread_count=0
elif command -v curl &>/dev/null; then
    # Use curl with IMAP protocol
    imap_response=$(curl -s --max-time 15 \
        --url "imaps://${OTTO_IMAP_HOST}:${IMAP_PORT}/${MAILBOX}" \
        --user "${OTTO_IMAP_USER}:${OTTO_IMAP_PASS}" \
        -X "SEARCH UNSEEN" 2>/dev/null) || imap_response=""
    if [[ -n "${imap_response}" ]]; then
        # Count space-separated message IDs
        unread_count=$(echo "${imap_response}" | grep -oP '\d+' | wc -l) || unread_count=0
    else
        unread_count=0
    fi
else
    log_debug "Neither python3 nor curl found, skipping email fetch"
    echo "${empty_result}"
    exit 0
fi

connected=true
if [[ "${unread_count}" == "0" ]] && ! command -v python3 &>/dev/null && ! command -v curl &>/dev/null; then
    connected=false
fi

jq -n \
    --argjson unread_count "${unread_count}" \
    --arg mailbox "${MAILBOX}" \
    --argjson connected "${connected}" \
    '{
        unread_count: $unread_count,
        mailbox: $mailbox,
        connected: $connected
    }'
