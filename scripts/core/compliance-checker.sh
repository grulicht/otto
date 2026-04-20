#!/usr/bin/env bash
# OTTO - Compliance & Security Audit
# Checks infrastructure against security and compliance best practices.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_COMPLIANCE_CHECKER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_COMPLIANCE_CHECKER_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# Accumulator for findings
_COMPLIANCE_FINDINGS="[]"

# --- Internal helpers ---

_compliance_add_finding() {
    local category="$1"
    local severity="$2"
    local check="$3"
    local status="$4"
    local details="$5"
    local remediation="${6:-}"

    _COMPLIANCE_FINDINGS=$(echo "${_COMPLIANCE_FINDINGS}" | jq \
        --arg cat "${category}" \
        --arg sev "${severity}" \
        --arg chk "${check}" \
        --arg st "${status}" \
        --arg det "${details}" \
        --arg rem "${remediation}" \
        '. + [{category: $cat, severity: $sev, check: $chk, status: $st, details: $det, remediation: $rem}]')
}

_compliance_reset() {
    _COMPLIANCE_FINDINGS="[]"
}

# --- Public API ---

# Check K8s pods for security issues.
# Usage: compliance_check_k8s_pods
compliance_check_k8s_pods() {
    if ! command -v kubectl &>/dev/null; then
        log_warn "kubectl not found - skipping K8s pod compliance checks"
        _compliance_add_finding "kubernetes" "info" "k8s_available" "warn" "kubectl not found" "Install kubectl"
        return 0
    fi

    log_info "Checking K8s pod compliance"

    local pods_json
    pods_json=$(kubectl get pods --all-namespaces -o json 2>/dev/null || echo '{"items":[]}')

    # Check for root containers
    local root_pods
    root_pods=$(echo "${pods_json}" | jq -r '[.items[] |
        select(.spec.containers[]? | .securityContext.runAsUser == 0 or
            (.securityContext.runAsNonRoot == false) or
            (.securityContext.runAsNonRoot == null and (.securityContext.runAsUser // null) == null)) |
        "\(.metadata.namespace)/\(.metadata.name)"] | unique | .[]' 2>/dev/null || true)

    if [[ -n "${root_pods}" ]]; then
        local count
        count=$(echo "${root_pods}" | wc -l)
        _compliance_add_finding "kubernetes" "warning" "no_root_containers" "fail" \
            "${count} pod(s) may run as root" \
            "Set securityContext.runAsNonRoot: true in pod spec"
    else
        _compliance_add_finding "kubernetes" "info" "no_root_containers" "pass" "No pods running as root" ""
    fi

    # Check for missing resource limits
    local no_limits
    no_limits=$(echo "${pods_json}" | jq -r '[.items[] |
        select(.spec.containers[]? | .resources.limits == null) |
        "\(.metadata.namespace)/\(.metadata.name)"] | unique | .[]' 2>/dev/null || true)

    if [[ -n "${no_limits}" ]]; then
        local count
        count=$(echo "${no_limits}" | wc -l)
        _compliance_add_finding "kubernetes" "warning" "resource_limits" "fail" \
            "${count} pod(s) missing resource limits" \
            "Set resources.limits.cpu and resources.limits.memory"
    else
        _compliance_add_finding "kubernetes" "info" "resource_limits" "pass" "All pods have resource limits" ""
    fi

    # Check for missing probes
    local no_probes
    no_probes=$(echo "${pods_json}" | jq -r '[.items[] |
        select(.metadata.namespace != "kube-system") |
        select(.spec.containers[]? | (.livenessProbe == null) or (.readinessProbe == null)) |
        "\(.metadata.namespace)/\(.metadata.name)"] | unique | .[]' 2>/dev/null || true)

    if [[ -n "${no_probes}" ]]; then
        local count
        count=$(echo "${no_probes}" | wc -l)
        _compliance_add_finding "kubernetes" "info" "health_probes" "fail" \
            "${count} pod(s) missing liveness/readiness probes" \
            "Add livenessProbe and readinessProbe to container spec"
    else
        _compliance_add_finding "kubernetes" "info" "health_probes" "pass" "All pods have health probes" ""
    fi

    # Check for hostNetwork
    local host_net
    host_net=$(echo "${pods_json}" | jq -r '[.items[] |
        select(.spec.hostNetwork == true) |
        "\(.metadata.namespace)/\(.metadata.name)"] | unique | .[]' 2>/dev/null || true)

    if [[ -n "${host_net}" ]]; then
        local count
        count=$(echo "${host_net}" | wc -l)
        _compliance_add_finding "kubernetes" "critical" "no_host_network" "fail" \
            "${count} pod(s) using hostNetwork" \
            "Remove hostNetwork: true unless absolutely required"
    else
        _compliance_add_finding "kubernetes" "info" "no_host_network" "pass" "No pods using hostNetwork" ""
    fi

    # Check for privileged containers
    local privileged
    privileged=$(echo "${pods_json}" | jq -r '[.items[] |
        select(.spec.containers[]? | .securityContext.privileged == true) |
        "\(.metadata.namespace)/\(.metadata.name)"] | unique | .[]' 2>/dev/null || true)

    if [[ -n "${privileged}" ]]; then
        local count
        count=$(echo "${privileged}" | wc -l)
        _compliance_add_finding "kubernetes" "critical" "no_privileged" "fail" \
            "${count} pod(s) running privileged containers" \
            "Remove securityContext.privileged: true"
    else
        _compliance_add_finding "kubernetes" "info" "no_privileged" "pass" "No privileged containers" ""
    fi
}

# Check Docker images for issues.
# Usage: compliance_check_docker_images
compliance_check_docker_images() {
    if ! command -v docker &>/dev/null; then
        log_warn "docker not found - skipping Docker image checks"
        _compliance_add_finding "docker" "info" "docker_available" "warn" "Docker not found" "Install Docker"
        return 0
    fi

    log_info "Checking Docker image compliance"

    # Check for latest tag
    local latest_images
    latest_images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep ':latest$' || true)

    if [[ -n "${latest_images}" ]]; then
        local count
        count=$(echo "${latest_images}" | wc -l)
        _compliance_add_finding "docker" "warning" "no_latest_tag" "fail" \
            "${count} image(s) using :latest tag" \
            "Pin images to specific versions/digests"
    else
        _compliance_add_finding "docker" "info" "no_latest_tag" "pass" "No images using :latest tag" ""
    fi

    # Check for vulnerabilities with trivy if available
    if command -v trivy &>/dev/null; then
        local images
        images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | head -10)
        local vuln_count=0

        while IFS= read -r image; do
            [[ -z "${image}" ]] && continue
            [[ "${image}" == *"<none>"* ]] && continue

            local critical_vulns
            critical_vulns=$(trivy image --severity CRITICAL --format json --quiet "${image}" 2>/dev/null | \
                jq '[.Results[]?.Vulnerabilities // [] | length] | add // 0' 2>/dev/null || echo "0")

            if [[ "${critical_vulns}" -gt 0 ]]; then
                ((vuln_count++))
                _compliance_add_finding "docker" "critical" "image_vulnerabilities" "fail" \
                    "Image ${image} has ${critical_vulns} critical vulnerabilities" \
                    "Update base image and dependencies"
            fi
        done <<< "${images}"

        if [[ "${vuln_count}" -eq 0 ]]; then
            _compliance_add_finding "docker" "info" "image_vulnerabilities" "pass" \
                "No critical vulnerabilities found in scanned images" ""
        fi
    else
        _compliance_add_finding "docker" "info" "vulnerability_scan" "warn" \
            "Trivy not found - vulnerability scanning skipped" \
            "Install trivy: https://github.com/aquasecurity/trivy"
    fi
}

# Check Terraform state for security issues.
# Usage: compliance_check_terraform
compliance_check_terraform() {
    if ! command -v terraform &>/dev/null; then
        log_warn "terraform not found - skipping TF compliance checks"
        _compliance_add_finding "terraform" "info" "terraform_available" "warn" "Terraform not found" "Install Terraform"
        return 0
    fi

    log_info "Checking Terraform compliance"

    local tf_state
    tf_state=$(terraform show -json 2>/dev/null || echo '{}')

    if [[ "${tf_state}" == '{}' ]]; then
        _compliance_add_finding "terraform" "info" "tf_state_readable" "warn" \
            "No Terraform state found in current directory" \
            "Run from a directory with Terraform state"
        return 0
    fi

    # Check for unencrypted S3 buckets
    local unencrypted
    unencrypted=$(echo "${tf_state}" | jq -r '
        [.. | objects | select(.type? == "aws_s3_bucket") |
            select(.values?.server_side_encryption_configuration == null) |
            .values.bucket // .address] | unique | .[]' 2>/dev/null || true)

    if [[ -n "${unencrypted}" ]]; then
        local count
        count=$(echo "${unencrypted}" | wc -l)
        _compliance_add_finding "terraform" "critical" "encrypted_storage" "fail" \
            "${count} S3 bucket(s) without encryption" \
            "Enable server_side_encryption_configuration on all S3 buckets"
    else
        _compliance_add_finding "terraform" "info" "encrypted_storage" "pass" "All S3 buckets encrypted" ""
    fi

    # Check for public access
    local public_access
    public_access=$(echo "${tf_state}" | jq -r '
        [.. | objects | select(.type? == "aws_s3_bucket_public_access_block") |
            select(.values?.block_public_acls == false or .values?.block_public_policy == false) |
            .address] | .[]' 2>/dev/null || true)

    if [[ -n "${public_access}" ]]; then
        _compliance_add_finding "terraform" "critical" "no_public_access" "fail" \
            "S3 buckets with public access enabled" \
            "Enable block_public_acls and block_public_policy"
    else
        _compliance_add_finding "terraform" "info" "no_public_access" "pass" "No public S3 buckets" ""
    fi

    # Check for missing tags
    local untagged
    untagged=$(echo "${tf_state}" | jq -r '
        [.. | objects | select(.type? | test("aws_instance|aws_s3_bucket|aws_rds";"i") // false) |
            select(.values?.tags == null or (.values?.tags | keys | length) == 0) |
            .address] | .[]' 2>/dev/null || true)

    if [[ -n "${untagged}" ]]; then
        local count
        count=$(echo "${untagged}" | wc -l)
        _compliance_add_finding "terraform" "warning" "resource_tags" "fail" \
            "${count} resource(s) missing tags" \
            "Add tags (at minimum: Environment, Owner, Project) to all resources"
    else
        _compliance_add_finding "terraform" "info" "resource_tags" "pass" "All resources have tags" ""
    fi
}

# Check for weak/default passwords in config files.
# Usage: compliance_check_passwords
compliance_check_passwords() {
    log_info "Checking for weak/default passwords in configuration files"

    local config_dirs=("/etc" "/opt" "${HOME}/.config")
    local patterns=("password.*=.*password" "password.*=.*123" "password.*=.*admin"
                    "secret.*=.*secret" "api_key.*=.*changeme" "token.*=.*default")
    local found=0

    for dir in "${config_dirs[@]}"; do
        [[ ! -d "${dir}" ]] && continue

        for pattern in "${patterns[@]}"; do
            local matches
            matches=$(grep -r -l -i "${pattern}" "${dir}" --include="*.conf" --include="*.yaml" \
                --include="*.yml" --include="*.ini" --include="*.env" --include="*.cfg" \
                2>/dev/null | head -20 || true)

            if [[ -n "${matches}" ]]; then
                local count
                count=$(echo "${matches}" | wc -l)
                found=$((found + count))
            fi
        done
    done

    if [[ "${found}" -gt 0 ]]; then
        _compliance_add_finding "security" "critical" "weak_passwords" "fail" \
            "${found} config file(s) may contain weak/default passwords" \
            "Replace default passwords with strong, unique values. Use a secrets manager."
    else
        _compliance_add_finding "security" "info" "weak_passwords" "pass" \
            "No obvious weak/default passwords found in config files" ""
    fi
}

# Check SSL certificates for upcoming expiry.
# Usage: compliance_check_ssl_expiry
compliance_check_ssl_expiry() {
    log_info "Checking SSL certificate expiry"

    local cert_dirs=("/etc/ssl/certs" "/etc/letsencrypt/live" "/etc/pki/tls/certs")
    local expiring_soon=0
    local expired=0
    local warning_days=30

    for dir in "${cert_dirs[@]}"; do
        [[ ! -d "${dir}" ]] && continue

        while IFS= read -r cert_file; do
            [[ -z "${cert_file}" ]] && continue

            local end_date
            end_date=$(openssl x509 -enddate -noout -in "${cert_file}" 2>/dev/null | cut -d= -f2) || continue
            [[ -z "${end_date}" ]] && continue

            local end_epoch now_epoch days_left
            end_epoch=$(date -d "${end_date}" +%s 2>/dev/null) || continue
            now_epoch=$(date +%s)
            days_left=$(( (end_epoch - now_epoch) / 86400 ))

            if [[ "${days_left}" -lt 0 ]]; then
                ((expired++))
                _compliance_add_finding "ssl" "critical" "ssl_expiry" "fail" \
                    "Certificate expired: ${cert_file} (${days_left} days ago)" \
                    "Renew certificate immediately"
            elif [[ "${days_left}" -lt "${warning_days}" ]]; then
                ((expiring_soon++))
                _compliance_add_finding "ssl" "warning" "ssl_expiry" "warn" \
                    "Certificate expiring soon: ${cert_file} (${days_left} days)" \
                    "Renew certificate before expiry"
            fi
        done < <(find "${dir}" -name "*.pem" -o -name "*.crt" 2>/dev/null | head -50)
    done

    if [[ "${expired}" -eq 0 ]] && [[ "${expiring_soon}" -eq 0 ]]; then
        _compliance_add_finding "ssl" "info" "ssl_expiry" "pass" \
            "All checked certificates are valid for >${warning_days} days" ""
    fi
}

# Verify backups are recent enough per RPO.
# Usage: compliance_check_backup_age
compliance_check_backup_age() {
    local rpo_hours="${OTTO_BACKUP_RPO_HOURS:-24}"

    log_info "Checking backup age (RPO: ${rpo_hours}h)"

    local backup_dirs=("/var/backups" "/backup" "/opt/backups" "${HOME}/backups")
    local checked=0
    local stale=0

    for dir in "${backup_dirs[@]}"; do
        [[ ! -d "${dir}" ]] && continue

        local newest
        newest=$(find "${dir}" -type f \( -name "*.tar.gz" -o -name "*.sql.gz" -o -name "*.dump" \
            -o -name "*.bak" -o -name "*.backup" \) -printf '%T@ %p\n' 2>/dev/null | \
            sort -n | tail -1 || true)

        if [[ -n "${newest}" ]]; then
            ((checked++))
            local file_epoch
            file_epoch=$(echo "${newest}" | awk '{print int($1)}')
            local now_epoch
            now_epoch=$(date +%s)
            local age_hours=$(( (now_epoch - file_epoch) / 3600 ))

            if [[ "${age_hours}" -gt "${rpo_hours}" ]]; then
                ((stale++))
                local file_name
                file_name=$(echo "${newest}" | awk '{print $2}')
                _compliance_add_finding "backup" "warning" "backup_freshness" "fail" \
                    "Stale backup in ${dir}: newest is ${age_hours}h old (RPO: ${rpo_hours}h) - ${file_name}" \
                    "Run backup immediately and verify backup schedule"
            fi
        fi
    done

    if [[ "${checked}" -eq 0 ]]; then
        _compliance_add_finding "backup" "warning" "backup_freshness" "warn" \
            "No backup directories found to check" \
            "Verify backup locations and ensure backups are configured"
    elif [[ "${stale}" -eq 0 ]]; then
        _compliance_add_finding "backup" "info" "backup_freshness" "pass" \
            "All backups within RPO (${rpo_hours}h)" ""
    fi
}

# Generate a full compliance report.
# Usage: compliance_report
compliance_report() {
    _compliance_reset
    log_info "Running full compliance check"

    compliance_check_k8s_pods
    compliance_check_docker_images
    compliance_check_terraform
    compliance_check_passwords
    compliance_check_ssl_expiry
    compliance_check_backup_age

    local score
    score=$(compliance_score)

    local total passed failed warnings
    total=$(echo "${_COMPLIANCE_FINDINGS}" | jq 'length')
    passed=$(echo "${_COMPLIANCE_FINDINGS}" | jq '[.[] | select(.status == "pass")] | length')
    failed=$(echo "${_COMPLIANCE_FINDINGS}" | jq '[.[] | select(.status == "fail")] | length')
    warnings=$(echo "${_COMPLIANCE_FINDINGS}" | jq '[.[] | select(.status == "warn")] | length')

    jq -n \
        --argjson score "${score}" \
        --argjson total "${total}" \
        --argjson passed "${passed}" \
        --argjson failed "${failed}" \
        --argjson warnings "${warnings}" \
        --argjson findings "${_COMPLIANCE_FINDINGS}" \
        '{
            score: $score,
            total_checks: $total,
            passed: $passed,
            failed: $failed,
            warnings: $warnings,
            findings: $findings
        }'
}

# Calculate overall compliance score (0-100).
# Usage: compliance_score
compliance_score() {
    local total passed failed warnings
    total=$(echo "${_COMPLIANCE_FINDINGS}" | jq 'length')
    passed=$(echo "${_COMPLIANCE_FINDINGS}" | jq '[.[] | select(.status == "pass")] | length')
    failed=$(echo "${_COMPLIANCE_FINDINGS}" | jq '[.[] | select(.status == "fail")] | length')
    warnings=$(echo "${_COMPLIANCE_FINDINGS}" | jq '[.[] | select(.status == "warn")] | length')

    if [[ "${total}" -eq 0 ]]; then
        echo "0"
        return
    fi

    # Score: pass=full weight, warn=half weight, fail=0
    # Weight critical failures more heavily
    local critical_fails
    critical_fails=$(echo "${_COMPLIANCE_FINDINGS}" | jq '[.[] | select(.status == "fail" and .severity == "critical")] | length')
    local normal_fails=$((failed - critical_fails))

    # Each critical fail costs 2x, normal fail costs 1x, warn costs 0.5x
    local max_points=$((total * 100))
    local deductions=$(( (critical_fails * 200) + (normal_fails * 100) + (warnings * 50) ))

    local score=$(( (max_points - deductions) * 100 / max_points ))

    # Clamp to 0-100
    if [[ "${score}" -lt 0 ]]; then
        score=0
    elif [[ "${score}" -gt 100 ]]; then
        score=100
    fi

    echo "${score}"
}
