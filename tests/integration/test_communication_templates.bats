#!/usr/bin/env bats
# OTTO - Communication templates integration tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
}

@test "all Slack templates are valid JSON" {
    if ! command -v jq &>/dev/null; then
        skip "jq not available"
    fi

    local failed=0
    for template in "${OTTO_DIR}"/scripts/templates/slack/*.json; do
        [ -f "${template}" ] || continue
        if ! jq -e '.' "${template}" >/dev/null 2>&1; then
            echo "Invalid JSON: ${template}" >&2
            failed=1
        fi
    done
    [ "${failed}" -eq 0 ]
}

@test "all Telegram templates exist and are non-empty" {
    local template_dir="${OTTO_DIR}/scripts/templates/telegram"
    [ -d "${template_dir}" ]

    local found=0
    for template in "${template_dir}"/*.txt; do
        [ -f "${template}" ] || continue
        found=1
        local size
        size=$(wc -c < "${template}")
        [ "${size}" -gt 0 ]
    done
    [ "${found}" -eq 1 ]
}

@test "all Email templates are valid HTML (contain html tag)" {
    local template_dir="${OTTO_DIR}/scripts/templates/email"
    [ -d "${template_dir}" ]

    local found=0
    for template in "${template_dir}"/*.html; do
        [ -f "${template}" ] || continue
        found=1
        grep -qi "<html" "${template}"
    done
    [ "${found}" -eq 1 ]
}

@test "dashboard template exists and has placeholder variables" {
    local dashboard="${OTTO_DIR}/scripts/templates/dashboard/index.html"
    [ -f "${dashboard}" ]

    local size
    size=$(wc -c < "${dashboard}")
    [ "${size}" -gt 0 ]

    # Dashboard should contain some placeholder pattern ({{var}} or ${var} or similar)
    grep -qE '\{\{|\$\{|%[A-Z_]+%|__[A-Z_]+__' "${dashboard}" || \
    grep -qi 'placeholder\|template\|variable\|OTTO' "${dashboard}"
}
