#!/usr/bin/env bash
# OTTO - Issue/Incident Context Memory
# Saves, loads, and searches incident contexts for pattern matching.
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_INCIDENT_MEMORY_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_INCIDENT_MEMORY_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"

# Incident storage
INCIDENT_DIR="${OTTO_HOME}/state/incidents"

# --- Internal ---

_incident_memory_init() {
    mkdir -p "${INCIDENT_DIR}"
}

# --- Public API ---

# Save incident context.
# Usage: incident_memory_save <incident_id> <context_json>
# context_json should contain: symptoms, checks_run, hypotheses, actions_taken, resolution, etc.
incident_memory_save() {
    local incident_id="$1"
    local context_json="$2"
    _incident_memory_init

    local incident_file="${INCIDENT_DIR}/${incident_id}.json"
    local now
    now=$(date -Iseconds)

    # Merge with existing data if present
    if [[ -f "${incident_file}" ]]; then
        local existing
        existing=$(cat "${incident_file}")
        echo "${existing}" | jq --argjson ctx "${context_json}" --arg ts "${now}" '
            . * $ctx | .updated_at = $ts
        ' > "${incident_file}"
    else
        echo "${context_json}" | jq --arg id "${incident_id}" --arg ts "${now}" '
            . + {"incident_id": $id, "created_at": $ts, "updated_at": $ts, "linked_incidents": [], "timeline": []}
        ' > "${incident_file}"
    fi

    log_info "Incident context saved: ${incident_id}"
}

# Load incident context.
# Usage: incident_memory_load <incident_id>
incident_memory_load() {
    local incident_id="$1"
    local incident_file="${INCIDENT_DIR}/${incident_id}.json"

    if [[ ! -f "${incident_file}" ]]; then
        log_warn "Incident not found: ${incident_id}"
        echo "null"
        return 1
    fi

    cat "${incident_file}"
}

# Find past incidents with similar symptoms (keyword matching).
# Usage: incident_memory_find_similar <symptoms>
# symptoms: space-separated keywords or a short description
incident_memory_find_similar() {
    local symptoms="$1"
    _incident_memory_init

    # Tokenize symptoms into keywords
    local -a keywords=()
    for word in ${symptoms}; do
        # Skip very short words
        if [[ ${#word} -ge 3 ]]; then
            keywords+=("$(echo "${word}" | tr '[:upper:]' '[:lower:]')")
        fi
    done

    if [[ ${#keywords[@]} -eq 0 ]]; then
        echo "[]"
        return 0
    fi

    local results="[]"

    for incident_file in "${INCIDENT_DIR}"/*.json; do
        [[ -f "${incident_file}" ]] || continue

        local content
        content=$(cat "${incident_file}" | tr '[:upper:]' '[:lower:]')
        local match_count=0

        for kw in "${keywords[@]}"; do
            if echo "${content}" | grep -q "${kw}"; then
                match_count=$((match_count + 1))
            fi
        done

        if [[ ${match_count} -gt 0 ]]; then
            local incident_id score
            incident_id=$(jq -r '.incident_id // "unknown"' "${incident_file}")
            score=$((match_count * 100 / ${#keywords[@]}))

            results=$(echo "${results}" | jq --arg id "${incident_id}" --argjson score "${score}" \
                '. + [{"incident_id": $id, "similarity_score": $score}]')
        fi
    done

    # Sort by score descending
    echo "${results}" | jq 'sort_by(-.similarity_score)'
}

# Link related incidents.
# Usage: incident_memory_link <incident_id1> <incident_id2>
incident_memory_link() {
    local id1="$1"
    local id2="$2"
    _incident_memory_init

    local file1="${INCIDENT_DIR}/${id1}.json"
    local file2="${INCIDENT_DIR}/${id2}.json"

    if [[ ! -f "${file1}" ]]; then
        log_error "Incident not found: ${id1}"
        return 1
    fi
    if [[ ! -f "${file2}" ]]; then
        log_error "Incident not found: ${id2}"
        return 1
    fi

    # Add link to both incidents (idempotent)
    local tmp
    tmp=$(jq --arg linked "${id2}" '.linked_incidents = ((.linked_incidents // []) + [$linked] | unique)' "${file1}")
    echo "${tmp}" > "${file1}"

    tmp=$(jq --arg linked "${id1}" '.linked_incidents = ((.linked_incidents // []) + [$linked] | unique)' "${file2}")
    echo "${tmp}" > "${file2}"

    log_info "Linked incidents: ${id1} <-> ${id2}"
}

# Build timeline from audit log + incident context.
# Usage: incident_memory_timeline <incident_id>
incident_memory_timeline() {
    local incident_id="$1"
    _incident_memory_init

    local incident_file="${INCIDENT_DIR}/${incident_id}.json"
    if [[ ! -f "${incident_file}" ]]; then
        log_error "Incident not found: ${incident_id}"
        echo "[]"
        return 1
    fi

    local timeline="[]"

    # Add incident context events
    local created_at
    created_at=$(jq -r '.created_at // ""' "${incident_file}")
    if [[ -n "${created_at}" ]]; then
        timeline=$(echo "${timeline}" | jq --arg ts "${created_at}" '. + [{"timestamp": $ts, "type": "incident_created", "detail": "Incident opened"}]')
    fi

    # Add actions taken from context
    local actions
    actions=$(jq -r '.actions_taken // [] | .[]' "${incident_file}" 2>/dev/null || true)
    while IFS= read -r action; do
        [[ -z "${action}" ]] && continue
        timeline=$(echo "${timeline}" | jq --arg a "${action}" --arg ts "${created_at}" \
            '. + [{"timestamp": $ts, "type": "action", "detail": $a}]')
    done <<< "${actions}"

    # Add entries from audit log if available
    local audit_file="${OTTO_HOME}/state/audit.jsonl"
    if [[ -f "${audit_file}" ]]; then
        local audit_entries
        audit_entries=$(grep -i "${incident_id}" "${audit_file}" 2>/dev/null || true)
        while IFS= read -r entry; do
            [[ -z "${entry}" ]] && continue
            local ts detail
            ts=$(echo "${entry}" | jq -r '.timestamp // ""' 2>/dev/null || echo "")
            detail=$(echo "${entry}" | jq -r '.action // ""' 2>/dev/null || echo "")
            if [[ -n "${ts}" ]]; then
                timeline=$(echo "${timeline}" | jq --arg ts "${ts}" --arg d "${detail}" \
                    '. + [{"timestamp": $ts, "type": "audit", "detail": $d}]')
            fi
        done <<< "${audit_entries}"
    fi

    # Add inline timeline entries from incident context
    local ctx_timeline
    ctx_timeline=$(jq -c '.timeline // []' "${incident_file}")
    timeline=$(echo "${timeline}" | jq --argjson ct "${ctx_timeline}" '. + $ct')

    # Sort by timestamp
    echo "${timeline}" | jq 'sort_by(.timestamp)'
}
