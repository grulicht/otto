#!/usr/bin/env bash
# OTTO - Incident creation helper
# Creates an incident task and sends notifications via configured channels
# Usage: incident-create.sh --title <title> --severity <sev> --description <desc> [--dry-run]
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/permissions.sh"

TITLE=""
SEVERITY=""
DESCRIPTION=""
DRY_RUN=false
ENVIRONMENT=""
ASSIGNEE=""
CHANNEL=""
NOTIFY_SLACK=false
NOTIFY_TELEGRAM=false
NOTIFY_JIRA=false
NOTIFY_GRAFANA=false

OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"
OTTO_STATE_DIR="${OTTO_HOME}/state"
OTTO_TASKS_DIR="${OTTO_STATE_DIR}/tasks"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create an incident with notifications.

Options:
    --title <title>         Incident title (required)
    --severity <sev>        Severity: critical, high, medium, low (required)
    --description <desc>    Incident description (required)
    --environment <env>     Affected environment (optional)
    --assignee <person>     Person to assign (optional)
    --channel <channel>     Notification channel override (optional)
    --notify-slack          Send Slack notification
    --notify-telegram       Send Telegram notification
    --notify-jira           Create Jira issue
    --notify-grafana        Create Grafana Incident
    --dry-run               Preview without creating
    -h, --help              Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)           TITLE="$2"; shift 2 ;;
            --severity)        SEVERITY="$2"; shift 2 ;;
            --description)     DESCRIPTION="$2"; shift 2 ;;
            --environment)     ENVIRONMENT="$2"; shift 2 ;;
            --assignee)        ASSIGNEE="$2"; shift 2 ;;
            --channel)         CHANNEL="$2"; shift 2 ;;
            --notify-slack)    NOTIFY_SLACK=true; shift ;;
            --notify-telegram) NOTIFY_TELEGRAM=true; shift ;;
            --notify-jira)     NOTIFY_JIRA=true; shift ;;
            --notify-grafana)  NOTIFY_GRAFANA=true; shift ;;
            --dry-run)         DRY_RUN=true; shift ;;
            -h|--help)         usage; exit 0 ;;
            *)                 log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${TITLE}" ]] || [[ -z "${SEVERITY}" ]] || [[ -z "${DESCRIPTION}" ]]; then
        log_error "Missing required arguments: --title, --severity, and --description are required"
        usage
        exit 1
    fi

    case "${SEVERITY}" in
        critical|high|medium|low) ;;
        *) log_error "Invalid severity: ${SEVERITY}. Use: critical, high, medium, low"; exit 1 ;;
    esac

    # Auto-detect notification channels if none explicitly set
    local any_explicit=false
    [[ "${NOTIFY_SLACK}" == "true" || "${NOTIFY_TELEGRAM}" == "true" || "${NOTIFY_JIRA}" == "true" || "${NOTIFY_GRAFANA}" == "true" ]] && any_explicit=true

    if [[ "${any_explicit}" == "false" ]]; then
        [[ -n "${OTTO_SLACK_TOKEN:-}" ]] && NOTIFY_SLACK=true
        [[ -n "${OTTO_TELEGRAM_TOKEN:-}" ]] && NOTIFY_TELEGRAM=true
    fi
}

generate_incident_id() {
    echo "INC-$(date +%Y%m%d)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' ')"
}

create_task() {
    local incident_id="$1"

    mkdir -p "${OTTO_TASKS_DIR}/triage"

    local task_file="${OTTO_TASKS_DIR}/triage/${incident_id}.json"

    jq -n \
        --arg id "${incident_id}" \
        --arg title "${TITLE}" \
        --arg severity "${SEVERITY}" \
        --arg description "${DESCRIPTION}" \
        --arg environment "${ENVIRONMENT:-}" \
        --arg assignee "${ASSIGNEE:-}" \
        --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            id: $id,
            type: "incident",
            title: $title,
            severity: $severity,
            description: $description,
            environment: $environment,
            assignee: $assignee,
            status: "triage",
            created: $created,
            notifications: [],
            updates: []
        }' > "${task_file}"

    log_info "Created incident task: ${task_file}"
}

