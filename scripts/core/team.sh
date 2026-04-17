#!/usr/bin/env bash
# OTTO - Team management and multi-user features
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_TEAM_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_TEAM_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/config.sh"

# Team directories
OTTO_TEAM_DIR="${OTTO_HOME}/team"
OTTO_TEAM_CONFIG="${OTTO_TEAM_DIR}/config.yaml"
OTTO_TEAM_KNOWLEDGE_DIR="${OTTO_TEAM_DIR}/knowledge"
OTTO_TEAM_RUNBOOKS_DIR="${OTTO_TEAM_DIR}/runbooks"
OTTO_TEAM_ACTIVITY_LOG="${OTTO_TEAM_DIR}/activity.jsonl"

# --- Public API ---

# Initialize team configuration directory structure.
#   $1 - Team name
team_init() {
    local team_name="$1"

    log_info "Initializing team: ${team_name}"

    mkdir -p "${OTTO_TEAM_DIR}"
    mkdir -p "${OTTO_TEAM_KNOWLEDGE_DIR}"
    mkdir -p "${OTTO_TEAM_RUNBOOKS_DIR}"

    if [[ ! -f "${OTTO_TEAM_CONFIG}" ]]; then
        cat > "${OTTO_TEAM_CONFIG}" <<TEAMEOF
team:
  name: "${team_name}"
  members: []
  oncall:
    type: manual
    schedule: []
  shared_knowledge:
    type: directory
    path: "${OTTO_TEAM_KNOWLEDGE_DIR}"
  notification:
    team_channel: "#devops-team"
    incident_channel: "#incidents"
TEAMEOF
        log_info "Created team config: ${OTTO_TEAM_CONFIG}"
    else
        log_warn "Team config already exists: ${OTTO_TEAM_CONFIG}"
    fi

    # Initialize activity log
    if [[ ! -f "${OTTO_TEAM_ACTIVITY_LOG}" ]]; then
        touch "${OTTO_TEAM_ACTIVITY_LOG}"
    fi

    log_info "Team '${team_name}' initialized at ${OTTO_TEAM_DIR}"
}

# Load team configuration from config file or git-synced location.
# Sets OTTO_TEAM_CONFIG to the resolved path.
# Returns 0 if config found, 1 otherwise.
team_config_load() {
    # Check for git-synced team config location in user config
    local git_config_path
    git_config_path=$(config_get ".team.config_path" "")

    if [[ -n "${git_config_path}" ]] && [[ -f "${git_config_path}" ]]; then
        OTTO_TEAM_CONFIG="${git_config_path}"
        log_debug "Loaded team config from git-synced location: ${OTTO_TEAM_CONFIG}"
        return 0
    fi

    # Fall back to default location
    if [[ -f "${OTTO_TEAM_CONFIG}" ]]; then
        log_debug "Loaded team config from: ${OTTO_TEAM_CONFIG}"
        return 0
    fi

    log_warn "No team configuration found"
    return 1
}

# Merge team config with user config. Team config serves as the base
# layer; user config values override team values.
#   $1 - Path to user config file
#   $2 - Path to team config file
# Outputs merged config to stdout.
team_config_merge() {
    local user_config="$1"
    local team_config="$2"

    if [[ ! -f "${team_config}" ]]; then
        log_error "Team config not found: ${team_config}"
        return 1
    fi

    if [[ ! -f "${user_config}" ]]; then
        cat "${team_config}"
        return 0
    fi

    # Team config is base, user config overrides
    yaml_merge "${team_config}" "${user_config}"
}

# List all team members from team config.
# Outputs one member per line: "name email role"
team_get_members() {
    if ! team_config_load; then
        return 1
    fi

    local member_count
    member_count=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members | length" "0")

    if [[ "${member_count}" -eq 0 ]]; then
        log_info "No team members configured"
        return 0
    fi

    local i
    for ((i = 0; i < member_count; i++)); do
        local name email role
        name=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].name" "")
        email=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].email" "")
        role=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].role" "")
        printf '%s\t%s\t%s\n' "${name}" "${email}" "${role}"
    done
}

