#!/usr/bin/env bash
# OTTO - Fetch GitLab MR and pipeline status
# Outputs structured JSON to stdout
# Uses: glab CLI or curl + OTTO_GITLAB_URL + OTTO_GITLAB_TOKEN
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"open_mrs":[],"pipelines_failed":[],"pipelines_running":[]}'

# Determine fetch method: glab CLI or API
USE_GLAB=false
USE_API=false

if command -v glab &>/dev/null; then
    USE_GLAB=true
elif [[ -n "${OTTO_GITLAB_URL:-}" ]] && [[ -n "${OTTO_GITLAB_TOKEN:-}" ]]; then
    USE_API=true
else
    log_debug "Neither glab nor OTTO_GITLAB_URL/OTTO_GITLAB_TOKEN available, skipping GitLab fetch"
    echo "${empty_result}"
    exit 0
fi

# Optional project filter
GITLAB_PROJECT="${OTTO_GITLAB_PROJECT:-}"

# Helper: authenticated GET request to GitLab API
gitlab_api_get() {
    local endpoint="$1"
    local url="${OTTO_GITLAB_URL%/}"
    curl -sf --max-time 15 \
        -H "PRIVATE-TOKEN: ${OTTO_GITLAB_TOKEN}" \
        "${url}/api/v4${endpoint}" 2>/dev/null
}

open_mrs="[]"
pipelines_failed="[]"
pipelines_running="[]"

if [[ "${USE_GLAB}" == "true" ]]; then
    # Use glab CLI
    log_debug "Fetching GitLab data via glab CLI"

    # Open merge requests assigned to current user
    if mr_output=$(glab mr list --assignee=@me --state=opened --output=json 2>/dev/null); then
        open_mrs=$(echo "${mr_output}" | jq '[.[] | {
            iid: .iid,
            title: .title,
            author: .author.username,
            source_branch: .source_branch,
            target_branch: .target_branch,
            created_at: .created_at,
            web_url: .web_url,
            draft: .draft,
            approvals_required: (.approvals_before_merge // 0)
        }]' 2>/dev/null) || open_mrs="[]"
    fi

    # Failed pipelines (recent)
    if pipeline_output=$(glab ci list --status=failed --output=json 2>/dev/null); then
        pipelines_failed=$(echo "${pipeline_output}" | jq '[.[0:20] | .[] | {
            id: .id,
            ref: .ref,
            status: .status,
            source: .source,
            created_at: .created_at,
            web_url: .web_url,
            user: (.user.username // "")
        }]' 2>/dev/null) || pipelines_failed="[]"
    fi

    # Running pipelines
    if pipeline_output=$(glab ci list --status=running --output=json 2>/dev/null); then
        pipelines_running=$(echo "${pipeline_output}" | jq '[.[] | {
            id: .id,
            ref: .ref,
            status: .status,
            source: .source,
            created_at: .created_at,
            web_url: .web_url,
            user: (.user.username // "")
        }]' 2>/dev/null) || pipelines_running="[]"
    fi

elif [[ "${USE_API}" == "true" ]]; then
    # Use GitLab REST API
    log_debug "Fetching GitLab data via REST API"

    if [[ -n "${GITLAB_PROJECT}" ]]; then
        # URL-encode the project path
        project_encoded="${GITLAB_PROJECT//\//%2F}"

        # Open merge requests
        if mr_response=$(gitlab_api_get "/projects/${project_encoded}/merge_requests?state=opened&per_page=50"); then
            open_mrs=$(echo "${mr_response}" | jq '[.[] | {
                iid: .iid,
                title: .title,
                author: .author.username,
                source_branch: .source_branch,
                target_branch: .target_branch,
                created_at: .created_at,
                web_url: .web_url,
                draft: (.work_in_progress // .draft // false),
                approvals_required: (.approvals_before_merge // 0)
            }]' 2>/dev/null) || open_mrs="[]"
        fi

        # Failed pipelines
        if pipe_response=$(gitlab_api_get "/projects/${project_encoded}/pipelines?status=failed&per_page=20&order_by=updated_at"); then
            pipelines_failed=$(echo "${pipe_response}" | jq '[.[] | {
                id: .id,
                ref: .ref,
                status: .status,
                source: .source,
                created_at: .created_at,
                web_url: .web_url
            }]' 2>/dev/null) || pipelines_failed="[]"
        fi

        # Running pipelines
        if pipe_response=$(gitlab_api_get "/projects/${project_encoded}/pipelines?status=running&per_page=20"); then
            pipelines_running=$(echo "${pipe_response}" | jq '[.[] | {
                id: .id,
                ref: .ref,
                status: .status,
                source: .source,
                created_at: .created_at,
                web_url: .web_url
            }]' 2>/dev/null) || pipelines_running="[]"
        fi
    else
        # No project specified - fetch MRs assigned to authenticated user
        if mr_response=$(gitlab_api_get "/merge_requests?state=opened&scope=assigned_to_me&per_page=50"); then
            open_mrs=$(echo "${mr_response}" | jq '[.[] | {
                iid: .iid,
                title: .title,
                project: .references.full,
                author: .author.username,
                source_branch: .source_branch,
                target_branch: .target_branch,
                created_at: .created_at,
                web_url: .web_url,
                draft: (.work_in_progress // .draft // false)
            }]' 2>/dev/null) || open_mrs="[]"
        fi

        log_debug "No OTTO_GITLAB_PROJECT set; pipeline data requires a project scope"
    fi
fi

# Assemble final JSON
jq -n \
    --argjson open_mrs "${open_mrs}" \
    --argjson pipelines_failed "${pipelines_failed}" \
    --argjson pipelines_running "${pipelines_running}" \
    '{
        open_mrs: $open_mrs,
        pipelines_failed: $pipelines_failed,
        pipelines_running: $pipelines_running
    }'
