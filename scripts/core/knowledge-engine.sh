#!/usr/bin/env bash
set -euo pipefail

# OTTO Knowledge Engine
# Provides contextual DevOps knowledge to agents and users.

OTTO_ROOT="${OTTO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
KNOWLEDGE_DIR="${OTTO_ROOT}/knowledge"
CUSTOM_KNOWLEDGE_DIR="${HOME}/.config/otto/knowledge"
INDEX_FILE="${OTTO_ROOT}/.knowledge-index"

# ── Helpers ──────────────────────────────────────────────────────────────────

_ensure_index() {
    if [[ ! -f "${INDEX_FILE}" ]]; then
        knowledge_index_rebuild
    fi
}

_score_file() {
    local query="$1"
    local file="$2"
    local score=0
    local word

    for word in ${query}; do
        local count
        count=$(grep -ci "${word}" "${file}" 2>/dev/null || true)
        score=$((score + count))
    done
    echo "${score}"
}

_search_dir() {
    local query="$1"
    local dir="$2"
    local results=()

    if [[ ! -d "${dir}" ]]; then
        return
    fi

    while IFS= read -r -d '' file; do
        local score
        score=$(_score_file "${query}" "${file}")
        if [[ "${score}" -gt 0 ]]; then
            results+=("${score}|${file}")
        fi
    done < <(find "${dir}" -name '*.md' -print0 2>/dev/null)

    # Sort by score descending
    if [[ ${#results[@]} -gt 0 ]]; then
        printf '%s\n' "${results[@]}" | sort -t'|' -k1 -nr
    fi
}

# ── Public Functions ─────────────────────────────────────────────────────────

knowledge_search() {
    local query="${1:?Usage: knowledge_search <query>}"
    local all_results=()
    local line

    while IFS= read -r line; do
        [[ -n "${line}" ]] && all_results+=("${line}")
    done < <(_search_dir "${query}" "${KNOWLEDGE_DIR}")

    while IFS= read -r line; do
        [[ -n "${line}" ]] && all_results+=("${line}")
    done < <(_search_dir "${query}" "${CUSTOM_KNOWLEDGE_DIR}")

    if [[ ${#all_results[@]} -eq 0 ]]; then
        echo "No results found for: ${query}"
        return 1
    fi

    printf '%s\n' "${all_results[@]}" | sort -t'|' -k1 -nr | head -20 | while IFS='|' read -r score file; do
        local rel
        rel="${file#"${OTTO_ROOT}"/}"
        rel="${rel#"${CUSTOM_KNOWLEDGE_DIR}"/}"
        printf '[score:%s] %s\n' "${score}" "${rel}"
    done
}

knowledge_get_for_topic() {
    local topic="${1:?Usage: knowledge_get_for_topic <topic>}"
    local found=0

    for subdir in best-practices troubleshooting runbooks patterns; do
        local dir="${KNOWLEDGE_DIR}/${subdir}"
        if [[ -d "${dir}" ]]; then
            while IFS= read -r -d '' file; do
                local score
                score=$(_score_file "${topic}" "${file}")
                if [[ "${score}" -gt 0 ]]; then
                    echo "──── ${file#"${OTTO_ROOT}"/} ────"
                    cat "${file}"
                    echo ""
                    found=1
                fi
            done < <(find "${dir}" -name '*.md' -print0 2>/dev/null)
        fi
    done

    # Also check custom knowledge
    if [[ -d "${CUSTOM_KNOWLEDGE_DIR}" ]]; then
        while IFS= read -r -d '' file; do
            local score
            score=$(_score_file "${topic}" "${file}")
            if [[ "${score}" -gt 0 ]]; then
                echo "──── [custom] ${file#"${CUSTOM_KNOWLEDGE_DIR}"/} ────"
                cat "${file}"
                echo ""
                found=1
            fi
        done < <(find "${CUSTOM_KNOWLEDGE_DIR}" -name '*.md' -print0 2>/dev/null)
    fi

    if [[ "${found}" -eq 0 ]]; then
        echo "No knowledge found for topic: ${topic}"
        return 1
    fi
}

knowledge_get_troubleshooting() {
    local symptom="${1:?Usage: knowledge_get_troubleshooting <symptom>}"
    local dir="${KNOWLEDGE_DIR}/troubleshooting"
    local found=0

    if [[ ! -d "${dir}" ]]; then
        echo "No troubleshooting knowledge available."
        return 1
    fi

    while IFS= read -r -d '' file; do
        local score
        score=$(_score_file "${symptom}" "${file}")
        if [[ "${score}" -gt 0 ]]; then
            echo "──── ${file##*/} (relevance: ${score}) ────"
            cat "${file}"
            echo ""
            found=1
        fi
    done < <(find "${dir}" -name '*.md' -print0 2>/dev/null)

    if [[ "${found}" -eq 0 ]]; then
        echo "No troubleshooting guide found for: ${symptom}"
        return 1
    fi
}

knowledge_get_runbook() {
    local task="${1:?Usage: knowledge_get_runbook <task>}"
    local dir="${KNOWLEDGE_DIR}/runbooks"
    local found=0

    if [[ ! -d "${dir}" ]]; then
        echo "No runbooks available."
        return 1
    fi

    while IFS= read -r -d '' file; do
        local score
        score=$(_score_file "${task}" "${file}")
        if [[ "${score}" -gt 0 ]]; then
            echo "──── ${file##*/} (relevance: ${score}) ────"
            cat "${file}"
            echo ""
            found=1
        fi
    done < <(find "${dir}" -name '*.md' -print0 2>/dev/null)

    if [[ "${found}" -eq 0 ]]; then
        echo "No runbook found for: ${task}"
        return 1
    fi
}

knowledge_get_best_practices() {
    local domain="${1:?Usage: knowledge_get_best_practices <domain>}"
    local dir="${KNOWLEDGE_DIR}/best-practices"
    local found=0

    if [[ ! -d "${dir}" ]]; then
        echo "No best practices available."
        return 1
    fi

    while IFS= read -r -d '' file; do
        local score
        score=$(_score_file "${domain}" "${file}")
        if [[ "${score}" -gt 0 ]]; then
            echo "──── ${file##*/} (relevance: ${score}) ────"
            cat "${file}"
            echo ""
            found=1
        fi
    done < <(find "${dir}" -name '*.md' -print0 2>/dev/null)

    if [[ "${found}" -eq 0 ]]; then
        echo "No best practices found for: ${domain}"
        return 1
    fi
}

knowledge_list_topics() {
    _ensure_index

    echo "Available Knowledge Topics:"
    echo ""

    for subdir in best-practices troubleshooting runbooks patterns; do
        local dir="${KNOWLEDGE_DIR}/${subdir}"
        if [[ -d "${dir}" ]]; then
            echo "  ${subdir}:"
            while IFS= read -r -d '' file; do
                local name
                name="$(basename "${file}" .md)"
                echo "    - ${name}"
            done < <(find "${dir}" -name '*.md' -print0 2>/dev/null | sort -z)
        fi
    done

    if [[ -d "${CUSTOM_KNOWLEDGE_DIR}" ]]; then
        echo ""
        echo "  custom:"
        while IFS= read -r -d '' file; do
            local rel
            rel="${file#"${CUSTOM_KNOWLEDGE_DIR}"/}"
            echo "    - ${rel}"
        done < <(find "${CUSTOM_KNOWLEDGE_DIR}" -name '*.md' -print0 2>/dev/null | sort -z)
    fi
}

knowledge_add_custom() {
    local type="${1:?Usage: knowledge_add_custom <type> <filename> <content>}"
    local filename="${2:?Usage: knowledge_add_custom <type> <filename> <content>}"
    local content="${3:?Usage: knowledge_add_custom <type> <filename> <content>}"

    local target_dir="${CUSTOM_KNOWLEDGE_DIR}/${type}"
    mkdir -p "${target_dir}"

    local target_file="${target_dir}/${filename}"
    printf '%s\n' "${content}" > "${target_file}"
    echo "Custom knowledge added: ${target_file}"

    # Rebuild index
    knowledge_index_rebuild
}

knowledge_index_rebuild() {
    local index_content=""

    for base_dir in "${KNOWLEDGE_DIR}" "${CUSTOM_KNOWLEDGE_DIR}"; do
        if [[ ! -d "${base_dir}" ]]; then
            continue
        fi
        while IFS= read -r -d '' file; do
            local tags
            # Extract first heading and any tags line as metadata
            tags=$(head -5 "${file}" | grep -i 'tags:' 2>/dev/null || true)
            local heading
            heading=$(head -3 "${file}" | grep '^#' 2>/dev/null | head -1 || true)
            index_content+="${file}|${heading}|${tags}"$'\n'
        done < <(find "${base_dir}" -name '*.md' -print0 2>/dev/null)
    done

    printf '%s' "${index_content}" > "${INDEX_FILE}"
    echo "Knowledge index rebuilt: $(wc -l < "${INDEX_FILE}") entries"
}

# ── CLI Entry Point ──────────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-help}"
    shift || true

    case "${cmd}" in
        search)             knowledge_search "$@" ;;
        topic)              knowledge_get_for_topic "$@" ;;
        troubleshooting)    knowledge_get_troubleshooting "$@" ;;
        runbook)            knowledge_get_runbook "$@" ;;
        best-practices)     knowledge_get_best_practices "$@" ;;
        list)               knowledge_list_topics ;;
        add)                knowledge_add_custom "$@" ;;
        reindex)            knowledge_index_rebuild ;;
        help|*)
            echo "OTTO Knowledge Engine"
            echo ""
            echo "Usage: knowledge-engine.sh <command> [args...]"
            echo ""
            echo "Commands:"
            echo "  search <query>                    Search all knowledge"
            echo "  topic <topic>                     Get knowledge for a topic"
            echo "  troubleshooting <symptom>         Find troubleshooting guide"
            echo "  runbook <task>                    Find runbook for a task"
            echo "  best-practices <domain>           Get best practices"
            echo "  list                              List all topics"
            echo "  add <type> <filename> <content>   Add custom knowledge"
            echo "  reindex                           Rebuild knowledge index"
            ;;
    esac
fi