# Get the current on-call person based on team config or external service.
# Outputs: "name email" of the on-call person.
team_get_oncall() {
    if ! team_config_load; then
        return 1
    fi

    local oncall_type
    oncall_type=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.type" "manual")

    case "${oncall_type}" in
        schedule)
            _oncall_from_schedule
            ;;
        pagerduty)
            _oncall_from_pagerduty
            ;;
        opsgenie)
            _oncall_from_opsgenie
            ;;
        manual)
            _oncall_from_manual
            ;;
        *)
            log_error "Unknown oncall type: ${oncall_type}"
            return 1
            ;;
    esac
}

# Get a team member's role.
#   $1 - Member name or email
# Outputs the role string (admin, engineer, viewer, junior).
team_get_role() {
    local member="$1"

    if ! team_config_load; then
        return 1
    fi

    local member_count
    member_count=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members | length" "0")

    local i
    for ((i = 0; i < member_count; i++)); do
        local name email role
        name=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].name" "")
        email=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].email" "")
        role=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].role" "")

        if [[ "${name}" == "${member}" ]] || [[ "${email}" == "${member}" ]]; then
            echo "${role}"
            return 0
        fi
    done

    log_warn "Member not found: ${member}"
    return 1
}

# Return the path to the shared knowledge base directory.
team_shared_knowledge_path() {
    if ! team_config_load; then
        return 1
    fi

    local knowledge_type
    knowledge_type=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.shared_knowledge.type" "directory")

    case "${knowledge_type}" in
        git)
            local repo_path
            repo_path=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.shared_knowledge.path" "knowledge/")
            echo "${OTTO_TEAM_DIR}/${repo_path}"
            ;;
        directory)
            local dir_path
            dir_path=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.shared_knowledge.path" "${OTTO_TEAM_KNOWLEDGE_DIR}")
            echo "${dir_path}"
            ;;
        none)
            log_info "Shared knowledge base is disabled"
            return 1
            ;;
        *)
            log_error "Unknown knowledge type: ${knowledge_type}"
            return 1
            ;;
    esac
}

# Sync the team knowledge base from a git repo or shared directory.
team_sync_knowledge() {
    if ! team_config_load; then
        return 1
    fi

    local knowledge_type
    knowledge_type=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.shared_knowledge.type" "directory")

    case "${knowledge_type}" in
        git)
            local repo
            repo=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.shared_knowledge.repo" "")
            local knowledge_path
            knowledge_path=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.shared_knowledge.path" "knowledge/")
            local target_dir="${OTTO_TEAM_DIR}/${knowledge_path}"

            if [[ -z "${repo}" ]]; then
                log_error "No git repo configured for shared knowledge"
                return 1
            fi

            if [[ -d "${target_dir}/.git" ]]; then
                log_info "Pulling latest knowledge base from ${repo}"
                git -C "${target_dir}" pull --ff-only 2>&1 || {
                    log_error "Failed to pull knowledge base"
                    return 1
                }
            else
                log_info "Cloning knowledge base from ${repo}"
                mkdir -p "$(dirname "${target_dir}")"
                git clone "${repo}" "${target_dir}" 2>&1 || {
                    log_error "Failed to clone knowledge base"
                    return 1
                }
            fi
            log_info "Knowledge base synced successfully"
            ;;
        directory)
            log_info "Knowledge base is a local directory; no sync needed"
            ;;
        none)
            log_info "Shared knowledge is disabled"
            ;;
        *)
            log_error "Unknown knowledge type: ${knowledge_type}"
            return 1
            ;;
    esac
}

# Create a shared runbook accessible to all team members.
#   $1 - Runbook name (used as filename)
#   $2 - Runbook content (markdown)
team_create_shared_runbook() {
    local name="$1"
    local content="$2"

    mkdir -p "${OTTO_TEAM_RUNBOOKS_DIR}"

    local runbook_file="${OTTO_TEAM_RUNBOOKS_DIR}/${name}.md"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local author
    author=$(config_get ".user.name" "${USER:-unknown}")

    cat > "${runbook_file}" <<RUNBOOKEOF
---
name: "${name}"
author: "${author}"
created: "${now}"
updated: "${now}"
---

${content}
RUNBOOKEOF

    log_info "Created shared runbook: ${runbook_file}"
    team_activity_log "${author}" "create_runbook" "Created runbook: ${name}"
}

