#!/usr/bin/env bash
set -euo pipefail

# OTTO Adaptive UX
# Adapts OTTO's behavior based on user experience level.

OTTO_ROOT="${OTTO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
UX_CONFIG_DIR="${HOME}/.config/otto"
UX_STATE_FILE="${UX_CONFIG_DIR}/ux-state.json"
UX_HISTORY_FILE="${UX_CONFIG_DIR}/interaction-history.log"

_ux_ensure_state() {
    mkdir -p "${UX_CONFIG_DIR}"
    if [[ ! -f "${UX_STATE_FILE}" ]]; then
        cat > "${UX_STATE_FILE}" <<'EOJSON'
{
  "level": "auto",
  "detected_level": "beginner",
  "total_interactions": 0,
  "successful_interactions": 0,
  "complex_commands_used": 0,
  "tools_known": []
}
EOJSON
    fi
    if [[ ! -f "${UX_HISTORY_FILE}" ]]; then
        touch "${UX_HISTORY_FILE}"
    fi
}

_ux_read_field() {
    local field="$1"
    _ux_ensure_state
    grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "${UX_STATE_FILE}" 2>/dev/null \
        | head -1 | sed 's/.*: *"\([^"]*\)"/\1/' || echo ""
}

_ux_read_int_field() {
    local field="$1"
    _ux_ensure_state
    grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[0-9]*" "${UX_STATE_FILE}" 2>/dev/null \
        | head -1 | sed 's/.*: *//' || echo "0"
}

_ux_write_field() {
    local field="$1"
    local value="$2"
    _ux_ensure_state
    local tmp="${UX_STATE_FILE}.tmp"
    if [[ "${value}" =~ ^[0-9]+$ ]]; then
        sed "s/\"${field}\"[[:space:]]*:[[:space:]]*[0-9]*/\"${field}\": ${value}/" \
            "${UX_STATE_FILE}" > "${tmp}"
    else
        sed "s/\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"${field}\": \"${value}\"/" \
            "${UX_STATE_FILE}" > "${tmp}"
    fi
    mv "${tmp}" "${UX_STATE_FILE}"
}

# ── Public Functions ─────────────────────────────────────────────────────────

ux_get_level() {
    _ux_ensure_state
    local level
    level=$(_ux_read_field "level")
    if [[ "${level}" == "auto" ]]; then
        level=$(_ux_read_field "detected_level")
        [[ -z "${level}" ]] && level="beginner"
    fi
    echo "${level}"
}

ux_detect_level() {
    _ux_ensure_state

    local total
    total=$(_ux_read_int_field "total_interactions")
    local successful
    successful=$(_ux_read_int_field "successful_interactions")
    local complex
    complex=$(_ux_read_int_field "complex_commands_used")

    local detected="beginner"

    if [[ "${total}" -gt 100 ]]; then
        local success_rate=0
        if [[ "${total}" -gt 0 ]]; then
            success_rate=$(( (successful * 100) / total ))
        fi

        if [[ "${complex}" -gt 50 && "${success_rate}" -gt 90 ]]; then
            detected="expert"
        elif [[ "${complex}" -gt 20 && "${success_rate}" -gt 80 ]]; then
            detected="advanced"
        elif [[ "${total}" -gt 50 && "${success_rate}" -gt 60 ]]; then
            detected="intermediate"
        fi
    elif [[ "${total}" -gt 30 ]]; then
        if [[ "${complex}" -gt 10 ]]; then
            detected="intermediate"
        fi
    fi

    _ux_write_field "detected_level" "${detected}"
    echo "${detected}"
}

ux_set_level() {
    local level="${1:?Usage: ux_set_level <beginner|intermediate|advanced|expert|auto>}"

    case "${level}" in
        beginner|intermediate|advanced|expert|auto) ;;
        *)
            echo "Error: Invalid level '${level}'. Must be: beginner, intermediate, advanced, expert, auto" >&2
            return 1
            ;;
    esac

    _ux_write_field "level" "${level}"
    echo "Experience level set to: ${level}"
}

