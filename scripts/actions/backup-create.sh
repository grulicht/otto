#!/usr/bin/env bash
# OTTO - Create backup helper
# Supports: restic, borg, velero, pg_dump, mysqldump
# Usage: backup-create.sh --target <target> --type <restic|borg|velero|pg_dump|mysqldump> [--dry-run]
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/permissions.sh"

TARGET=""
BACKUP_TYPE=""
DRY_RUN=false
ENVIRONMENT=""
BACKUP_DEST=""
BACKUP_TAG=""
DB_HOST="localhost"
DB_PORT=""
DB_NAME=""
DB_USER=""
OUTPUT_DIR=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a backup using the specified tool.

Options:
    --target <path|name>    Backup target: directory, database, or namespace (required)
    --type <type>           Backup type: restic, borg, velero, pg_dump, mysqldump (required)
    --environment <env>     Environment name (optional, for permissions)
    --dest <path|repo>      Backup destination/repository (for restic/borg)
    --tag <tag>             Backup tag or label (optional)
    --db-host <host>        Database host (default: localhost)
    --db-port <port>        Database port (default: tool-specific)
    --db-name <name>        Database name (for pg_dump/mysqldump; defaults to target)
    --db-user <user>        Database user
    --output-dir <dir>      Output directory for dump files (default: /tmp)
    --dry-run               Preview backup without executing
    -h, --help              Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)      TARGET="$2"; shift 2 ;;
            --type)        BACKUP_TYPE="$2"; shift 2 ;;
            --environment) ENVIRONMENT="$2"; shift 2 ;;
            --dest)        BACKUP_DEST="$2"; shift 2 ;;
            --tag)         BACKUP_TAG="$2"; shift 2 ;;
            --db-host)     DB_HOST="$2"; shift 2 ;;
            --db-port)     DB_PORT="$2"; shift 2 ;;
            --db-name)     DB_NAME="$2"; shift 2 ;;
            --db-user)     DB_USER="$2"; shift 2 ;;
            --output-dir)  OUTPUT_DIR="$2"; shift 2 ;;
            --dry-run)     DRY_RUN=true; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${TARGET}" ]] || [[ -z "${BACKUP_TYPE}" ]]; then
        log_error "Missing required arguments: --target and --type are required"
        usage
        exit 1
    fi

    case "${BACKUP_TYPE}" in
        restic|borg|velero|pg_dump|mysqldump) ;;
        *) log_error "Unsupported backup type: ${BACKUP_TYPE}. Use: restic, borg, velero, pg_dump, mysqldump"; exit 1 ;;
    esac

    DB_NAME="${DB_NAME:-${TARGET}}"
    OUTPUT_DIR="${OUTPUT_DIR:-/tmp}"
}

output_result() {
    local action="$1" target="$2" status="$3" details="$4"
    jq -n \
        --arg action "${action}" \
        --arg target "${target}" \
        --arg status "${status}" \
        --arg details "${details}" \
        --arg backup_type "${BACKUP_TYPE}" \
        --arg environment "${ENVIRONMENT:-}" \
        --arg dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            action: $action,
            target: $target,
            status: $status,
            details: $details,
            backup_type: $backup_type,
            environment: $environment,
            dry_run: ($dry_run == "true"),
            timestamp: $timestamp
        }'
}

backup_restic() {
    otto_require_command restic "https://restic.net"

    local repo="${BACKUP_DEST:-${RESTIC_REPOSITORY:-}}"
    if [[ -z "${repo}" ]]; then
        log_error "No restic repository specified. Use --dest or set RESTIC_REPOSITORY"
        exit 1
    fi

    local cmd=(restic -r "${repo}" backup "${TARGET}")
    [[ -n "${BACKUP_TAG}" ]] && cmd+=(--tag "${BACKUP_TAG}")
    [[ "${DRY_RUN}" == "true" ]] && cmd+=(--dry-run)

    log_info "Creating restic backup of ${TARGET} to ${repo}"
    local output
    output=$("${cmd[@]}" 2>&1) || {
        output_result "backup" "${TARGET}" "failed" "restic backup failed: ${output}"
        exit 1
    }

    local snapshot_id
    snapshot_id=$(echo "${output}" | grep -oP 'snapshot \K[a-f0-9]+' | head -1) || snapshot_id="unknown"
    output_result "backup" "${TARGET}" "success" "restic backup completed, snapshot: ${snapshot_id}"
}