notify_slack() {
    local incident_id="$1"
    local token="${OTTO_SLACK_TOKEN:-}"

    if [[ -z "${token}" ]]; then
        log_warn "OTTO_SLACK_TOKEN not set, skipping Slack notification"
        return 1
    fi

    local channel="${CHANNEL:-#ops-incidents}"
    local env_line=""
    [[ -n "${ENVIRONMENT}" ]] && env_line="\n*Environment:* ${ENVIRONMENT}"
    local text="*INCIDENT: ${TITLE}*\n*ID:* ${incident_id}\n*Severity:* ${SEVERITY}${env_line}\n\n${DESCRIPTION}"

    curl -sf -X POST -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg channel "${channel}" --arg text "${text}" \
            '{channel: $channel, text: $text, unfurl_links: false}')" \
        "https://slack.com/api/chat.postMessage" | jq -r '.ok' 2>/dev/null || {
        log_warn "Slack notification failed"
        return 1
    }

    log_info "Slack notification sent to ${channel}"
}

notify_telegram() {
    local incident_id="$1"
    local token="${OTTO_TELEGRAM_TOKEN:-}"
    local chat_id="${OTTO_TELEGRAM_CHAT_ID:-}"

    if [[ -z "${token}" ]] || [[ -z "${chat_id}" ]]; then
        log_warn "Telegram not configured, skipping notification"
        return 1
    fi

    local env_line=""
    [[ -n "${ENVIRONMENT}" ]] && env_line="\n<i>Environment:</i> ${ENVIRONMENT}"
    local text="<b>[${SEVERITY^^}] INCIDENT: ${TITLE}</b>\n<i>ID:</i> ${incident_id}${env_line}\n\n${DESCRIPTION}"

    curl -sf -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg chat_id "${chat_id}" --arg text "${text}" \
            '{chat_id: $chat_id, text: $text, parse_mode: "HTML"}')" | \
        jq -r '.ok' 2>/dev/null || {
        log_warn "Telegram notification failed"
        return 1
    }

    log_info "Telegram notification sent"
}

notify_jira() {
    local incident_id="$1"
    local url="${OTTO_JIRA_URL:-}"
    local email="${OTTO_JIRA_EMAIL:-}"
    local token="${OTTO_JIRA_TOKEN:-}"

    if [[ -z "${url}" ]] || [[ -z "${email}" ]] || [[ -z "${token}" ]]; then
        log_warn "Jira not configured, skipping"
        return 1
    fi

    local priority=""
    case "${SEVERITY}" in
        critical) priority="Highest" ;;
        high)     priority="High" ;;
        medium)   priority="Medium" ;;
        low)      priority="Low" ;;
    esac

    local project="${OTTO_JIRA_PROJECT:-OPS}"

    local issue_key
    issue_key=$(curl -sf -X POST -u "${email}:${token}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg project "${project}" \
            --arg summary "[${incident_id}] ${TITLE}" \
            --arg priority "${priority}" \
            --arg description "${DESCRIPTION}" \
            '{fields: {project: {key: $project}, summary: $summary, issuetype: {name: "Bug"}, priority: {name: $priority}, description: {type: "doc", version: 1, content: [{type: "paragraph", content: [{type: "text", text: $description}]}]}}}')" \
        "${url}/rest/api/3/issue" 2>/dev/null | jq -r '.key // empty') || {
        log_warn "Jira issue creation failed"
        return 1
    }

    if [[ -n "${issue_key}" ]]; then
        log_info "Created Jira issue: ${issue_key}"
        echo "${issue_key}"
        return 0
    fi

    log_warn "Jira returned empty key"
    return 1
}

notify_grafana_incident() {
    local incident_id="$1"
    local url="${OTTO_GRAFANA_URL:-}"
    local token="${OTTO_GRAFANA_TOKEN:-}"

    if [[ -z "${url}" ]] || [[ -z "${token}" ]]; then
        log_warn "Grafana not configured, skipping"
        return 1
    fi

    local sev=""
    case "${SEVERITY}" in
        critical) sev="critical" ;;
        high)     sev="major" ;;
        *)        sev="minor" ;;
    esac

    local response
    response=$(curl -sf -X POST -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg title "[${incident_id}] ${TITLE}" --arg severity "${sev}" \
            '{title: $title, severity: $severity, status: "active"}')" \
        "${url}/api/plugins/grafana-incident-app/resources/api/v1/IncidentsService.CreateIncident" 2>/dev/null) || {
        log_warn "Grafana Incident creation failed"
        return 1
    }

    local gid
    gid=$(echo "${response}" | jq -r '.incident.incidentID // empty' 2>/dev/null) || gid=""

    if [[ -n "${gid}" ]]; then
        log_info "Created Grafana Incident: ${gid}"
        echo "${gid}"
        return 0
    fi

    log_warn "Grafana Incident returned unexpected response"
    return 1
}

