#!/usr/bin/env bash
# OTTO - Alert Routing Rules
# Matches alerts against configurable routing rules and dispatches notifications.
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_ALERT_ROUTER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_ALERT_ROUTER_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/config.sh"

# Cached rules (loaded once)
_ALERT_ROUTING_RULES=""
_ALERT_ROUTING_ENABLED=""
_ALERT_ROUTING_DEFAULT_TARGETS=""

# --- Public API ---

# Load routing rules from config (alert_routing.rules section).
alert_router_load_rules() {
    local config_file="${OTTO_HOME}/config.yaml"
    local default_config="${OTTO_DIR}/config/default.yaml"

    local cfg="${config_file}"
    if [[ ! -f "${cfg}" ]]; then
        cfg="${default_config}"
    fi

    _ALERT_ROUTING_ENABLED=$(yq '.alert_routing.enabled // false' "${cfg}" 2>/dev/null || echo "false")
    _ALERT_ROUTING_DEFAULT_TARGETS=$(yq '.alert_routing.default_targets // []' "${cfg}" -o=json 2>/dev/null || echo "[]")
    _ALERT_ROUTING_RULES=$(yq '.alert_routing.rules // []' "${cfg}" -o=json 2>/dev/null || echo "[]")

    log_debug "Alert routing enabled=${_ALERT_ROUTING_ENABLED}, rules=$(echo "${_ALERT_ROUTING_RULES}" | jq 'length')"
}

# Check if an alert matches a rule's conditions (severity, domain, source, environment).
# Usage: alert_router_match <alert_json> <rule_json>
# Returns 0 if match, 1 otherwise.
alert_router_match() {
    local alert="$1"
    local rule="$2"

    local match_block
    match_block=$(echo "${rule}" | jq -r '.match // {}')

    # Check each field in the match block
    local field value alert_value
    for field in $(echo "${match_block}" | jq -r 'keys[]'); do
        value=$(echo "${match_block}" | jq -r --arg f "${field}" '.[$f]')
        alert_value=$(echo "${alert}" | jq -r --arg f "${field}" '.[$f] // ""')

        if [[ "${value}" != "${alert_value}" ]]; then
            return 1
        fi
    done

    return 0
}

# Match alert against routing rules, return list of notification targets as JSON array.
# Usage: alert_route <alert_json>
alert_route() {
    local alert_json="$1"

    # Ensure rules are loaded
    if [[ -z "${_ALERT_ROUTING_RULES}" ]]; then
        alert_router_load_rules
    fi

    if [[ "${_ALERT_ROUTING_ENABLED}" != "true" ]]; then
        log_debug "Alert routing is disabled"
        echo "${_ALERT_ROUTING_DEFAULT_TARGETS}"
        return 0
    fi

    local targets="[]"
    local rule_count
    rule_count=$(echo "${_ALERT_ROUTING_RULES}" | jq 'length')

    local i rule
    for (( i = 0; i < rule_count; i++ )); do
        rule=$(echo "${_ALERT_ROUTING_RULES}" | jq ".[$i]")

        if alert_router_match "${alert_json}" "${rule}"; then
            local rule_targets
            rule_targets=$(echo "${rule}" | jq '.notify // []')
            targets=$(echo "${targets}" | jq --argjson new "${rule_targets}" '. + $new | unique')
        fi
    done

    # Fall back to default targets if no rules matched
    if [[ "$(echo "${targets}" | jq 'length')" -eq 0 ]]; then
        targets="${_ALERT_ROUTING_DEFAULT_TARGETS}"
    fi

    echo "${targets}"
}

