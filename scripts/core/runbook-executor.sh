#!/usr/bin/env bash
# OTTO - Interactive Runbook Executor (Wave 2)
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_RUNBOOK_EXECUTOR_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_RUNBOOK_EXECUTOR_LOADED=1

# Resolve OTTO_DIR from this script's location
OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/i18n.sh"

# Runbook directories
OTTO_RUNBOOK_DIRS=(
    "${OTTO_DIR}/knowledge/runbooks"
    "${OTTO_HOME}/knowledge/runbooks"
)

# --- Internal helpers ---

# Find a runbook file by name.
#   $1 - Runbook name (with or without .md extension)
# Outputs the full path or empty string.
_runbook_find() {
    local name="$1"
    local dir file

    # Strip .md if provided
    name="${name%.md}"

    for dir in "${OTTO_RUNBOOK_DIRS[@]}"; do
        file="${dir}/${name}.md"
        if [[ -f "${file}" ]]; then
            echo "${file}"
            return 0
        fi
    done
    echo ""
}

# Extract numbered steps from a runbook markdown file.
# Outputs lines of the form: STEP_NUM|TYPE|CONTENT
#   TYPE is "text" for instructions, "bash" for code blocks.
_runbook_parse_steps() {
    local file="$1"
    local in_code=0
    local code_lang=""
    local step_num=0
    local code_buffer=""
    local in_frontmatter=0
    local past_frontmatter=0

    while IFS= read -r line; do
        # Skip frontmatter
        if [[ "${line}" == "---" ]]; then
            if [[ "${in_frontmatter}" -eq 0 ]] && [[ "${past_frontmatter}" -eq 0 ]]; then
                in_frontmatter=1
                continue
            elif [[ "${in_frontmatter}" -eq 1 ]]; then
                in_frontmatter=0
                past_frontmatter=1
                continue
            fi
        fi
        if [[ "${in_frontmatter}" -eq 1 ]]; then
            continue
        fi

        # Handle code blocks
        if [[ "${line}" =~ ^\`\`\`bash ]] || [[ "${line}" =~ ^\`\`\`sh ]]; then
            in_code=1
            code_lang="bash"
            code_buffer=""
            continue
        fi

        if [[ "${line}" == '```' ]] && [[ "${in_code}" -eq 1 ]]; then
            in_code=0
            if [[ "${code_lang}" == "bash" ]] && [[ -n "${code_buffer}" ]]; then
                step_num=$(( step_num + 1 ))
                # Encode newlines for safe transport
                local encoded
                encoded=$(printf '%s' "${code_buffer}" | base64 -w0 2>/dev/null || printf '%s' "${code_buffer}" | base64 2>/dev/null)
                echo "${step_num}|bash|${encoded}"
            fi
            code_buffer=""
            continue
        fi

        if [[ "${in_code}" -eq 1 ]]; then
            if [[ -n "${code_buffer}" ]]; then
                code_buffer+=$'\n'
            fi
            code_buffer+="${line}"
            continue
        fi

        # Numbered steps (1. 2. 3. etc.)
        if [[ "${line}" =~ ^[0-9]+\.\  ]]; then
            step_num=$(( step_num + 1 ))
            local text="${line#*. }"
            echo "${step_num}|text|${text}"
        fi
    done < "${file}"
}

# --- Public API ---

# List available runbooks from all runbook directories.
runbook_list() {
    echo -e "${BOLD}$(i18n_get RUNBOOK_AVAILABLE "Available Runbooks")${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"

    local found=0
    local dir file basename title

    for dir in "${OTTO_RUNBOOK_DIRS[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            continue
        fi

        for file in "${dir}"/*.md; do
            [[ -f "${file}" ]] || continue
            found=1
            basename=$(basename "${file}" .md)
            title=$(head -5 "${file}" | grep '^# ' | head -1 | sed 's/^# //')
            if [[ -z "${title}" ]]; then
                title="${basename}"
            fi
            printf '  %-30s %s\n' "${basename}" "${title}"
        done
    done

    if [[ "${found}" -eq 0 ]]; then
        echo -e "  ${DIM}$(i18n_get RUNBOOK_NONE "No runbooks found")${NC}"
    fi
}

# Display a runbook's contents.
#   $1 - Runbook name
runbook_show() {
    local name="$1"

    if [[ -z "${name}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): runbook name"
        return 1
    fi

    local file
    file=$(_runbook_find "${name}")

    if [[ -z "${file}" ]] || [[ ! -f "${file}" ]]; then
        log_error "$(i18n_get ERR_FILE_NOT_FOUND "File not found"): ${name}"
        return 1
    fi

    cat "${file}"
}

# Interactively execute a runbook step by step.
#   $1 - Runbook name
runbook_execute() {
    local name="$1"

    if [[ -z "${name}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): runbook name"
        return 1
    fi

    local file
    file=$(_runbook_find "${name}")

    if [[ -z "${file}" ]] || [[ ! -f "${file}" ]]; then
        log_error "$(i18n_get ERR_FILE_NOT_FOUND "File not found"): ${name}"
        return 1
    fi

    local title
    title=$(head -5 "${file}" | grep '^# ' | head -1 | sed 's/^# //')
    echo -e "${BOLD}$(i18n_get RUNBOOK_TITLE "Runbook"): ${title:-${name}}${NC}"
    echo -e "${DIM}══════════════════════════════════════════${NC}"
    echo ""

    local steps
    steps=$(_runbook_parse_steps "${file}")

    if [[ -z "${steps}" ]]; then
        log_warn "No executable steps found in runbook"
        return 1
    fi

    local total_steps
    total_steps=$(echo "${steps}" | wc -l)
    local completed=0 skipped=0

    while IFS='|' read -r step_num step_type step_content; do
        echo -e "${CYAN}$(i18n_get RUNBOOK_STEP "Step") ${step_num}/${total_steps}${NC}"

        if [[ "${step_type}" == "text" ]]; then
            echo -e "  ${step_content}"
            echo ""
            echo -ne "  ${DIM}$(i18n_get PROMPT_CONTINUE "Press Enter to continue...")${NC} "
            read -r
            completed=$(( completed + 1 ))

        elif [[ "${step_type}" == "bash" ]]; then
            # Decode base64 content
            local decoded
            decoded=$(echo "${step_content}" | base64 -d 2>/dev/null || echo "${step_content}" | base64 --decode 2>/dev/null || echo "${step_content}")

            echo -e "  ${YELLOW}Command:${NC}"
            echo "${decoded}" | while IFS= read -r cmd_line; do
                echo -e "    ${DIM}\$${NC} ${cmd_line}"
            done
            echo ""

            echo -ne "  $(i18n_get PROMPT_STEP "Execute this step? [Y/n/s(kip)/q(uit)]") "
            local response
            read -r response

            case "${response}" in
                n|N)
                    echo -e "  ${YELLOW}Skipped${NC}"
                    skipped=$(( skipped + 1 ))
                    ;;
                s|S)
                    echo -e "  ${YELLOW}$(i18n_get RUNBOOK_SKIPPED "Skipped")${NC}"
                    skipped=$(( skipped + 1 ))
                    ;;
                q|Q)
                    echo ""
                    echo -e "${YELLOW}$(i18n_get RUNBOOK_ABORTED "Runbook aborted")${NC}"
                    echo -e "  Completed: ${completed}  Skipped: ${skipped}"
                    return 1
                    ;;
                *)
                    echo -e "  ${CYAN}$(i18n_get RUNBOOK_EXECUTING "Executing step") ${step_num}...${NC}"
                    echo ""

                    if eval "${decoded}"; then
                        echo ""
                        echo -e "  ${GREEN}OK${NC}"
                        completed=$(( completed + 1 ))
                    else
                        local exit_code=$?
                        echo ""
                        echo -e "  ${RED}Failed (exit code: ${exit_code})${NC}"
                        echo -ne "  Continue anyway? [Y/n] "
                        read -r cont_response
                        if [[ "${cont_response}" == "n" ]] || [[ "${cont_response}" == "N" ]]; then
                            echo -e "${YELLOW}$(i18n_get RUNBOOK_ABORTED "Runbook aborted")${NC}"
                            return 1
                        fi
                        completed=$(( completed + 1 ))
                    fi
                    ;;
            esac
        fi
        echo ""
    done <<< "${steps}"

    echo -e "${GREEN}$(i18n_get RUNBOOK_COMPLETED "Runbook completed")${NC}"
    echo -e "  Completed: ${completed}  Skipped: ${skipped}"
}

# Validate that a runbook is in valid format for execution.
#   $1 - Runbook name
runbook_validate() {
    local name="$1"

    if [[ -z "${name}" ]]; then
        log_error "$(i18n_get ERR_MISSING_ARG "Missing required argument"): runbook name"
        return 1
    fi

    local file
    file=$(_runbook_find "${name}")

    if [[ -z "${file}" ]] || [[ ! -f "${file}" ]]; then
        log_error "$(i18n_get ERR_FILE_NOT_FOUND "File not found"): ${name}"
        return 1
    fi

    local errors=0

    # Check for a title
    if ! head -10 "${file}" | grep -q '^# '; then
        echo -e "${YELLOW}Warning: No title (# heading) found${NC}"
        errors=$(( errors + 1 ))
    fi

    # Check for executable content
    local steps
    steps=$(_runbook_parse_steps "${file}")

    if [[ -z "${steps}" ]]; then
        echo -e "${RED}Error: No executable steps found (numbered steps or bash code blocks)${NC}"
        errors=$(( errors + 1 ))
    else
        local step_count
        step_count=$(echo "${steps}" | wc -l)
        local bash_count
        bash_count=$(echo "${steps}" | grep -c '|bash|' || true)
        local text_count
        text_count=$(echo "${steps}" | grep -c '|text|' || true)
        echo -e "${GREEN}Valid runbook:${NC} ${step_count} steps (${text_count} text, ${bash_count} bash)"
    fi

    # Check for unclosed code blocks
    local open_blocks close_blocks
    open_blocks=$(grep -c '```bash\|```sh' "${file}" || true)
    close_blocks=$(grep -c '^```$' "${file}" || true)
    if [[ "${open_blocks}" -ne "${close_blocks}" ]]; then
        echo -e "${RED}Error: Mismatched code blocks (${open_blocks} open, ${close_blocks} close)${NC}"
        errors=$(( errors + 1 ))
    fi

    if [[ "${errors}" -eq 0 ]]; then
        echo -e "${GREEN}Runbook is valid for execution${NC}"
        return 0
    else
        echo -e "${RED}${errors} issue(s) found${NC}"
        return 1
    fi
}

# --- CLI ---

_runbook_usage() {
    echo "Usage: otto runbook <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list                List available runbooks"
    echo "  show <name>         Display runbook contents"
    echo "  execute <name>      Interactively execute a runbook"
    echo "  validate <name>     Validate runbook format"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    i18n_init 2>/dev/null || true

    case "${1:-}" in
        list)
            runbook_list
            ;;
        show)
            runbook_show "${2:-}"
            ;;
        execute)
            runbook_execute "${2:-}"
            ;;
        validate)
            runbook_validate "${2:-}"
            ;;
        -h|--help|"")
            _runbook_usage
            ;;
        *)
            log_error "Unknown command: $1"
            _runbook_usage
            exit 1
            ;;
    esac
fi