backup_borg() {
    otto_require_command borg "https://borgbackup.org"

    local repo="${BACKUP_DEST:-${BORG_REPO:-}}"
    if [[ -z "${repo}" ]]; then
        log_error "No borg repository specified. Use --dest or set BORG_REPO"
        exit 1
    fi

    local archive_name="${repo}::${BACKUP_TAG:-$(date +%Y-%m-%dT%H%M%S)}"
    local cmd=(borg create --stats --compression lz4 "${archive_name}" "${TARGET}")
    [[ "${DRY_RUN}" == "true" ]] && cmd+=(--dry-run)

    log_info "Creating borg backup of ${TARGET} to ${archive_name}"
    local output
    output=$("${cmd[@]}" 2>&1) || {
        output_result "backup" "${TARGET}" "failed" "borg backup failed: ${output}"
        exit 1
    }
    output_result "backup" "${TARGET}" "success" "borg backup completed: ${archive_name}"
}

backup_velero() {
    otto_require_command velero

    local backup_name="${BACKUP_TAG:-${TARGET}-$(date +%Y%m%d-%H%M%S)}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create Velero backup '${backup_name}' for namespace '${TARGET}'"
        output_result "backup" "${TARGET}" "dry-run" "Would create Velero backup ${backup_name}"
        return
    fi

    log_info "Creating Velero backup '${backup_name}' for namespace '${TARGET}'"
    local output
    output=$(velero backup create "${backup_name}" --include-namespaces "${TARGET}" --wait 2>&1) || {
        output_result "backup" "${TARGET}" "failed" "velero backup failed: ${output}"
        exit 1
    }

    local status
    status=$(velero backup describe "${backup_name}" -o json 2>/dev/null | \
        jq -r '.status.phase // "unknown"' 2>/dev/null) || status="unknown"
    output_result "backup" "${TARGET}" "success" "Velero backup completed: ${backup_name} (${status})"
}

backup_pg_dump() {
    otto_require_command pg_dump

    local port="${DB_PORT:-5432}"
    local dump_file="${OUTPUT_DIR}/${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql.gz"
    local cmd=(pg_dump -h "${DB_HOST}" -p "${port}" -d "${DB_NAME}")
    [[ -n "${DB_USER}" ]] && cmd+=(-U "${DB_USER}")

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would dump PostgreSQL database ${DB_NAME} to ${dump_file}"
        output_result "backup" "${TARGET}" "dry-run" "Would dump ${DB_NAME} to ${dump_file}"
        return
    fi

    log_info "Dumping PostgreSQL database '${DB_NAME}' from ${DB_HOST}:${port}"
    if "${cmd[@]}" 2>/dev/null | gzip > "${dump_file}"; then
        local size
        size=$(du -h "${dump_file}" 2>/dev/null | cut -f1) || size="unknown"
        output_result "backup" "${TARGET}" "success" "pg_dump completed: ${dump_file} (${size})"
    else
        rm -f "${dump_file}"
        output_result "backup" "${TARGET}" "failed" "pg_dump failed for ${DB_NAME}"
        exit 1
    fi
}

backup_mysqldump() {
    otto_require_command mysqldump

    local port="${DB_PORT:-3306}"
    local dump_file="${OUTPUT_DIR}/${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql.gz"
    local cmd=(mysqldump -h "${DB_HOST}" -P "${port}" --single-transaction --routines --triggers "${DB_NAME}")
    [[ -n "${DB_USER}" ]] && cmd+=(-u "${DB_USER}")

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would dump MySQL database ${DB_NAME} to ${dump_file}"
        output_result "backup" "${TARGET}" "dry-run" "Would dump ${DB_NAME} to ${dump_file}"
        return
    fi

    log_info "Dumping MySQL database '${DB_NAME}' from ${DB_HOST}:${port}"
    if "${cmd[@]}" 2>/dev/null | gzip > "${dump_file}"; then
        local size
        size=$(du -h "${dump_file}" 2>/dev/null | cut -f1) || size="unknown"
        output_result "backup" "${TARGET}" "success" "mysqldump completed: ${dump_file} (${size})"
    else
        rm -f "${dump_file}"
        output_result "backup" "${TARGET}" "failed" "mysqldump failed for ${DB_NAME}"
        exit 1
    fi
}

main() {
    parse_args "$@"

    local description="Create ${BACKUP_TYPE} backup of ${TARGET}"

    if ! permission_enforce "backup" "create" "${ENVIRONMENT}" "${description}"; then
        output_result "backup" "${TARGET}" "denied" "Permission denied for backup creation"
        exit 1
    fi

    case "${BACKUP_TYPE}" in
        restic)    backup_restic ;;
        borg)      backup_borg ;;
        velero)    backup_velero ;;
        pg_dump)   backup_pg_dump ;;
        mysqldump) backup_mysqldump ;;
    esac
}

main "$@"
