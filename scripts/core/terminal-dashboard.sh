#!/usr/bin/env bash
# OTTO - Rich Terminal UI Dashboard
# Provides colored terminal dashboard with box drawing, tables, and status bars.
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_TUI_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_TUI_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# Terminal dimensions
TUI_COLS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
TUI_ROWS="${LINES:-$(tput lines 2>/dev/null || echo 24)}"

# Box drawing characters
readonly TUI_TL="┌" TUI_TR="┐" TUI_BL="└" TUI_BR="┘"
readonly TUI_H="─" TUI_V="│"
readonly TUI_LT="├" TUI_RT="┤" TUI_TT="┬" TUI_BT="┴" TUI_CR="┼"

# --- Public API ---

# Draw a horizontal separator line.
tui_separator() {
    local width="${1:-${TUI_COLS}}"
    printf '%*s\n' "${width}" '' | tr ' ' "${TUI_H}"
}

# Draw a box around content with a title.
# Usage: tui_box <title> <content>
tui_box() {
    local title="$1"
    local content="$2"
    local width="${3:-${TUI_COLS}}"
    local inner=$((width - 2))

    # Top border
    local title_len=${#title}
    local pad_after=$((inner - title_len - 2))
    if [[ ${pad_after} -lt 0 ]]; then pad_after=0; fi

    printf '%s%s %s ' "${TUI_TL}" "${TUI_H}" "${title}"
    printf '%*s' "${pad_after}" '' | tr ' ' "${TUI_H}"
    printf '%s\n' "${TUI_TR}"

    # Content lines
    while IFS= read -r line; do
        local stripped
        stripped=$(echo -e "${line}" | sed 's/\x1b\[[0-9;]*m//g')
        local line_len=${#stripped}
        local pad=$((inner - line_len))
        if [[ ${pad} -lt 0 ]]; then pad=0; fi
        printf '%s%s%*s%s\n' "${TUI_V}" "${line}" "${pad}" '' "${TUI_V}"
    done <<< "${content}"

    # Bottom border
    printf '%s' "${TUI_BL}"
    printf '%*s' "${inner}" '' | tr ' ' "${TUI_H}"
    printf '%s\n' "${TUI_BR}"
}

# Colored progress/health bar.
# Usage: tui_health_bar <label> <percent>
tui_health_bar() {
    local label="$1"
    local percent="$2"
    local bar_width=30
    local filled=$(( (percent * bar_width) / 100 ))
    local empty=$((bar_width - filled))

    # Color based on threshold
    local color
    if [[ ${percent} -ge 80 ]]; then
        color="${COLOR_GREEN:-\033[32m}"
    elif [[ ${percent} -ge 50 ]]; then
        color="${COLOR_YELLOW:-\033[33m}"
    else
        color="${COLOR_RED:-\033[31m}"
    fi
    local reset="${COLOR_RESET:-\033[0m}"

    local bar=""
    if [[ ${filled} -gt 0 ]]; then
        bar+=$(printf '%*s' "${filled}" '' | tr ' ' '█')
    fi
    if [[ ${empty} -gt 0 ]]; then
        bar+=$(printf '%*s' "${empty}" '' | tr ' ' '░')
    fi

    printf '  %-20s %b%s%b %3d%%\n' "${label}" "${color}" "${bar}" "${reset}" "${percent}"
}

# Status line with colored indicator.
# Usage: tui_status_line <label> <status>
# status: ok, warning, critical, unknown
tui_status_line() {
    local label="$1"
    local status="$2"

    local indicator color
    local reset="${COLOR_RESET:-\033[0m}"

    case "${status}" in
        ok|healthy|running|up)
            indicator="●"
            color="${COLOR_GREEN:-\033[32m}"
            ;;
        warning|degraded)
            indicator="●"
            color="${COLOR_YELLOW:-\033[33m}"
            ;;
        critical|error|down|failed)
            indicator="●"
            color="${COLOR_RED:-\033[31m}"
            ;;
        *)
            indicator="○"
            color="${COLOR_DIM:-\033[2m}"
            ;;
    esac

    printf '  %b%s%b %-30s %s\n' "${color}" "${indicator}" "${reset}" "${label}" "${status}"
}

