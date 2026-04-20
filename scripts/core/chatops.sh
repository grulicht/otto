#!/usr/bin/env bash
# OTTO - Bidirectional ChatOps
# Polls Slack/Telegram for commands, executes them, and replies.
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_CHATOPS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_CHATOPS_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"

# State for Telegram offset tracking
CHATOPS_STATE_DIR="${OTTO_HOME}/state/chatops"
CHATOPS_TELEGRAM_OFFSET_FILE="${CHATOPS_STATE_DIR}/telegram_offset"
CHATOPS_SLACK_TS_FILE="${CHATOPS_STATE_DIR}/slack_last_ts"

# --- Internal ---

_chatops_init() {
    mkdir -p "${CHATOPS_STATE_DIR}"
}

# --- Public API ---

# Parse natural language text into an OTTO command.
# Usage: chatops_parse_command <text>
# Outputs: JSON with {command, args[]} or null if unrecognized.
chatops_parse_command() {
    local text="$1"
    # Normalize: lowercase, trim
    text=$(echo "${text}" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Remove bot mention prefix (e.g. "@otto ", "otto ")
    text=$(echo "${text}" | sed -E 's/^@?otto[[:space:]]+//')

    local command="" args="[]"

    case "${text}" in
        check\ *)
            command="check"
            local target="${text#check }"
            args=$(jq -n --arg t "${target}" '[$t]')
            ;;
        status|status\ *)
            command="status"
            ;;
        deploy\ *)
            command="deploy"
            # Expected: deploy <target> <env> <version>
            local rest="${text#deploy }"
            args=$(echo "${rest}" | awk '{printf "[\"%s\",\"%s\",\"%s\"]", $1, $2, $3}')
            ;;
        rollback\ *)
            command="rollback"
            # Expected: rollback <target> <env>
            local rest="${text#rollback }"
            args=$(echo "${rest}" | awk '{printf "[\"%s\",\"%s\"]", $1, $2}')
            ;;
        scale\ *)
            command="scale"
            # Expected: scale <target> <count>
            local rest="${text#scale }"
            args=$(echo "${rest}" | awk '{printf "[\"%s\",\"%s\"]", $1, $2}')
            ;;
        incident\ *)
            command="incident"
            local title="${text#incident }"
            args=$(jq -n --arg t "${title}" '[$t]')
            ;;
        help)
            command="help"
            ;;
        *)
            echo "null"
            return 0
            ;;
    esac

    jq -n --arg cmd "${command}" --argjson args "${args}" '{"command": $cmd, "args": $args}'
}