# Send a notification to all team members.
#   $1 - Message text
#   $2 - Severity (info, warning, critical)
team_notify_all() {
    local message="$1"
    local severity="${2:-info}"

    if ! team_config_load; then
        return 1
    fi

    local team_channel
    team_channel=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.notification.team_channel" "")

    if [[ -z "${team_channel}" ]]; then
        log_warn "No team notification channel configured"
        return 1
    fi

    local prefix=""
    case "${severity}" in
        critical) prefix="[CRITICAL] " ;;
        warning)  prefix="[WARNING] " ;;
        info)     prefix="" ;;
    esac

    local formatted_message="${prefix}${message}"

    # Use incident channel for critical severity
    if [[ "${severity}" == "critical" ]]; then
        local incident_channel
        incident_channel=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.notification.incident_channel" "")
        if [[ -n "${incident_channel}" ]]; then
            _send_channel_notification "${incident_channel}" "${formatted_message}"
        fi
    fi

    _send_channel_notification "${team_channel}" "${formatted_message}"
    log_info "Sent team notification (${severity}): ${message}"
}

# Send a notification to the current on-call person only.
#   $1 - Message text
#   $2 - Severity (info, warning, critical)
team_notify_oncall() {
    local message="$1"
    local severity="${2:-info}"

    local oncall_info
    if ! oncall_info=$(team_get_oncall); then
        log_error "Cannot determine on-call person"
        return 1
    fi

    local oncall_name
    oncall_name=$(echo "${oncall_info}" | awk '{print $1}')

    local prefix=""
    case "${severity}" in
        critical) prefix="[CRITICAL] " ;;
        warning)  prefix="[WARNING] " ;;
        info)     prefix="" ;;
    esac

    log_info "Notifying on-call (${oncall_name}): ${prefix}${message}"

    # Look up the on-call person's notification details
    if ! team_config_load; then
        return 1
    fi

    local member_count
    member_count=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members | length" "0")

    local i
    for ((i = 0; i < member_count; i++)); do
        local name slack_id
        name=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].name" "")
        if [[ "${name}" == "${oncall_name}" ]]; then
            slack_id=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${i}].slack_id" "")
            if [[ -n "${slack_id}" ]]; then
                _send_dm_notification "${slack_id}" "${prefix}${message}"
            fi
            return 0
        fi
    done

    log_warn "Could not find notification details for on-call: ${oncall_name}"
    return 1
}

# Log a team member's activity.
#   $1 - Member name or identifier
#   $2 - Action performed
#   $3 - Additional details
team_activity_log() {
    local member="$1"
    local action="$2"
    local details="${3:-}"

    mkdir -p "${OTTO_TEAM_DIR}"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local escaped_details
    escaped_details=$(printf '%s' "${details}" | jq -Rs '.')

    printf '{"ts":"%s","member":"%s","action":"%s","details":%s}\n' \
        "${timestamp}" "${member}" "${action}" "${escaped_details}" \
        >> "${OTTO_TEAM_ACTIVITY_LOG}"
}

