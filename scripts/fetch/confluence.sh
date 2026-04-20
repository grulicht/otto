#!/usr/bin/env bash
# OTTO - Fetch Confluence recently modified pages and spaces
# Outputs structured JSON to stdout
# Uses: curl + OTTO_JIRA_URL (same base) + OTTO_JIRA_EMAIL + OTTO_JIRA_TOKEN (Basic auth)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"recent_pages":[],"spaces":[]}'

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    log_debug "curl or jq not found, skipping Confluence fetch"
    echo "${empty_result}"
    exit 0
fi

CONFLUENCE_URL="${OTTO_CONFLUENCE_URL:-${OTTO_JIRA_URL:-}}"
JIRA_EMAIL="${OTTO_JIRA_EMAIL:-}"
JIRA_TOKEN="${OTTO_JIRA_TOKEN:-}"

if [[ -z "${CONFLUENCE_URL}" || -z "${JIRA_EMAIL}" || -z "${JIRA_TOKEN}" ]]; then
    log_warn "OTTO_JIRA_URL/OTTO_CONFLUENCE_URL, OTTO_JIRA_EMAIL, or OTTO_JIRA_TOKEN not set"
    echo "${empty_result}"
    exit 0
fi

AUTH=$(printf '%s:%s' "${JIRA_EMAIL}" "${JIRA_TOKEN}" | base64 -w0 2>/dev/null || printf '%s:%s' "${JIRA_EMAIL}" "${JIRA_TOKEN}" | base64 2>/dev/null)
WIKI_BASE="${CONFLUENCE_URL%/}/wiki/rest/api"

confluence_get() {
    curl -s --fail -H "Authorization: Basic ${AUTH}" -H "Content-Type: application/json" "$1" 2>/dev/null
}

# Fetch recently modified pages
recent_pages="[]"
if response=$(confluence_get "${WIKI_BASE}/content?type=page&orderby=lastmodified%20desc&limit=25&expand=version,space"); then
    recent_pages=$(echo "${response}" | jq '[.results[]? | {
        id: .id,
        title: .title,
        space: .space.name,
        space_key: .space.key,
        last_modified: .version.when,
        modified_by: .version.by.displayName,
        version: .version.number
    }]' 2>/dev/null) || recent_pages="[]"
fi

# Fetch spaces
spaces="[]"
if response=$(confluence_get "${WIKI_BASE}/space?limit=50&type=global"); then
    spaces=$(echo "${response}" | jq '[.results[]? | {
        key: .key,
        name: .name,
        type: .type,
        status: .status
    }]' 2>/dev/null) || spaces="[]"
fi

jq -n \
    --argjson recent_pages "${recent_pages}" \
    --argjson spaces "${spaces}" \
    '{
        recent_pages: $recent_pages,
        spaces: $spaces
    }'