# Execute a parsed command and send the result back to the source.
# Usage: chatops_execute <command_json> <source> <reply_to>
# source: "slack" or "telegram"
# reply_to: channel/chat_id + optional thread info as JSON
chatops_execute() {
    local command_json="$1"
    local source="$2"
    local reply_to="$3"

    local cmd args
    cmd=$(echo "${command_json}" | jq -r '.command')
    args=$(echo "${command_json}" | jq -r '.args // []')

    local result=""

    case "${cmd}" in
        check)
            local target
            target=$(echo "${args}" | jq -r '.[0] // ""')
            local fetch_script="${OTTO_DIR}/scripts/fetch/${target}.sh"
            if [[ -f "${fetch_script}" ]]; then
                result=$("${fetch_script}" 2>&1 || true)
            else
                result="Unknown check target: ${target}. Available: $(ls "${OTTO_DIR}/scripts/fetch/" 2>/dev/null | sed 's/\.sh$//' | tr '\n' ', ')"
            fi
            ;;
        status)
            result="OTTO Status: Running. $(date -Iseconds)"
            if [[ -f "${OTTO_HOME}/state/state.json" ]]; then
                result="${result}\n$(jq -r 'to_entries | map("\(.key): \(.value)") | join("\n")' "${OTTO_HOME}/state/state.json" 2>/dev/null || echo "State unavailable")"
            fi
            ;;
        deploy)
            local target env version
            target=$(echo "${args}" | jq -r '.[0] // ""')
            env=$(echo "${args}" | jq -r '.[1] // ""')
            version=$(echo "${args}" | jq -r '.[2] // ""')
            if [[ -z "${target}" || -z "${env}" || -z "${version}" ]]; then
                result="Usage: deploy <target> <environment> <version>"
            else
                result="Deploy requested: ${target} to ${env} version ${version}. This requires confirmation via OTTO permissions system."
                log_info "ChatOps deploy request: ${target} ${env} ${version}"
            fi
            ;;
        rollback)
            local target env
            target=$(echo "${args}" | jq -r '.[0] // ""')
            env=$(echo "${args}" | jq -r '.[1] // ""')
            if [[ -z "${target}" || -z "${env}" ]]; then
                result="Usage: rollback <target> <environment>"
            else
                result="Rollback requested: ${target} in ${env}. This requires confirmation via OTTO permissions system."
                log_info "ChatOps rollback request: ${target} ${env}"
            fi
            ;;
        scale)
            local target count
            target=$(echo "${args}" | jq -r '.[0] // ""')
            count=$(echo "${args}" | jq -r '.[1] // ""')
            if [[ -z "${target}" || -z "${count}" ]]; then
                result="Usage: scale <target> <count>"
            else
                result="Scale requested: ${target} to ${count} replicas. This requires confirmation via OTTO permissions system."
                log_info "ChatOps scale request: ${target} ${count}"
            fi
            ;;
        incident)
            local title
            title=$(echo "${args}" | jq -r '.[0] // ""')
            result="Incident created: ${title}\nTimestamp: $(date -Iseconds)\nUse 'otto incident' CLI for full incident management."
            log_info "ChatOps incident created: ${title}"
            ;;
        help)
            result="OTTO ChatOps Commands:\n  check <target> - Run health check\n  status - System status\n  deploy <target> <env> <version> - Request deployment\n  rollback <target> <env> - Request rollback\n  scale <target> <count> - Request scaling\n  incident <title> - Create incident"
            ;;
        *)
            result="Unknown command: ${cmd}. Try 'help'."
            ;;
    esac

    # Send reply back to source
    case "${source}" in
        slack)
            local channel thread_ts
            channel=$(echo "${reply_to}" | jq -r '.channel // ""')
            thread_ts=$(echo "${reply_to}" | jq -r '.thread_ts // ""')
            chatops_reply_slack "${channel}" "${thread_ts}" "${result}"
            ;;
        telegram)
            local chat_id
            chat_id=$(echo "${reply_to}" | jq -r '.chat_id // ""')
            chatops_reply_telegram "${chat_id}" "${result}"
            ;;
        *)
            log_warn "Unknown ChatOps source: ${source}"
            echo -e "${result}"
            ;;
    esac
}

# Send reply to Slack.
# Usage: chatops_reply_slack <channel> <thread_ts> <message>
chatops_reply_slack() {
    local channel="$1"
    local thread_ts="$2"
    local message="$3"

    if [[ -z "${OTTO_SLACK_TOKEN:-}" ]]; then
        log_warn "OTTO_SLACK_TOKEN not set, cannot reply to Slack"
        return 1
    fi

    local payload
    payload=$(jq -n --arg ch "${channel}" --arg msg "${message}" '{"channel": $ch, "text": $msg}')

    if [[ -n "${thread_ts}" ]]; then
        payload=$(echo "${payload}" | jq --arg ts "${thread_ts}" '. + {"thread_ts": $ts}')
    fi

    curl -s -X POST "https://slack.com/api/chat.postMessage" \
        -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${payload}" >/dev/null 2>&1

    log_debug "Slack reply sent to ${channel}"
}

# Send reply to Telegram.
# Usage: chatops_reply_telegram <chat_id> <message>
chatops_reply_telegram() {
    local chat_id="$1"
    local message="$2"

    if [[ -z "${OTTO_TELEGRAM_TOKEN:-}" ]]; then
        log_warn "OTTO_TELEGRAM_TOKEN not set, cannot reply to Telegram"
        return 1
    fi

    curl -s -X POST "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${message}" >/dev/null 2>&1

    log_debug "Telegram reply sent to ${chat_id}"
}

