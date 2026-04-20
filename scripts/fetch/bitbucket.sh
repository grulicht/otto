#!/usr/bin/env bash
# OTTO - Fetch Bitbucket PRs and pipeline status
# Outputs structured JSON to stdout
# Uses: curl + OTTO_BITBUCKET_USER + OTTO_BITBUCKET_TOKEN (REST API v2)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"open_prs":[],"pipelines":[]}'

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    log_debug "curl or jq not found, skipping Bitbucket fetch"
    echo "${empty_result}"
    exit 0
fi

BB_USER="${OTTO_BITBUCKET_USER:-}"
BB_TOKEN="${OTTO_BITBUCKET_TOKEN:-}"
BB_WORKSPACE="${OTTO_BITBUCKET_WORKSPACE:-}"
BB_REPO="${OTTO_BITBUCKET_REPO:-}"

if [[ -z "${BB_USER}" || -z "${BB_TOKEN}" ]]; then
    log_warn "OTTO_BITBUCKET_USER or OTTO_BITBUCKET_TOKEN not set"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${BB_WORKSPACE}" || -z "${BB_REPO}" ]]; then
    log_warn "OTTO_BITBUCKET_WORKSPACE or OTTO_BITBUCKET_REPO not set"
    echo "${empty_result}"
    exit 0
fi

BB_API="https://api.bitbucket.org/2.0"

bb_get() {
    curl -s --fail -u "${BB_USER}:${BB_TOKEN}" "$1" 2>/dev/null
}

# Fetch open pull requests
open_prs="[]"
if response=$(bb_get "${BB_API}/repositories/${BB_WORKSPACE}/${BB_REPO}/pullrequests?state=OPEN&pagelen=50"); then
    open_prs=$(echo "${response}" | jq '[.values[]? | {
        id: .id,
        title: .title,
        author: .author.display_name,
        source_branch: .source.branch.name,
        destination_branch: .destination.branch.name,
        state: .state,
        created_on: .created_on,
        updated_on: .updated_on,
        url: .links.html.href,
        comment_count: .comment_count,
        task_count: .task_count
    }]' 2>/dev/null) || open_prs="[]"
fi

# Fetch recent pipelines
pipelines="[]"
if response=$(bb_get "${BB_API}/repositories/${BB_WORKSPACE}/${BB_REPO}/pipelines/?pagelen=20&sort=-created_on"); then
    pipelines=$(echo "${response}" | jq '[.values[]? | {
        uuid: .uuid,
        state: .state.name,
        result: (.state.result.name // null),
        target_branch: (.target.ref_name // null),
        trigger: .trigger.name,
        created_on: .created_on,
        completed_on: .completed_on,
        duration_seconds: .duration_in_seconds
    }]' 2>/dev/null) || pipelines="[]"
fi

jq -n \
    --argjson open_prs "${open_prs}" \
    --argjson pipelines "${pipelines}" \
    '{
        open_prs: $open_prs,
        pipelines: $pipelines
    }'