# Send alert to matched targets.
# Usage: alert_router_notify <targets_json> <alert_json>
alert_router_notify() {
    local targets_json="$1"
    local alert_json="$2"

    local severity name message
    severity=$(echo "${alert_json}" | jq -r '.severity // "info"')
    name=$(echo "${alert_json}" | jq -r '.name // "unknown"')
    message=$(echo "${alert_json}" | jq -r '.message // ""')

    local formatted="[${severity^^}] ${name}: ${message}"

    local target_count target
    target_count=$(echo "${targets_json}" | jq 'length')

    for (( i = 0; i < target_count; i++ )); do
        target=$(echo "${targets_json}" | jq -r ".[$i]")

        case "${target}" in
            slack_oncall)
                log_info "Routing alert to Slack on-call channel: ${name}"
                if command -v curl &>/dev/null && [[ -n "${OTTO_SLACK_TOKEN:-}" ]]; then
                    local oncall_channel="${OTTO_SLACK_ONCALL_CHANNEL:-${OTTO_SLACK_CHANNEL_ID:-}}"
                    if [[ -n "${oncall_channel}" ]]; then
                        curl -s -X POST "https://slack.com/api/chat.postMessage" \
                            -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
                            -H "Content-Type: application/json" \
                            -d "{\"channel\":\"${oncall_channel}\",\"text\":\"${formatted}\"}" >/dev/null 2>&1 || true
                    fi
                fi
                ;;
            slack_channel)
                log_info "Routing alert to Slack channel: ${name}"
                if command -v curl &>/dev/null && [[ -n "${OTTO_SLACK_TOKEN:-}" ]] && [[ -n "${OTTO_SLACK_CHANNEL_ID:-}" ]]; then
                    curl -s -X POST "https://slack.com/api/chat.postMessage" \
                        -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -d "{\"channel\":\"${OTTO_SLACK_CHANNEL_ID}\",\"text\":\"${formatted}\"}" >/dev/null 2>&1 || true
                fi
                ;;
            telegram)
                log_info "Routing alert to Telegram: ${name}"
                if command -v curl &>/dev/null && [[ -n "${OTTO_TELEGRAM_TOKEN:-}" ]] && [[ -n "${OTTO_TELEGRAM_CHAT_ID:-}" ]]; then
                    curl -s -X POST "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/sendMessage" \
                        -d "chat_id=${OTTO_TELEGRAM_CHAT_ID}" \
                        -d "text=${formatted}" >/dev/null 2>&1 || true
                fi
                ;;
            email|email_digest)
                log_info "Routing alert to email: ${name}"
                if command -v mail &>/dev/null && [[ -n "${OTTO_EMAIL_TO:-}" ]]; then
                    echo "${formatted}" | mail -s "[OTTO] ${severity^^}: ${name}" "${OTTO_EMAIL_TO}" 2>/dev/null || true
                fi
                ;;
            pagerduty)
                log_info "Routing alert to PagerDuty: ${name}"
                if command -v curl &>/dev/null && [[ -n "${OTTO_PAGERDUTY_KEY:-}" ]]; then
                    curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
                        -H "Content-Type: application/json" \
                        -d "{\"routing_key\":\"${OTTO_PAGERDUTY_KEY}\",\"event_action\":\"trigger\",\"payload\":{\"summary\":\"${formatted}\",\"severity\":\"${severity}\",\"source\":\"otto\"}}" >/dev/null 2>&1 || true
                fi
                ;;
            *)
                log_warn "Unknown routing target: ${target}"
                ;;
        esac
    done
}

# Dry-run: show which rules match and where alert would go.
# Usage: alert_router_test <alert_json>
alert_router_test() {
    local alert_json="$1"

    # Ensure rules are loaded
    if [[ -z "${_ALERT_ROUTING_RULES}" ]]; then
        alert_router_load_rules
    fi

    echo "=== Alert Router Dry-Run ==="
    echo "Alert: $(echo "${alert_json}" | jq -c '.')"
    echo "Routing enabled: ${_ALERT_ROUTING_ENABLED}"
    echo ""

    local rule_count i rule matched=0
    rule_count=$(echo "${_ALERT_ROUTING_RULES}" | jq 'length')

    for (( i = 0; i < rule_count; i++ )); do
        rule=$(echo "${_ALERT_ROUTING_RULES}" | jq ".[$i]")
        local match_desc
        match_desc=$(echo "${rule}" | jq -c '.match')
        local notify_desc
        notify_desc=$(echo "${rule}" | jq -c '.notify')

        if alert_router_match "${alert_json}" "${rule}"; then
            echo "  [MATCH] Rule #$((i+1)): match=${match_desc} -> notify=${notify_desc}"
            matched=1
        else
            echo "  [SKIP]  Rule #$((i+1)): match=${match_desc}"
        fi
    done

    if [[ "${matched}" -eq 0 ]]; then
        echo "  No rules matched. Default targets: $(echo "${_ALERT_ROUTING_DEFAULT_TARGETS}" | jq -c '.')"
    fi

    echo ""
    echo "Final targets: $(alert_route "${alert_json}")"
}