output_result() {
    local action="$1" target="$2" status="$3" details="$4" notifications_json="$5"
    jq -n \
        --arg action "${action}" \
        --arg target "${target}" \
        --arg status "${status}" \
        --arg details "${details}" \
        --arg severity "${SEVERITY}" \
        --arg title "${TITLE}" \
        --arg environment "${ENVIRONMENT:-}" \
        --argjson notifications "${notifications_json}" \
        --arg dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            action: $action,
            target: $target,
            status: $status,
            details: $details,
            severity: $severity,
            title: $title,
            environment: $environment,
            notifications: $notifications,
            dry_run: ($dry_run == "true"),
            timestamp: $timestamp
        }'
}

main() {
    parse_args "$@"

    local description="Create incident: [${SEVERITY}] ${TITLE}"

    if ! permission_enforce "incident" "create" "${ENVIRONMENT}" "${description}"; then
        output_result "incident-create" "" "denied" "Permission denied for incident creation" "[]"
        exit 1
    fi

    local incident_id
    incident_id=$(generate_incident_id)

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create incident ${incident_id}: [${SEVERITY}] ${TITLE}"
        log_info "[DRY-RUN] Notifications: slack=${NOTIFY_SLACK}, telegram=${NOTIFY_TELEGRAM}, jira=${NOTIFY_JIRA}, grafana=${NOTIFY_GRAFANA}"
        output_result "incident-create" "${incident_id}" "dry-run" "Would create incident and send notifications" "[]"
        return
    fi

    log_info "Creating incident ${incident_id}: [${SEVERITY}] ${TITLE}"

    # Create local task
    create_task "${incident_id}"

    # Send notifications and collect results
    local notifications="[]"

    if [[ "${NOTIFY_SLACK}" == "true" ]]; then
        if notify_slack "${incident_id}"; then
            notifications=$(echo "${notifications}" | jq '. + [{"channel": "slack", "status": "sent"}]')
        else
            notifications=$(echo "${notifications}" | jq '. + [{"channel": "slack", "status": "failed"}]')
        fi
    fi

    if [[ "${NOTIFY_TELEGRAM}" == "true" ]]; then
        if notify_telegram "${incident_id}"; then
            notifications=$(echo "${notifications}" | jq '. + [{"channel": "telegram", "status": "sent"}]')
        else
            notifications=$(echo "${notifications}" | jq '. + [{"channel": "telegram", "status": "failed"}]')
        fi
    fi

    if [[ "${NOTIFY_JIRA}" == "true" ]]; then
        local jira_key
        if jira_key=$(notify_jira "${incident_id}"); then
            notifications=$(echo "${notifications}" | jq --arg key "${jira_key}" '. + [{"channel": "jira", "status": "sent", "key": $key}]')
        else
            notifications=$(echo "${notifications}" | jq '. + [{"channel": "jira", "status": "failed"}]')
        fi
    fi

    if [[ "${NOTIFY_GRAFANA}" == "true" ]]; then
        local gid
        if gid=$(notify_grafana_incident "${incident_id}"); then
            notifications=$(echo "${notifications}" | jq --arg gid "${gid}" '. + [{"channel": "grafana", "status": "sent", "incident_id": $gid}]')
        else
            notifications=$(echo "${notifications}" | jq '. + [{"channel": "grafana", "status": "failed"}]')
        fi
    fi

    # Update task with notification results
    local task_file="${OTTO_TASKS_DIR}/triage/${incident_id}.json"
    if [[ -f "${task_file}" ]]; then
        local tmp
        tmp=$(mktemp)
        jq --argjson notifs "${notifications}" '.notifications = $notifs' "${task_file}" > "${tmp}" && mv "${tmp}" "${task_file}"
    fi

    local sent_count
    sent_count=$(echo "${notifications}" | jq '[.[] | select(.status == "sent")] | length')

    output_result "incident-create" "${incident_id}" "success" "Incident created, ${sent_count} notification(s) sent" "${notifications}"
}

main "$@"