# Colored alert list from JSON array.
# Usage: tui_alert_list <alerts_json>
tui_alert_list() {
    local alerts_json="$1"
    local reset="${COLOR_RESET:-\033[0m}"

    local count
    count=$(echo "${alerts_json}" | jq 'length')

    if [[ "${count}" -eq 0 ]]; then
        echo "  No active alerts."
        return 0
    fi

    local i
    for (( i = 0; i < count; i++ )); do
        local severity name message timestamp
        severity=$(echo "${alerts_json}" | jq -r ".[$i].severity // \"info\"")
        name=$(echo "${alerts_json}" | jq -r ".[$i].name // \"unknown\"")
        message=$(echo "${alerts_json}" | jq -r ".[$i].message // \"\"")
        timestamp=$(echo "${alerts_json}" | jq -r ".[$i].timestamp // \"\"")

        local color
        case "${severity}" in
            critical) color="${COLOR_RED:-\033[31m}" ;;
            warning)  color="${COLOR_YELLOW:-\033[33m}" ;;
            info)     color="${COLOR_CYAN:-\033[36m}" ;;
            *)        color="${COLOR_DIM:-\033[2m}" ;;
        esac

        printf '  %b[%s]%b %-25s %s  %s\n' "${color}" "${severity^^}" "${reset}" "${name}" "${message}" "${timestamp}"
    done
}

# Simple table with alignment.
# Usage: tui_table <headers_csv> <rows_json>
# headers_csv: "Name,Status,CPU,Memory"
# rows_json: [["app1","ok","10%","256Mi"], ...]
tui_table() {
    local headers_csv="$1"
    local rows_json="$2"

    # Parse headers
    IFS=',' read -ra headers <<< "${headers_csv}"
    local num_cols=${#headers[@]}

    # Calculate column widths
    local -a widths=()
    for (( c = 0; c < num_cols; c++ )); do
        widths[${c}]=${#headers[${c}]}
    done

    local row_count
    row_count=$(echo "${rows_json}" | jq 'length')

    local i c
    for (( i = 0; i < row_count; i++ )); do
        for (( c = 0; c < num_cols; c++ )); do
            local val
            val=$(echo "${rows_json}" | jq -r ".[$i][$c] // \"\"")
            local val_len=${#val}
            if [[ ${val_len} -gt ${widths[${c}]} ]]; then
                widths[${c}]=${val_len}
            fi
        done
    done

    # Print header
    printf '  '
    for (( c = 0; c < num_cols; c++ )); do
        printf "%-$((widths[${c}] + 2))s" "${headers[${c}]}"
    done
    printf '\n  '
    for (( c = 0; c < num_cols; c++ )); do
        printf '%*s  ' "${widths[${c}]}" '' | tr ' ' '-'
    done
    printf '\n'

    # Print rows
    for (( i = 0; i < row_count; i++ )); do
        printf '  '
        for (( c = 0; c < num_cols; c++ )); do
            local val
            val=$(echo "${rows_json}" | jq -r ".[$i][$c] // \"\"")
            printf "%-$((widths[${c}] + 2))s" "${val}"
        done
        printf '\n'
    done
}

# Clear screen and render full dashboard.
# Usage: tui_clear_and_render
tui_clear_and_render() {
    clear
    tui_render
}

# Full terminal dashboard with colors and box drawing.
# Usage: tui_render
tui_render() {
    # Refresh terminal dimensions
    TUI_COLS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
    local reset="${COLOR_RESET:-\033[0m}"
    local bold="${COLOR_BOLD:-\033[1m}"

    # Header
    printf '%b' "${bold}"
    tui_box "OTTO Dashboard - $(date '+%Y-%m-%d %H:%M:%S')" "  Operations & Technology Toolchain Orchestrator" "${TUI_COLS}"
    printf '%b' "${reset}"
    echo ""

    # System Health section
    local health_content=""
    if [[ -f "${OTTO_HOME}/state/state.json" ]]; then
        local state
        state=$(cat "${OTTO_HOME}/state/state.json" 2>/dev/null || echo '{}')

        # Extract health metrics if available
        local overall_status
        overall_status=$(echo "${state}" | jq -r '.health.status // "unknown"')
        health_content+="$(tui_status_line "Overall" "${overall_status}")"
    else
        health_content+="$(tui_status_line "State" "unknown")"
    fi

    tui_box "System Health" "${health_content}" "${TUI_COLS}"
    echo ""

    # Alerts section
    local alerts_json="[]"
    local alerts_dir="${OTTO_HOME}/state/alerts"
    if [[ -d "${alerts_dir}" ]]; then
        alerts_json=$(cat "${alerts_dir}"/*.json 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")
    fi

    local alerts_content
    alerts_content=$(tui_alert_list "${alerts_json}")
    tui_box "Active Alerts" "${alerts_content}" "${TUI_COLS}"
    echo ""

    # Quick stats
    local stats_content=""
    local task_dirs=("triage" "todo" "in-progress" "done" "failed")
    for dir in "${task_dirs[@]}"; do
        local count=0
        if [[ -d "${OTTO_HOME}/state/tasks/${dir}" ]]; then
            count=$(find "${OTTO_HOME}/state/tasks/${dir}" -maxdepth 1 -type f 2>/dev/null | wc -l)
        fi
        stats_content+="  ${dir}: ${count}\n"
    done

    tui_box "Tasks" "$(echo -e "${stats_content}")" "${TUI_COLS}"
}