# Generate a team status dashboard showing who is on, recent activity,
# and open incidents.
team_dashboard() {
    if ! team_config_load; then
        return 1
    fi

    local team_name
    team_name=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.name" "Unknown Team")

    echo -e "${BOLD}Team Dashboard: ${team_name}${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"
    echo ""

    # On-call status
    echo -e "${BOLD}On-Call:${NC}"
    local oncall_info
    if oncall_info=$(team_get_oncall 2>/dev/null); then
        echo -e "  ${GREEN}●${NC} ${oncall_info}"
    else
        echo -e "  ${YELLOW}●${NC} No on-call configured"
    fi
    echo ""

    # Team members
    echo -e "${BOLD}Team Members:${NC}"
    local members
    if members=$(team_get_members 2>/dev/null); then
        if [[ -n "${members}" ]]; then
            echo "${members}" | while IFS=$'\t' read -r name email role; do
                local role_color=""
                case "${role}" in
                    admin)    role_color="${RED}" ;;
                    engineer) role_color="${BLUE}" ;;
                    viewer)   role_color="${DIM}" ;;
                    junior)   role_color="${CYAN}" ;;
                esac
                printf '  %-15s %-30s %b%s%b\n' "${name}" "${email}" "${role_color}" "${role}" "${NC}"
            done
        else
            echo "  (no members)"
        fi
    else
        echo "  (unable to load members)"
    fi
    echo ""

    # Recent activity (last 10 entries)
    echo -e "${BOLD}Recent Activity:${NC}"
    if [[ -f "${OTTO_TEAM_ACTIVITY_LOG}" ]] && [[ -s "${OTTO_TEAM_ACTIVITY_LOG}" ]]; then
        tail -n 10 "${OTTO_TEAM_ACTIVITY_LOG}" | while IFS= read -r line; do
            local ts member action details
            ts=$(echo "${line}" | jq -r '.ts // empty' 2>/dev/null)
            member=$(echo "${line}" | jq -r '.member // empty' 2>/dev/null)
            action=$(echo "${line}" | jq -r '.action // empty' 2>/dev/null)
            details=$(echo "${line}" | jq -r '.details // empty' 2>/dev/null)
            if [[ -n "${ts}" ]]; then
                printf '  %s  %-12s %-20s %s\n' "${ts}" "${member}" "${action}" "${details}"
            fi
        done
    else
        echo "  (no recent activity)"
    fi
    echo ""

    echo -e "${DIM}──────────────────────────────────────────${NC}"
    echo -e "${DIM}Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")${NC}"
}

# --- Internal helpers ---

# Determine on-call from the configured schedule based on current day of week.
_oncall_from_schedule() {
    local schedule_count
    schedule_count=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.schedule | length" "0")

    if [[ "${schedule_count}" -eq 0 ]]; then
        log_warn "No on-call schedule entries configured"
        return 1
    fi

    # Get current day of week (lowercase)
    local today
    today=$(date +%A | tr '[:upper:]' '[:lower:]')

    local days_order="monday tuesday wednesday thursday friday saturday sunday"
    local today_idx
    today_idx=$(_day_index "${today}")

    local i
    for ((i = 0; i < schedule_count; i++)); do
        local name start_day end_day
        name=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.schedule[${i}].name" "")
        start_day=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.schedule[${i}].start" "")
        end_day=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.schedule[${i}].end" "")

        local start_idx end_idx
        start_idx=$(_day_index "${start_day}")
        end_idx=$(_day_index "${end_day}")

        if _day_in_range "${today_idx}" "${start_idx}" "${end_idx}"; then
            # Look up email from members list
            local member_count
            member_count=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members | length" "0")
            local j email=""
            for ((j = 0; j < member_count; j++)); do
                local mname
                mname=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${j}].name" "")
                if [[ "${mname}" == "${name}" ]]; then
                    email=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.members[${j}].email" "")
                    break
                fi
            done
            printf '%s\t%s\n' "${name}" "${email}"
            return 0
        fi
    done

    log_warn "No on-call schedule matches today (${today})"
    return 1
}

# Query PagerDuty for on-call information.
_oncall_from_pagerduty() {
    local api_key="${OTTO_PAGERDUTY_API_KEY:-}"
    local schedule_id
    schedule_id=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.pagerduty_schedule_id" "")

    if [[ -z "${api_key}" ]]; then
        log_error "OTTO_PAGERDUTY_API_KEY not set"
        return 1
    fi

    if [[ -z "${schedule_id}" ]]; then
        log_error "No pagerduty_schedule_id configured in team config"
        return 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local response
    response=$(curl -sf \
        -H "Authorization: Token token=${api_key}" \
        -H "Content-Type: application/json" \
        "https://api.pagerduty.com/oncalls?schedule_ids[]=${schedule_id}&since=${now}&until=${now}" 2>/dev/null) || {
        log_error "Failed to query PagerDuty API"
        return 1
    }

    local oncall_name oncall_email
    oncall_name=$(echo "${response}" | jq -r '.oncalls[0].user.summary // empty')
    oncall_email=$(echo "${response}" | jq -r '.oncalls[0].user.email // empty')

    if [[ -z "${oncall_name}" ]]; then
        log_warn "No on-call user returned from PagerDuty"
        return 1
    fi

    printf '%s\t%s\n' "${oncall_name}" "${oncall_email}"
}