# Poll Slack for new DMs to OTTO bot, parse commands.
# Usage: chatops_poll_slack
chatops_poll_slack() {
    _chatops_init

    if [[ -z "${OTTO_SLACK_TOKEN:-}" ]]; then
        log_debug "Slack polling skipped: OTTO_SLACK_TOKEN not set"
        return 0
    fi

    local last_ts="0"
    if [[ -f "${CHATOPS_SLACK_TS_FILE}" ]]; then
        last_ts=$(cat "${CHATOPS_SLACK_TS_FILE}")
    fi

    # Get DMs (conversations with bot)
    local response
    response=$(curl -s -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
        "https://slack.com/api/conversations.list?types=im&limit=10" 2>/dev/null || echo '{"ok":false}')

    if [[ "$(echo "${response}" | jq -r '.ok')" != "true" ]]; then
        log_warn "Slack API error during poll"
        return 1
    fi

    local channels
    channels=$(echo "${response}" | jq -r '.channels[]?.id // empty')

    for channel in ${channels}; do
        local messages
        messages=$(curl -s -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
            "https://slack.com/api/conversations.history?channel=${channel}&oldest=${last_ts}&limit=10" 2>/dev/null || echo '{"ok":false}')

        if [[ "$(echo "${messages}" | jq -r '.ok')" != "true" ]]; then
            continue
        fi

        echo "${messages}" | jq -c '.messages[]? | select(.bot_id == null)' | while IFS= read -r msg; do
            local text ts
            text=$(echo "${msg}" | jq -r '.text // ""')
            ts=$(echo "${msg}" | jq -r '.ts // ""')

            if [[ -z "${text}" ]]; then
                continue
            fi

            log_info "Slack command received: ${text}"
            local parsed
            parsed=$(chatops_parse_command "${text}")

            if [[ "${parsed}" != "null" ]]; then
                local reply_to
                reply_to=$(jq -n --arg ch "${channel}" --arg ts "${ts}" '{"channel": $ch, "thread_ts": $ts}')
                chatops_execute "${parsed}" "slack" "${reply_to}"
            else
                chatops_reply_slack "${channel}" "${ts}" "Unknown command. Try 'help'."
            fi

            # Update last timestamp
            echo "${ts}" > "${CHATOPS_SLACK_TS_FILE}"
        done
    done
}

# Poll Telegram for bot updates, parse commands.
# Usage: chatops_poll_telegram
chatops_poll_telegram() {
    _chatops_init

    if [[ -z "${OTTO_TELEGRAM_TOKEN:-}" ]]; then
        log_debug "Telegram polling skipped: OTTO_TELEGRAM_TOKEN not set"
        return 0
    fi

    local offset=0
    if [[ -f "${CHATOPS_TELEGRAM_OFFSET_FILE}" ]]; then
        offset=$(cat "${CHATOPS_TELEGRAM_OFFSET_FILE}")
    fi

    local response
    response=$(curl -s "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/getUpdates?offset=${offset}&limit=10&timeout=0" 2>/dev/null || echo '{"ok":false}')

    if [[ "$(echo "${response}" | jq -r '.ok')" != "true" ]]; then
        log_warn "Telegram API error during poll"
        return 1
    fi

    echo "${response}" | jq -c '.result[]?' | while IFS= read -r update; do
        local update_id text chat_id
        update_id=$(echo "${update}" | jq -r '.update_id')
        text=$(echo "${update}" | jq -r '.message.text // ""')
        chat_id=$(echo "${update}" | jq -r '.message.chat.id // ""')

        if [[ -z "${text}" || -z "${chat_id}" ]]; then
            echo "$((update_id + 1))" > "${CHATOPS_TELEGRAM_OFFSET_FILE}"
            continue
        fi

        log_info "Telegram command received: ${text}"
        local parsed
        parsed=$(chatops_parse_command "${text}")

        if [[ "${parsed}" != "null" ]]; then
            local reply_to
            reply_to=$(jq -n --arg cid "${chat_id}" '{"chat_id": $cid}')
            chatops_execute "${parsed}" "telegram" "${reply_to}"
        else
            chatops_reply_telegram "${chat_id}" "Unknown command. Try 'help'."
        fi

        echo "$((update_id + 1))" > "${CHATOPS_TELEGRAM_OFFSET_FILE}"
    done
}
