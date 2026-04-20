#!/usr/bin/env bash
# OTTO - Offline Mode with Cache and Notification Queue
# Caches fetch results, queues notifications when offline, and flushes on reconnect.
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_OFFLINE_CACHE_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_OFFLINE_CACHE_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"

# Cache and queue paths
CACHE_DIR="${OTTO_HOME}/state/cache"
CACHE_QUEUE_FILE="${OTTO_HOME}/state/notification-queue.jsonl"
CACHE_STATUS_FILE="${CACHE_DIR}/.status.json"

# --- Internal ---

_cache_init() {
    mkdir -p "${CACHE_DIR}"
    if [[ ! -f "${CACHE_QUEUE_FILE}" ]]; then
        touch "${CACHE_QUEUE_FILE}"
    fi
}

# --- Public API ---

# Save fetch result to cache.
# Usage: cache_save <key> <data>
cache_save() {
    local key="$1"
    local data="$2"
    _cache_init

    local now
    now=$(date +%s)
    local cache_file="${CACHE_DIR}/${key}.json"

    jq -n --arg data "${data}" --argjson ts "${now}" '{"data": ($data | try fromjson catch $data), "cached_at": $ts}' > "${cache_file}"

    log_debug "Cache saved: ${key}"
}

# Get cached data if not expired.
# Usage: cache_get <key> <max_age_seconds>
# Returns the cached data or empty string if expired/missing. Exit code 1 if miss.
cache_get() {
    local key="$1"
    local max_age="${2:-3600}"
    _cache_init

    local cache_file="${CACHE_DIR}/${key}.json"

    if [[ ! -f "${cache_file}" ]]; then
        log_debug "Cache miss: ${key} (not found)"
        return 1
    fi

    local cached_at now age
    cached_at=$(jq -r '.cached_at // 0' "${cache_file}")
    now=$(date +%s)
    age=$((now - cached_at))

    if [[ ${age} -gt ${max_age} ]]; then
        log_debug "Cache miss: ${key} (expired, age=${age}s > max=${max_age}s)"
        return 1
    fi

    jq -r '.data' "${cache_file}"
    log_debug "Cache hit: ${key} (age=${age}s)"
}

# Remove cached data.
# Usage: cache_invalidate <key>
cache_invalidate() {
    local key="$1"
    local cache_file="${CACHE_DIR}/${key}.json"

    if [[ -f "${cache_file}" ]]; then
        rm -f "${cache_file}"
        log_debug "Cache invalidated: ${key}"
    fi
}

# Check internet connectivity.
# Usage: cache_is_online
# Returns 0 if online, 1 if offline.
cache_is_online() {
    # Try multiple methods
    if curl -s --max-time 3 --head "https://1.1.1.1" >/dev/null 2>&1; then
        return 0
    fi
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        return 0
    fi
    if curl -s --max-time 3 --head "https://www.google.com" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Queue notification for later delivery.
# Usage: cache_queue_notification <channel> <message>
cache_queue_notification() {
    local channel="$1"
    local message="$2"
    _cache_init

    local now
    now=$(date -Iseconds)

    jq -n -c --arg ch "${channel}" --arg msg "${message}" --arg ts "${now}" \
        '{"channel": $ch, "message": $msg, "queued_at": $ts}' >> "${CACHE_QUEUE_FILE}"

    log_info "Notification queued for ${channel} (offline mode)"
}

# Send all queued notifications.
# Usage: cache_flush_queue
cache_flush_queue() {
    _cache_init

    if [[ ! -s "${CACHE_QUEUE_FILE}" ]]; then
        log_debug "Notification queue is empty"
        return 0
    fi

    if ! cache_is_online; then
        log_warn "Still offline, cannot flush notification queue"
        return 1
    fi

    local total=0 sent=0 failed=0
    local tmpfile="${CACHE_QUEUE_FILE}.tmp"
    : > "${tmpfile}"

    while IFS= read -r entry; do
        [[ -z "${entry}" ]] && continue
        total=$((total + 1))

        local channel message
        channel=$(echo "${entry}" | jq -r '.channel')
        message=$(echo "${entry}" | jq -r '.message')

        local success=false

        case "${channel}" in
            slack|slack_channel|slack_oncall)
                if [[ -n "${OTTO_SLACK_TOKEN:-}" ]] && [[ -n "${OTTO_SLACK_CHANNEL_ID:-}" ]]; then
                    local target_channel="${OTTO_SLACK_CHANNEL_ID}"
                    if [[ "${channel}" == "slack_oncall" ]] && [[ -n "${OTTO_SLACK_ONCALL_CHANNEL:-}" ]]; then
                        target_channel="${OTTO_SLACK_ONCALL_CHANNEL}"
                    fi
                    if curl -s -X POST "https://slack.com/api/chat.postMessage" \
                        -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -d "{\"channel\":\"${target_channel}\",\"text\":\"${message}\"}" 2>/dev/null | jq -e '.ok == true' >/dev/null 2>&1; then
                        success=true
                    fi
                fi
                ;;
            telegram)
                if [[ -n "${OTTO_TELEGRAM_TOKEN:-}" ]] && [[ -n "${OTTO_TELEGRAM_CHAT_ID:-}" ]]; then
                    if curl -s -X POST "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/sendMessage" \
                        -d "chat_id=${OTTO_TELEGRAM_CHAT_ID}" \
                        --data-urlencode "text=${message}" 2>/dev/null | jq -e '.ok == true' >/dev/null 2>&1; then
                        success=true
                    fi
                fi
                ;;
            email)
                if command -v mail &>/dev/null && [[ -n "${OTTO_EMAIL_TO:-}" ]]; then
                    if echo "${message}" | mail -s "[OTTO] Queued Notification" "${OTTO_EMAIL_TO}" 2>/dev/null; then
                        success=true
                    fi
                fi
                ;;
            *)
                log_warn "Unknown queue channel: ${channel}"
                ;;
        esac

        if [[ "${success}" == "true" ]]; then
            sent=$((sent + 1))
        else
            failed=$((failed + 1))
            # Keep failed entries for retry
            echo "${entry}" >> "${tmpfile}"
        fi
    done < "${CACHE_QUEUE_FILE}"

    mv "${tmpfile}" "${CACHE_QUEUE_FILE}"
    log_info "Queue flush: ${sent}/${total} sent, ${failed} remaining"
}