ux_should_explain() {
    local level
    level=$(ux_get_level)
    case "${level}" in
        beginner|intermediate) return 0 ;;
        *) return 1 ;;
    esac
}

ux_should_suggest_alternatives() {
    local level
    level=$(ux_get_level)
    case "${level}" in
        beginner) return 0 ;;
        *) return 1 ;;
    esac
}

ux_should_show_tutorial() {
    local level
    level=$(ux_get_level)
    case "${level}" in
        beginner) return 0 ;;
        *) return 1 ;;
    esac
}

ux_format_response() {
    local level="${1:?Usage: ux_format_response <level> <content>}"
    local content="${2:?Usage: ux_format_response <level> <content>}"

    case "${level}" in
        beginner)
            echo "ℹ️  ${content}"
            echo ""
            echo "💡 Tip: Use 'otto help <command>' for more details on any command."
            ;;
        intermediate)
            echo "${content}"
            ;;
        advanced|expert)
            # Compact output, no extras
            echo "${content}"
            ;;
        *)
            echo "${content}"
            ;;
    esac
}

ux_track_interaction() {
    local command="${1:?Usage: ux_track_interaction <command> <success>}"
    local success="${2:?Usage: ux_track_interaction <command> <success>}"

    _ux_ensure_state

    # Log the interaction
    printf '%s|%s|%s\n' "$(date -Iseconds)" "${command}" "${success}" >> "${UX_HISTORY_FILE}"

    # Update counters
    local total
    total=$(_ux_read_int_field "total_interactions")
    _ux_write_field "total_interactions" "$(( total + 1 ))"

    if [[ "${success}" == "true" || "${success}" == "1" ]]; then
        local successful
        successful=$(_ux_read_int_field "successful_interactions")
        _ux_write_field "successful_interactions" "$(( successful + 1 ))"
    fi

    # Check if command is "complex" (pipes, multiple flags, advanced tools)
    if [[ "${command}" == *"|"* || "${command}" == *"&&"* || \
          "${command}" == *"kubectl"* || "${command}" == *"terraform"* || \
          "${command}" == *"ansible"* || "${command}" == *"helm"* ]]; then
        local complex
        complex=$(_ux_read_int_field "complex_commands_used")
        _ux_write_field "complex_commands_used" "$(( complex + 1 ))"
    fi

    # Re-detect level periodically
    if (( (total + 1) % 20 == 0 )); then
        ux_detect_level > /dev/null
    fi
}

# ── CLI Entry Point ──────────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-help}"
    shift || true

    case "${cmd}" in
        get-level)      ux_get_level ;;
        detect)         ux_detect_level ;;
        set-level)      ux_set_level "$@" ;;
        explain?)       ux_should_explain && echo "yes" || echo "no" ;;
        alternatives?)  ux_should_suggest_alternatives && echo "yes" || echo "no" ;;
        tutorial?)      ux_should_show_tutorial && echo "yes" || echo "no" ;;
        format)         ux_format_response "$@" ;;
        track)          ux_track_interaction "$@" ;;
        help|*)
            echo "OTTO Adaptive UX"
            echo ""
            echo "Usage: adaptive-ux.sh <command> [args...]"
            echo ""
            echo "Commands:"
            echo "  get-level                    Get current experience level"
            echo "  detect                       Auto-detect experience level"
            echo "  set-level <level>            Set level (beginner|intermediate|advanced|expert|auto)"
            echo "  explain?                     Should explanations be shown?"
            echo "  alternatives?                Should alternatives be suggested?"
            echo "  tutorial?                    Should tutorials be offered?"
            echo "  format <level> <content>     Format response for level"
            echo "  track <command> <success>    Track an interaction"
            ;;
    esac
fi