# Query OpsGenie for on-call information.
_oncall_from_opsgenie() {
    local api_key="${OTTO_OPSGENIE_API_KEY:-}"
    local schedule_id
    schedule_id=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.opsgenie_schedule_id" "")

    if [[ -z "${api_key}" ]]; then
        log_error "OTTO_OPSGENIE_API_KEY not set"
        return 1
    fi

    if [[ -z "${schedule_id}" ]]; then
        log_error "No opsgenie_schedule_id configured in team config"
        return 1
    fi

    local response
    response=$(curl -sf \
        -H "Authorization: GenieKey ${api_key}" \
        "https://api.opsgenie.com/v2/schedules/${schedule_id}/on-calls" 2>/dev/null) || {
        log_error "Failed to query OpsGenie API"
        return 1
    }

    local oncall_name
    oncall_name=$(echo "${response}" | jq -r '.data.onCallParticipants[0].name // empty')

    if [[ -z "${oncall_name}" ]]; then
        log_warn "No on-call user returned from OpsGenie"
        return 1
    fi

    printf '%s\n' "${oncall_name}"
}

# Return manually configured on-call person.
_oncall_from_manual() {
    local name
    name=$(yaml_get "${OTTO_TEAM_CONFIG}" ".team.oncall.manual_oncall" "")

    if [[ -z "${name}" ]]; then
        log_warn "No manual on-call person configured"
        return 1
    fi

    printf '%s\n' "${name}"
}

# Convert day name to numeric index (0=monday, 6=sunday).
_day_index() {
    local day="$1"
    case "${day}" in
        monday)    echo 0 ;;
        tuesday)   echo 1 ;;
        wednesday) echo 2 ;;
        thursday)  echo 3 ;;
        friday)    echo 4 ;;
        saturday)  echo 5 ;;
        sunday)    echo 6 ;;
        *)         echo 0 ;;
    esac
}

# Check if a day index falls within a range (handles week wrap-around).
#   $1 - day to check (index)
#   $2 - range start (index)
#   $3 - range end (index, exclusive)
_day_in_range() {
    local day="$1"
    local start="$2"
    local end="$3"

    if [[ "${start}" -le "${end}" ]]; then
        # Normal range (e.g., monday-friday)
        [[ "${day}" -ge "${start}" ]] && [[ "${day}" -lt "${end}" ]]
    else
        # Wrapping range (e.g., friday-monday)
        [[ "${day}" -ge "${start}" ]] || [[ "${day}" -lt "${end}" ]]
    fi
}

# Send a notification to a channel (Slack or configured provider).
_send_channel_notification() {
    local channel="$1"
    local message="$2"

    local slack_token="${OTTO_SLACK_TOKEN:-}"
    if [[ -n "${slack_token}" ]]; then
        curl -sf -X POST \
            -H "Authorization: Bearer ${slack_token}" \
            -H "Content-Type: application/json" \
            -d "{\"channel\":\"${channel}\",\"text\":\"${message}\"}" \
            "https://slack.com/api/chat.postMessage" > /dev/null 2>&1 || {
            log_warn "Failed to send Slack notification to ${channel}"
            return 1
        }
    else
        log_debug "No Slack token; logging notification: [${channel}] ${message}"
    fi
}

# Send a direct message notification to a user (by Slack ID).
_send_dm_notification() {
    local user_id="$1"
    local message="$2"

    local slack_token="${OTTO_SLACK_TOKEN:-}"
    if [[ -n "${slack_token}" ]]; then
        curl -sf -X POST \
            -H "Authorization: Bearer ${slack_token}" \
            -H "Content-Type: application/json" \
            -d "{\"channel\":\"${user_id}\",\"text\":\"${message}\"}" \
            "https://slack.com/api/chat.postMessage" > /dev/null 2>&1 || {
            log_warn "Failed to send Slack DM to ${user_id}"
            return 1
        }
    else
        log_debug "No Slack token; logging DM to ${user_id}: ${message}"
    fi
}
