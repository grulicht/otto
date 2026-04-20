#!/usr/bin/env bash
# OTTO - Fetch Jira issues and sprint status
# Outputs structured JSON to stdout
# Uses: curl + OTTO_JIRA_URL + OTTO_JIRA_EMAIL + OTTO_JIRA_TOKEN (Basic auth)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"my_issues":[],"open_issues":[],"active_sprint":null}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Jira fetch"
    echo "${empty_result}"
    exit 0
fi

if ! command -v jq &>/dev/null; then
    log_debug "jq not found, skipping Jira fetch"
    echo "${empty_result}"
    exit 0
fi

JIRA_URL="${OTTO_JIRA_URL:-}"
JIRA_EMAIL="${OTTO_JIRA_EMAIL:-}"
JIRA_TOKEN="${OTTO_JIRA_TOKEN:-}"

if [[ -z "${JIRA_URL}" || -z "${JIRA_EMAIL}" || -z "${JIRA_TOKEN}" ]]; then
    log_warn "OTTO_JIRA_URL, OTTO_JIRA_EMAIL, or OTTO_JIRA_TOKEN not set"
    echo "${empty_result}"
    exit 0
fi

AUTH=$(printf '%s:%s' "${JIRA_EMAIL}" "${JIRA_TOKEN}" | base64 -w0 2>/dev/null || printf '%s:%s' "${JIRA_EMAIL}" "${JIRA_TOKEN}" | base64 2>/dev/null)
JIRA_BASE="${JIRA_URL%/}/rest/api/3"

jira_get() {
    curl -s --fail -H "Authorization: Basic ${AUTH}" -H "Content-Type: application/json" "$1" 2>/dev/null
}

# Fetch my assigned issues
my_issues="[]"
if response=$(jira_get "${JIRA_BASE}/search?jql=assignee%3DcurrentUser()%20AND%20resolution%3DUnresolved%20ORDER%20BY%20updated%20DESC&maxResults=50&fields=key,summary,status,priority,updated,issuetype"); then
    my_issues=$(echo "${response}" | jq '[.issues[]? | {
        key: .key,
        summary: .fields.summary,
        status: .fields.status.name,
        priority: .fields.priority.name,
        type: .fields.issuetype.name,
        updated: .fields.updated
    }]' 2>/dev/null) || my_issues="[]"
fi

# Fetch open issues (recent, across project)
open_issues="[]"
JQL="${OTTO_JIRA_JQL:-resolution=Unresolved ORDER BY updated DESC}"
JQL_ENCODED=$(printf '%s' "${JQL}" | jq -sRr @uri 2>/dev/null) || JQL_ENCODED="resolution%3DUnresolved%20ORDER%20BY%20updated%20DESC"
if response=$(jira_get "${JIRA_BASE}/search?jql=${JQL_ENCODED}&maxResults=30&fields=key,summary,status,priority,updated,issuetype,assignee"); then
    open_issues=$(echo "${response}" | jq '[.issues[]? | {
        key: .key,
        summary: .fields.summary,
        status: .fields.status.name,
        priority: .fields.priority.name,
        type: .fields.issuetype.name,
        assignee: (.fields.assignee.displayName // "Unassigned"),
        updated: .fields.updated
    }]' 2>/dev/null) || open_issues="[]"
fi

# Fetch active sprint
active_sprint="null"
BOARD_ID="${OTTO_JIRA_BOARD_ID:-}"
if [[ -n "${BOARD_ID}" ]]; then
    AGILE_BASE="${JIRA_URL%/}/rest/agile/1.0"
    if response=$(jira_get "${AGILE_BASE}/board/${BOARD_ID}/sprint?state=active"); then
        active_sprint=$(echo "${response}" | jq '.values[0]? // null | if . then {
            id: .id,
            name: .name,
            state: .state,
            start_date: .startDate,
            end_date: .endDate,
            goal: (.goal // null)
        } else null end' 2>/dev/null) || active_sprint="null"
    fi
fi

jq -n \
    --argjson my_issues "${my_issues}" \
    --argjson open_issues "${open_issues}" \
    --argjson active_sprint "${active_sprint}" \
    '{
        my_issues: $my_issues,
        open_issues: $open_issues,
        active_sprint: $active_sprint
    }'
