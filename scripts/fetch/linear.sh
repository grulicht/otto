#!/usr/bin/env bash
# OTTO - Fetch Linear issues and cycles
# Outputs structured JSON to stdout
# Uses: curl + OTTO_LINEAR_TOKEN (GraphQL API)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"my_issues":[],"active_cycle":null,"team_issues":[]}'

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    log_debug "curl or jq not found, skipping Linear fetch"
    echo "${empty_result}"
    exit 0
fi

LINEAR_TOKEN="${OTTO_LINEAR_TOKEN:-}"
if [[ -z "${LINEAR_TOKEN}" ]]; then
    log_warn "OTTO_LINEAR_TOKEN not set"
    echo "${empty_result}"
    exit 0
fi

LINEAR_API="https://api.linear.app/graphql"

linear_query() {
    local query="$1"
    curl -s --fail -X POST "${LINEAR_API}" \
        -H "Authorization: ${LINEAR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": $(echo "${query}" | jq -Rs .)}" 2>/dev/null
}

# Fetch my issues
my_issues="[]"
if response=$(linear_query '{ viewer { assignedIssues(first: 50, filter: { state: { type: { nin: ["completed","cancelled"] } } }, orderBy: updatedAt) { nodes { identifier title state { name } priority priorityLabel updatedAt url labels { nodes { name } } } } } }'); then
    my_issues=$(echo "${response}" | jq '[.data.viewer.assignedIssues.nodes[]? | {
        id: .identifier,
        title: .title,
        status: .state.name,
        priority: .priority,
        priority_label: .priorityLabel,
        updated_at: .updatedAt,
        url: .url,
        labels: [.labels.nodes[]?.name]
    }]' 2>/dev/null) || my_issues="[]"
fi

# Fetch active cycle
active_cycle="null"
TEAM_KEY="${OTTO_LINEAR_TEAM:-}"
if [[ -n "${TEAM_KEY}" ]]; then
    if response=$(linear_query "{ team(id: \"${TEAM_KEY}\") { activeCycle { id number name startsAt endsAt progress { scopeCompleted scopeTotal } } } }"); then
        active_cycle=$(echo "${response}" | jq '.data.team.activeCycle // null | if . then {
            id: .id,
            number: .number,
            name: .name,
            starts_at: .startsAt,
            ends_at: .endsAt,
            completed: .progress.scopeCompleted,
            total: .progress.scopeTotal
        } else null end' 2>/dev/null) || active_cycle="null"
    fi
fi

# Fetch team issues (open)
team_issues="[]"
if [[ -n "${TEAM_KEY}" ]]; then
    if response=$(linear_query "{ team(id: \"${TEAM_KEY}\") { issues(first: 50, filter: { state: { type: { nin: [\"completed\",\"cancelled\"] } } }, orderBy: updatedAt) { nodes { identifier title state { name } priority priorityLabel assignee { name } updatedAt } } } }"); then
        team_issues=$(echo "${response}" | jq '[.data.team.issues.nodes[]? | {
            id: .identifier,
            title: .title,
            status: .state.name,
            priority: .priority,
            priority_label: .priorityLabel,
            assignee: (.assignee.name // "Unassigned"),
            updated_at: .updatedAt
        }]' 2>/dev/null) || team_issues="[]"
    fi
fi

jq -n \
    --argjson my_issues "${my_issues}" \
    --argjson active_cycle "${active_cycle}" \
    --argjson team_issues "${team_issues}" \
    '{
        my_issues: $my_issues,
        active_cycle: $active_cycle,
        team_issues: $team_issues
    }'
