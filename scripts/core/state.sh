#!/usr/bin/env bash
# OTTO - State management
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_STATE_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_STATE_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

# State directory and files
OTTO_STATE_DIR="${OTTO_HOME}/state"
OTTO_STATE_FILE="${OTTO_STATE_DIR}/state.json"
OTTO_LOG_JSONL="${OTTO_STATE_DIR}/log.jsonl"

# Task status directories (kanban-style)
readonly -a OTTO_TASK_STATUSES=(triage todo in-progress done failed cancelled)

# --- Public API ---

# Initialize the state directory structure.
# Creates all required directories and files if they do not exist.
state_init() {
    log_debug "Initializing state directory: ${OTTO_STATE_DIR}"

    mkdir -p "${OTTO_STATE_DIR}"
    mkdir -p "${OTTO_STATE_DIR}/tasks"
    mkdir -p "${OTTO_STATE_DIR}/memory"
    mkdir -p "${OTTO_STATE_DIR}/night-watch"

    # Create task status directories
    local status
    for status in "${OTTO_TASK_STATUSES[@]}"; do
        mkdir -p "${OTTO_STATE_DIR}/tasks/${status}"
    done

    # Initialize state.json if missing
    if [[ ! -f "${OTTO_STATE_FILE}" ]]; then
        _state_create_initial
    fi

    # Initialize log.jsonl if missing
    if [[ ! -f "${OTTO_LOG_JSONL}" ]]; then
        touch "${OTTO_LOG_JSONL}"
    fi

    log_debug "State directory initialized"
}

# Read a value from state.json.
#   $1 - jq path expression (e.g. ".last_heartbeat")
#   $2 - Default value if the key does not exist (optional)
state_get() {
    local key="$1"
    local default="${2:-}"

    json_get "${OTTO_STATE_FILE}" "${key}" "${default}"
}

# Write a value to state.json.
#   $1 - jq path expression (e.g. ".last_heartbeat")
#   $2 - Value (JSON literal: string must be quoted, numbers bare)
state_set() {
    local key="$1"
    local value="$2"

    # Ensure state file exists
    if [[ ! -f "${OTTO_STATE_FILE}" ]]; then
        _state_create_initial
    fi

    json_set "${OTTO_STATE_FILE}" "${key}" "${value}"

    # Update the last-modified timestamp
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    json_set "${OTTO_STATE_FILE}" ".updated_at" "\"${now}\""
}

# Append a structured log entry to log.jsonl.
#   $1 - Level (debug|info|warn|error)
#   $2 - Agent name (e.g. "orchestrator", "infra")
#   $3 - Log message
state_log() {
    local level="$1"
    local agent="$2"
    local message="$3"

    # Ensure log file parent exists
    if [[ ! -d "${OTTO_STATE_DIR}" ]]; then
        mkdir -p "${OTTO_STATE_DIR}"
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Escape special characters for JSON safety
    local escaped_message
    escaped_message=$(printf '%s' "${message}" | jq -Rs '.')

    printf '{"ts":"%s","level":"%s","agent":"%s","msg":%s}\n' \
        "${timestamp}" "${level}" "${agent}" "${escaped_message}" \
        >> "${OTTO_LOG_JSONL}"
}

# Create a new task as a markdown file with YAML frontmatter.
#   $1 - Task title
#   $2 - Task description
#   $3 - Priority (critical|high|medium|low)
#   $4 - Assigned agent (optional, defaults to "unassigned")
# Outputs the task ID on stdout.
task_create() {
    local title="$1"
    local description="${2:-}"
    local priority="${3:-medium}"
    local agent="${4:-unassigned}"

    # Validate priority
    case "${priority}" in
        critical|high|medium|low) ;;
        *)
            log_error "Invalid task priority: '${priority}' (expected critical|high|medium|low)"
            return 1
            ;;
    esac

    # Generate a unique task ID: timestamp + random suffix
    local task_id
    task_id="$(date -u +%Y%m%d%H%M%S)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local task_dir="${OTTO_STATE_DIR}/tasks/triage"
    mkdir -p "${task_dir}"

    local task_file="${task_dir}/${task_id}.md"

    # Write task markdown with YAML frontmatter
    cat > "${task_file}" <<TASKEOF
---
id: "${task_id}"
title: "${title}"
priority: ${priority}
agent: ${agent}
status: triage
created: "${now}"
updated: "${now}"
---

# ${title}

${description}
TASKEOF

    log_info "Created task ${task_id}: ${title} [${priority}]"
    state_log "info" "state" "Task created: ${task_id} - ${title}"

    # Return the task ID
    echo "${task_id}"
}

