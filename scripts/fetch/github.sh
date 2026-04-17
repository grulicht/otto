#!/usr/bin/env bash
# OTTO - Fetch GitHub PR and Actions status
# Outputs structured JSON to stdout
# Uses: gh CLI (GitHub CLI)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"open_prs":[],"failing_checks":[],"running_workflows":[]}'

# Graceful exit if gh is not installed
if ! command -v gh &>/dev/null; then
    log_debug "gh CLI not found, skipping GitHub fetch"
    echo "${empty_result}"
    exit 0
fi

# Verify gh authentication
if ! gh auth status &>/dev/null 2>&1; then
    log_warn "gh CLI not authenticated, skipping GitHub fetch"
    echo "${empty_result}"
    exit 0
fi

# Determine repository context
REPO="${OTTO_GITHUB_REPO:-}"
REPO_ARGS=()
if [[ -n "${REPO}" ]]; then
    REPO_ARGS=(--repo "${REPO}")
fi

open_prs="[]"
failing_checks="[]"
running_workflows="[]"

# Fetch open pull requests
if pr_output=$(gh pr list "${REPO_ARGS[@]}" --state open --json number,title,author,headRefName,baseRefName,createdAt,url,isDraft,reviewDecision,labels --limit 50 2>/dev/null); then
    open_prs=$(echo "${pr_output}" | jq '[.[] | {
        number: .number,
        title: .title,
        author: .author.login,
        head_branch: .headRefName,
        base_branch: .baseRefName,
        created_at: .createdAt,
        url: .url,
        draft: .isDraft,
        review_decision: (.reviewDecision // "PENDING"),
        labels: [.labels[].name]
    }]' 2>/dev/null) || open_prs="[]"
fi

# Fetch failing check runs for open PRs
if [[ "${open_prs}" != "[]" ]]; then
    failing_checks_list="[]"
    # Check the most recent PRs (limit to 10 to avoid rate limiting)
    pr_numbers=$(echo "${open_prs}" | jq -r '.[0:10] | .[].number' 2>/dev/null) || pr_numbers=""

    for pr_num in ${pr_numbers}; do
        if checks_output=$(gh pr checks "${pr_num}" "${REPO_ARGS[@]}" --json name,state,startedAt,completedAt,detailsUrl --required 2>/dev/null); then
            failed=$(echo "${checks_output}" | jq --argjson pr "${pr_num}" '[
                .[] | select(.state == "FAILURE" or .state == "ERROR") | {
                    pr: $pr,
                    name: .name,
                    state: .state,
                    started_at: .startedAt,
                    completed_at: .completedAt,
                    details_url: .detailsUrl
                }
            ]' 2>/dev/null) || failed="[]"
            failing_checks_list=$(echo "${failing_checks_list}" | jq --argjson new "${failed}" '. + $new' 2>/dev/null) || true
        fi
    done
    failing_checks="${failing_checks_list}"
fi

# Fetch running workflows
if wf_output=$(gh run list "${REPO_ARGS[@]}" --status in_progress --json databaseId,name,headBranch,event,createdAt,url,workflowName --limit 20 2>/dev/null); then
    running_workflows=$(echo "${wf_output}" | jq '[.[] | {
        id: .databaseId,
        name: .name,
        workflow: .workflowName,
        branch: .headBranch,
        event: .event,
        created_at: .createdAt,
        url: .url
    }]' 2>/dev/null) || running_workflows="[]"
fi

# Assemble final JSON
jq -n \
    --argjson open_prs "${open_prs}" \
    --argjson failing_checks "${failing_checks}" \
    --argjson running_workflows "${running_workflows}" \
    '{
        open_prs: $open_prs,
        failing_checks: $failing_checks,
        running_workflows: $running_workflows
    }'