# Show cache stats.
# Usage: cache_status
cache_status() {
    _cache_init

    local cached_items=0 total_size=0 queue_size=0
    local oldest_ts="" newest_ts=""

    if [[ -d "${CACHE_DIR}" ]]; then
        cached_items=$(find "${CACHE_DIR}" -maxdepth 1 -name '*.json' -not -name '.status.json' 2>/dev/null | wc -l)
        total_size=$(du -sh "${CACHE_DIR}" 2>/dev/null | awk '{print $1}' || echo "0")

        # Find oldest and newest
        for f in "${CACHE_DIR}"/*.json; do
            [[ -f "${f}" ]] || continue
            [[ "$(basename "${f}")" == ".status.json" ]] && continue
            local ts
            ts=$(jq -r '.cached_at // 0' "${f}" 2>/dev/null || echo "0")
            if [[ -z "${oldest_ts}" || "${ts}" -lt "${oldest_ts}" ]]; then
                oldest_ts="${ts}"
            fi
            if [[ -z "${newest_ts}" || "${ts}" -gt "${newest_ts}" ]]; then
                newest_ts="${ts}"
            fi
        done
    fi

    if [[ -f "${CACHE_QUEUE_FILE}" ]]; then
        queue_size=$(wc -l < "${CACHE_QUEUE_FILE}" | tr -d ' ')
    fi

    local online_status="unknown"
    if cache_is_online; then
        online_status="online"
    else
        online_status="offline"
    fi

    local oldest_date="n/a" newest_date="n/a"
    if [[ -n "${oldest_ts}" && "${oldest_ts}" != "0" ]]; then
        oldest_date=$(date -d "@${oldest_ts}" -Iseconds 2>/dev/null || date -r "${oldest_ts}" -Iseconds 2>/dev/null || echo "${oldest_ts}")
    fi
    if [[ -n "${newest_ts}" && "${newest_ts}" != "0" ]]; then
        newest_date=$(date -d "@${newest_ts}" -Iseconds 2>/dev/null || date -r "${newest_ts}" -Iseconds 2>/dev/null || echo "${newest_ts}")
    fi

    jq -n \
        --argjson items "${cached_items}" \
        --arg size "${total_size}" \
        --argjson queue "${queue_size}" \
        --arg status "${online_status}" \
        --arg oldest "${oldest_date}" \
        --arg newest "${newest_date}" \
        '{
            cached_items: $items,
            cache_size: $size,
            queue_size: $queue,
            connectivity: $status,
            oldest_entry: $oldest,
            newest_entry: $newest
        }'
}