# Move a task between status directories.
#   $1 - Task ID (filename without .md)
#   $2 - Source status directory (e.g. "triage")
#   $3 - Target status directory (e.g. "todo")
task_move() {
    local task_id="$1"
    local from_status="$2"
    local to_status="$3"

    # Validate statuses
    if ! _is_valid_status "${from_status}"; then
        log_error "Invalid source status: '${from_status}'"
        return 1
    fi
    if ! _is_valid_status "${to_status}"; then
        log_error "Invalid target status: '${to_status}'"
        return 1
    fi

    local src_file="${OTTO_STATE_DIR}/tasks/${from_status}/${task_id}.md"
    local dst_dir="${OTTO_STATE_DIR}/tasks/${to_status}"
    local dst_file="${dst_dir}/${task_id}.md"

    if [[ ! -f "${src_file}" ]]; then
        log_error "Task not found: ${src_file}"
        return 1
    fi

    mkdir -p "${dst_dir}"

    # Update the frontmatter status and updated timestamp before moving
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp_file
    tmp_file=$(mktemp "${TMPDIR:-/tmp}/otto-task.XXXXXX")

    # Replace status and updated fields in the YAML frontmatter
    awk -v new_status="${to_status}" -v new_updated="${now}" '
    BEGIN { in_front=0 }
    /^---$/ {
        if (in_front == 0) { in_front=1; print; next }
        else { in_front=0; print; next }
    }
    in_front && /^status:/ { print "status: " new_status; next }
    in_front && /^updated:/ { print "updated: \"" new_updated "\""; next }
    { print }
    ' "${src_file}" > "${tmp_file}"

    mv "${tmp_file}" "${dst_file}"
    rm -f "${src_file}"

    log_info "Moved task ${task_id}: ${from_status} -> ${to_status}"
    state_log "info" "state" "Task moved: ${task_id} ${from_status} -> ${to_status}"
}

# List tasks in a given status directory.
#   $1 - Status name (e.g. "triage", "todo", "in-progress")
# Outputs one line per task: "ID PRIORITY TITLE"
task_list() {
    local status="$1"

    if ! _is_valid_status "${status}"; then
        log_error "Invalid status: '${status}'"
        return 1
    fi

    local task_dir="${OTTO_STATE_DIR}/tasks/${status}"
    if [[ ! -d "${task_dir}" ]]; then
        return 0
    fi

    local task_file
    for task_file in "${task_dir}"/*.md; do
        [[ -f "${task_file}" ]] || continue

        local id title priority
        id=$(_frontmatter_get "${task_file}" "id")
        title=$(_frontmatter_get "${task_file}" "title")
        priority=$(_frontmatter_get "${task_file}" "priority")

        # Color-code priority
        local pcolor=""
        case "${priority}" in
            critical) pcolor="${RED}" ;;
            high)     pcolor="${YELLOW}" ;;
            medium)   pcolor="${BLUE}" ;;
            low)      pcolor="${DIM}" ;;
        esac

        printf '%s  %b%-8s%b  %s\n' "${id}" "${pcolor}" "${priority}" "${NC}" "${title}"
    done
}

# Read full details of a specific task.
#   $1 - Task ID
# Searches across all status directories.
task_get() {
    local task_id="$1"

    local status
    for status in "${OTTO_TASK_STATUSES[@]}"; do
        local task_file="${OTTO_STATE_DIR}/tasks/${status}/${task_id}.md"
        if [[ -f "${task_file}" ]]; then
            cat "${task_file}"
            return 0
        fi
    done

    log_error "Task not found: ${task_id}"
    return 1
}

# --- Internal helpers ---

# Create the initial state.json file with baseline structure.
_state_create_initial() {
    mkdir -p "$(dirname "${OTTO_STATE_FILE}")"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "${OTTO_STATE_FILE}" <<STATEEOF
{
  "version": "0.1.0",
  "created_at": "${now}",
  "updated_at": "${now}",
  "last_heartbeat": null,
  "night_watcher": {
    "active": false,
    "started_at": null
  },
  "task_counts": {
    "triage": 0,
    "todo": 0,
    "in-progress": 0,
    "done": 0,
    "failed": 0,
    "cancelled": 0
  }
}
STATEEOF

    log_debug "Created initial state file: ${OTTO_STATE_FILE}"
}

# Check whether a status name is valid.
_is_valid_status() {
    local status="$1"
    local valid
    for valid in "${OTTO_TASK_STATUSES[@]}"; do
        if [[ "${status}" == "${valid}" ]]; then
            return 0
        fi
    done
    return 1
}

# Extract a field from YAML frontmatter in a markdown file.
# Uses lightweight parsing -- no yq dependency for reading tasks.
#   $1 - File path
#   $2 - Field name
_frontmatter_get() {
    local file="$1"
    local field="$2"

    # Read between the first pair of --- lines
    local value
    value=$(awk -v field="${field}" '
    BEGIN { in_front=0; found="" }
    /^---$/ {
        if (in_front == 0) { in_front=1; next }
        else { exit }
    }
    in_front {
        # Match field: value or field: "value"
        split($0, parts, /: */)
        if (parts[1] == field) {
            val = $0
            sub(/^[^:]+: */, "", val)
            gsub(/^"/, "", val)
            gsub(/"$/, "", val)
            found = val
        }
    }
    END { print found }
    ' "${file}")

    echo "${value}"
}
