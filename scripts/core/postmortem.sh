#!/usr/bin/env bash
# OTTO - Postmortem Generator (Wave 2)
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_POSTMORTEM_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_POSTMORTEM_LOADED=1

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
source "${OTTO_DIR}/scripts/lib/i18n.sh"

OTTO_STATE_DIR="${OTTO_HOME}/state"
OTTO_POSTMORTEM_DIR="${OTTO_STATE_DIR}/postmortems"
OTTO_AUDIT_FILE="${OTTO_STATE_DIR}/audit.jsonl"
OTTO_TEMPLATE_FILE="${OTTO_DIR}/knowledge/patterns/postmortem-template.md"

# --- Internal helpers ---

# Find a task file by incident ID across all task status directories.
#   $1 - Task/incident ID
# Outputs the file path or empty string.
_postmortem_find_task() {
    local incident_id="$1"
    local status_dirs=("triage" "todo" "in-progress" "done" "failed" "cancelled")
    local status

    for status in "${status_dirs[@]}"; do
        local task_file="${OTTO_STATE_DIR}/tasks/${status}/${incident_id}.md"
        if [[ -f "${task_file}" ]]; then
            echo "${task_file}"
            return 0
        fi
    done
    echo ""
}

# Extract frontmatter value from a markdown file.
#   $1 - File path
#   $2 - Field name
_pm_frontmatter_get() {
    local file="$1"
    local field="$2"

    awk -v field="${field}" '
    BEGIN { in_front=0 }
    /^---$/ {
        if (in_front == 0) { in_front=1; next }
        else { exit }
    }
    in_front {
        split($0, parts, /: */)
        if (parts[1] == field) {
            val = $0
            sub(/^[^:]+: */, "", val)
            gsub(/^"/, "", val)
            gsub(/"$/, "", val)
            print val
        }
    }
    ' "${file}"
}

# Extract body (non-frontmatter) from a markdown file.
_pm_body_get() {
    local file="$1"

    awk '
    BEGIN { in_front=0; past_front=0 }
    /^---$/ {
        if (in_front == 0) { in_front=1; next }
        else { in_front=0; past_front=1; next }
    }
    past_front { print }
    ' "${file}"
}

# Collect audit log entries for a time range.
#   $1 - Start timestamp (ISO8601)
#   $2 - End timestamp (ISO8601)
_postmortem_collect_audit() {
    local start="$1"
    local end="$2"

    if [[ ! -f "${OTTO_AUDIT_FILE}" ]]; then
        return 0
    fi

    jq -c "select(.ts >= \"${start}\" and .ts <= \"${end}\")" "${OTTO_AUDIT_FILE}" 2>/dev/null || true
}

# Collect night watch logs for a time range.
#   $1 - Start timestamp (ISO8601)
#   $2 - End timestamp (ISO8601)
_postmortem_collect_nightwatch() {
    local start="$1"
    local end="$2"
    local nw_dir="${OTTO_STATE_DIR}/night-watch"

    if [[ ! -d "${nw_dir}" ]]; then
        return 0
    fi

    local file
    for file in "${nw_dir}"/*.json; do
        [[ -f "${file}" ]] || continue
        local file_ts
        file_ts=$(jq -r '.timestamp // .ts // empty' "${file}" 2>/dev/null || true)
        if [[ -n "${file_ts}" ]] && [[ "${file_ts}" >= "${start}" ]] && [[ "${file_ts}" <= "${end}" ]]; then
            jq -c '.' "${file}" 2>/dev/null || true
        fi
    done
}

# Collect alert data for a time range.
#   $1 - Start timestamp (ISO8601)
#   $2 - End timestamp (ISO8601)
_postmortem_collect_alerts() {
    local start="$1"
    local end="$2"
    local alerts_file="${OTTO_STATE_DIR}/alerts.json"

    if [[ ! -f "${alerts_file}" ]]; then
        return 0
    fi

    jq -c ".[] | select(.timestamp >= \"${start}\" and .timestamp <= \"${end}\")" "${alerts_file}" 2>/dev/null || true
}

# Build the timeline section from collected data.
#   $1 - Audit entries (newline-separated JSON lines)
#   $2 - Alert entries (newline-separated JSON lines)
_postmortem_build_timeline() {
    local audit_entries="$1"
    local alert_entries="$2"

    echo "| Time | Event |"
    echo "|------|-------|"

    # Merge and sort events by timestamp
    {
        if [[ -n "${audit_entries}" ]]; then
            echo "${audit_entries}" | jq -r '"| \(.ts) | [AUDIT] \(.actor) \(.action) \(.target) - \(.result) |"' 2>/dev/null || true
        fi
        if [[ -n "${alert_entries}" ]]; then
            echo "${alert_entries}" | jq -r '"| \(.timestamp // .ts) | [ALERT] \(.severity // "?") - \(.message // "unknown") |"' 2>/dev/null || true
        fi
    } | sort
}

# --- Public API ---

# Auto-generate a postmortem document from an incident task.
#   $1 - Incident/task ID
postmortem_generate() {
    local incident_id="$1"

    if [[ -z "${incident_id}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): incident_id"
        return 1
    fi

    mkdir -p "${OTTO_POSTMORTEM_DIR}"

    # Find the incident task
    local task_file
    task_file=$(_postmortem_find_task "${incident_id}")

    local title="Incident ${incident_id}"
    local description=""
    local priority="unknown"
    local created_at=""
    local updated_at=""

    if [[ -n "${task_file}" ]] && [[ -f "${task_file}" ]]; then
        title=$(_pm_frontmatter_get "${task_file}" "title")
        priority=$(_pm_frontmatter_get "${task_file}" "priority")
        created_at=$(_pm_frontmatter_get "${task_file}" "created")
        updated_at=$(_pm_frontmatter_get "${task_file}" "updated")
        description=$(_pm_body_get "${task_file}")
    else
        log_warn "Task file not found for incident: ${incident_id}"
        created_at=$(date -u -d "1 day ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
        updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    # Set time range for data collection
    local start_time="${created_at:-$(date -u +"%Y-%m-%dT00:00:00Z")}"
    local end_time="${updated_at:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

    # Collect data
    local audit_entries alert_entries nw_entries
    audit_entries=$(_postmortem_collect_audit "${start_time}" "${end_time}")
    alert_entries=$(_postmortem_collect_alerts "${start_time}" "${end_time}")
    nw_entries=$(_postmortem_collect_nightwatch "${start_time}" "${end_time}")

    # Build timeline
    local timeline
    timeline=$(_postmortem_build_timeline "${audit_entries}" "${alert_entries}")

    # Map priority to severity
    local severity="P3"
    case "${priority}" in
        critical) severity="P1" ;;
        high)     severity="P2" ;;
        medium)   severity="P3" ;;
        low)      severity="P4" ;;
    esac

    local now
    now=$(date -u +"%Y-%m-%d")
    local output_file="${OTTO_POSTMORTEM_DIR}/${now}-${incident_id}.md"

    # Generate the postmortem document
    cat > "${output_file}" <<PMEOF
# Postmortem: ${title}

**Date:** ${now}
**Incident ID:** ${incident_id}
**Severity:** ${severity}
**Duration:** ${start_time} - ${end_time}
**Author:** OTTO (auto-generated)
**Status:** Draft

---

## $(i18n_get POSTMORTEM_SUMMARY "Summary")

${description:-_No description available. Please fill in a brief description of what happened._}

## $(i18n_get POSTMORTEM_IMPACT "Impact")

- **Users affected:** _To be determined_
- **Services affected:** _To be determined_
- **SLA breach:** _To be determined_
- **Data loss:** No

## $(i18n_get POSTMORTEM_TIMELINE "Timeline") (UTC)

${timeline}

## $(i18n_get POSTMORTEM_ROOT_CAUSE "Root Cause")

_To be determined. Analyze the timeline and audit entries above to identify the root cause._

## $(i18n_get POSTMORTEM_CONTRIBUTING "Contributing Factors")

- [ ] _Factor 1_
- [ ] _Factor 2_

## $(i18n_get POSTMORTEM_ACTIONS "Action Items")

| Priority | Action | Owner | Due Date | Status |
|----------|--------|-------|----------|--------|
| ${severity} | Investigate root cause | TBD | $(date -u -d "+7 days" +%Y-%m-%d 2>/dev/null || date -u -v+7d +%Y-%m-%d 2>/dev/null || echo "TBD") | Open |
| P3 | Update monitoring | TBD | $(date -u -d "+14 days" +%Y-%m-%d 2>/dev/null || date -u -v+14d +%Y-%m-%d 2>/dev/null || echo "TBD") | Open |
| P3 | Update runbook | TBD | $(date -u -d "+14 days" +%Y-%m-%d 2>/dev/null || date -u -v+14d +%Y-%m-%d 2>/dev/null || echo "TBD") | Open |

## $(i18n_get POSTMORTEM_LESSONS "Lessons Learned")

### What went well

- _To be filled in during review_

### What went poorly

- _To be filled in during review_

### Where we got lucky

- _To be filled in during review_

---

### Appendix: Night Watcher Data

$(if [[ -n "${nw_entries}" ]]; then
    echo '```json'
    echo "${nw_entries}" | jq '.' 2>/dev/null || echo "${nw_entries}"
    echo '```'
else
    echo "_No Night Watcher data for this time range._"
fi)

### Appendix: Audit Log Entries

$(if [[ -n "${audit_entries}" ]]; then
    echo '```json'
    echo "${audit_entries}" | jq '.' 2>/dev/null || echo "${audit_entries}"
    echo '```'
else
    echo "_No audit log entries for this time range._"
fi)

---
_This postmortem was auto-generated by OTTO and should be reviewed by the incident team._
PMEOF

    log_info "Postmortem generated: ${output_file}"
    echo "${output_file}"
}

# Generate a postmortem for a time range (not tied to a specific incident).
#   $1 - Start timestamp (ISO8601)
#   $2 - End timestamp (ISO8601)
postmortem_from_timerange() {
    local start="$1"
    local end="$2"

    if [[ -z "${start}" ]] || [[ -z "${end}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): start and end timestamps"
        return 1
    fi

    mkdir -p "${OTTO_POSTMORTEM_DIR}"

    # Collect data
    local audit_entries alert_entries nw_entries
    audit_entries=$(_postmortem_collect_audit "${start}" "${end}")
    alert_entries=$(_postmortem_collect_alerts "${start}" "${end}")
    nw_entries=$(_postmortem_collect_nightwatch "${start}" "${end}")

    local timeline
    timeline=$(_postmortem_build_timeline "${audit_entries}" "${alert_entries}")

    local now
    now=$(date -u +"%Y-%m-%d")
    local range_id
    range_id=$(echo "${start}-${end}" | tr -c 'a-zA-Z0-9-' '_' | head -c 40)
    local output_file="${OTTO_POSTMORTEM_DIR}/${now}-range-${range_id}.md"

    cat > "${output_file}" <<PMEOF
# Postmortem: Time Range Analysis

**Date:** ${now}
**Period:** ${start} to ${end}
**Author:** OTTO (auto-generated)
**Status:** Draft

---

## $(i18n_get POSTMORTEM_SUMMARY "Summary")

_Auto-generated postmortem for the period ${start} to ${end}. Please fill in details._

## $(i18n_get POSTMORTEM_IMPACT "Impact")

- **Users affected:** _To be determined_
- **Services affected:** _To be determined_

## $(i18n_get POSTMORTEM_TIMELINE "Timeline") (UTC)

${timeline}

## $(i18n_get POSTMORTEM_ROOT_CAUSE "Root Cause")

_To be determined._

## $(i18n_get POSTMORTEM_CONTRIBUTING "Contributing Factors")

- [ ] _Factor 1_

## $(i18n_get POSTMORTEM_ACTIONS "Action Items")

| Priority | Action | Owner | Due Date | Status |
|----------|--------|-------|----------|--------|
| P3 | Review findings | TBD | TBD | Open |

## $(i18n_get POSTMORTEM_LESSONS "Lessons Learned")

### What went well

- _To be filled in during review_

### What went poorly

- _To be filled in during review_

---

### Appendix: Night Watcher Data

$(if [[ -n "${nw_entries}" ]]; then
    echo '```json'
    echo "${nw_entries}" | jq '.' 2>/dev/null || echo "${nw_entries}"
    echo '```'
else
    echo "_No Night Watcher data for this time range._"
fi)

### Appendix: Audit Log Entries

$(if [[ -n "${audit_entries}" ]]; then
    echo '```json'
    echo "${audit_entries}" | jq '.' 2>/dev/null || echo "${audit_entries}"
    echo '```'
else
    echo "_No audit log entries for this time range._"
fi)

---
_This postmortem was auto-generated by OTTO and should be reviewed by the incident team._
PMEOF

    log_info "Postmortem generated: ${output_file}"
    echo "${output_file}"
}

# List all generated postmortems.
postmortem_list() {
    if [[ ! -d "${OTTO_POSTMORTEM_DIR}" ]]; then
        echo -e "${DIM}$(i18n_get POSTMORTEM_NONE "No postmortems found")${NC}"
        return 0
    fi

    local files
    files=$(ls -1 "${OTTO_POSTMORTEM_DIR}"/*.md 2>/dev/null || true)

    if [[ -z "${files}" ]]; then
        echo -e "${DIM}$(i18n_get POSTMORTEM_NONE "No postmortems found")${NC}"
        return 0
    fi

    echo -e "${BOLD}$(i18n_get POSTMORTEM_TITLE "Postmortem Reports")${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"

    local file
    for file in ${files}; do
        local basename
        basename=$(basename "${file}" .md)
        local title
        title=$(head -1 "${file}" | sed 's/^# //')
        printf '  %-40s %s\n' "${basename}" "${title}"
    done
}

# --- CLI ---

_postmortem_usage() {
    echo "Usage: otto postmortem <command> [args]"
    echo ""
    echo "Commands:"
    echo "  generate <incident_id>    Generate postmortem from incident"
    echo "  range <start> <end>       Generate postmortem for time range"
    echo "  list                      List generated postmortems"
    echo ""
    echo "Examples:"
    echo "  otto postmortem generate 20260417120000-a1b2c3d4"
    echo "  otto postmortem range 2026-04-16T00:00:00Z 2026-04-17T00:00:00Z"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    i18n_init 2>/dev/null || true

    case "${1:-}" in
        generate)
            if [[ -z "${2:-}" ]]; then
                log_error "Missing incident_id"
                _postmortem_usage
                exit 1
            fi
            postmortem_generate "$2"
            ;;
        range)
            if [[ -z "${2:-}" ]] || [[ -z "${3:-}" ]]; then
                log_error "Missing start or end timestamp"
                _postmortem_usage
                exit 1
            fi
            postmortem_from_timerange "$2" "$3"
            ;;
        list)
            postmortem_list
            ;;
        -h|--help|"")
            _postmortem_usage
            ;;
        *)
            log_error "Unknown command: $1"
            _postmortem_usage
            exit 1
            ;;
    esac
fi
