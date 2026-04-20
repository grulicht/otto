#!/usr/bin/env bash
# OTTO - Capacity Planning
# Predict resource exhaustion and forecast growth using trend analysis.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_CAPACITY_PLANNER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_CAPACITY_PLANNER_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/trend-analyzer.sh"

# --- Public API ---

# Predict when a disk mount point will be exhausted based on current usage trend.
# Usage: capacity_disk_prediction <mount_point>
capacity_disk_prediction() {
    local mount_point="${1:-/}"

    local usage_pct total_kb _used_kb avail_kb
    read -r total_kb _used_kb avail_kb usage_pct <<< "$(df -k "${mount_point}" | awk 'NR==2 {gsub(/%/,"",$5); print $2, $3, $4, $5}')"

    local usage_num="${usage_pct}"

    # Estimate days to full based on historical data if available
    local state_file="${OTTO_HOME}/state/disk-${mount_point//\//_}.json"
    local days_to_full="unknown"

    if [[ -f "${state_file}" ]]; then
        local data_points
        data_points=$(cat "${state_file}")
        local trend
        trend=$(trend_analyze_metric "disk_${mount_point//\//_}" "${data_points}" 2>/dev/null) || trend=""
        if [[ -n "${trend}" ]]; then
            local rate
            rate=$(echo "${trend}" | jq -r '.rate_per_day // 0')
            if [[ "$(echo "${rate}" | awk '{print ($1 > 0)}')" == "1" ]]; then
                days_to_full=$(echo "${rate} ${usage_num}" | awk '{printf "%.0f", (100 - $2) / $1}')
            fi
        fi
    fi

    jq -n --arg mp "${mount_point}" --argjson pct "${usage_num}" \
        --argjson total_gb "$(echo "${total_kb}" | awk '{printf "%.1f", $1/1048576}')" \
        --argjson avail_gb "$(echo "${avail_kb}" | awk '{printf "%.1f", $1/1048576}')" \
        --arg days_to_full "${days_to_full}" \
        '{
            mount_point: $mp,
            usage_percent: $pct,
            total_gb: $total_gb,
            available_gb: $avail_gb,
            days_to_full: $days_to_full,
            severity: (if $pct > 90 then "critical" elif $pct > 80 then "warning" else "ok" end)
        }'
}

# Predict memory exhaustion for a host.
# Usage: capacity_memory_prediction <host>
capacity_memory_prediction() {
    local host="${1:-localhost}"

    local mem_info
    if [[ "${host}" == "localhost" ]]; then
        mem_info=$(free -m | awk 'NR==2 {printf "{\"total_mb\":%d,\"used_mb\":%d,\"available_mb\":%d,\"usage_pct\":%.1f}", $2, $3, $7, $3/$2*100}')
    else
        mem_info=$(ssh "${host}" "free -m" 2>/dev/null | awk 'NR==2 {printf "{\"total_mb\":%d,\"used_mb\":%d,\"available_mb\":%d,\"usage_pct\":%.1f}", $2, $3, $7, $3/$2*100}') || {
            log_error "Failed to get memory info from ${host}"
            return 1
        }
    fi

    local usage_pct
    usage_pct=$(echo "${mem_info}" | jq -r '.usage_pct')

    echo "${mem_info}" | jq --arg host "${host}" \
        '. + {host: $host, severity: (if .usage_pct > 90 then "critical" elif .usage_pct > 80 then "warning" else "ok" end)}'
}

# Analyze CPU usage trend over a given period.
# Usage: capacity_cpu_trend <host> <days>
capacity_cpu_trend() {
    local host="${1:-localhost}"
    local days="${2:-7}"

    local state_file="${OTTO_HOME}/state/cpu-${host}.json"

    if [[ ! -f "${state_file}" ]]; then
        # Collect current snapshot
        local cpu_idle
        if [[ "${host}" == "localhost" ]]; then
            cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%')
        else
            cpu_idle=$(ssh "${host}" "top -bn1" 2>/dev/null | grep "Cpu(s)" | awk '{print $8}' | tr -d '%') || cpu_idle="0"
        fi
        local cpu_used
        cpu_used=$(echo "100 - ${cpu_idle:-0}" | bc 2>/dev/null) || cpu_used="0"

        jq -n --arg host "${host}" --argjson cpu "${cpu_used}" \
            '{host: $host, current_cpu_percent: $cpu, trend: "insufficient_data", note: "Collect more data points for trend analysis"}'
        return 0
    fi

    local data_points
    data_points=$(cat "${state_file}")
    local trend
    trend=$(trend_analyze_metric "cpu_${host}" "${data_points}" 2>/dev/null) || trend='{}'

    echo "${trend}" | jq --arg host "${host}" --argjson days "${days}" \
        '. + {host: $host, analysis_period_days: $days}'
}

# Predict when Kubernetes nodes will need scaling.
# Usage: capacity_k8s_node_pressure <context>
# shellcheck disable=SC2120
capacity_k8s_node_pressure() {
    local context="${1:-}"
    local ctx_flag=""
    [[ -n "${context}" ]] && ctx_flag="--context ${context}"

    local node_info
    # shellcheck disable=SC2086
    node_info=$(kubectl ${ctx_flag} top nodes --no-headers 2>/dev/null) || {
        log_error "Failed to get node metrics (metrics-server required)"
        return 1
    }

    local results="[]"
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        local node cpu_pct mem_pct
        node=$(echo "${line}" | awk '{print $1}')
        cpu_pct=$(echo "${line}" | awk '{gsub(/%/,""); print $3}')
        mem_pct=$(echo "${line}" | awk '{gsub(/%/,""); print $5}')

        local pressure="none"
        if (( $(echo "${cpu_pct} > 80" | bc -l) )) || (( $(echo "${mem_pct} > 80" | bc -l) )); then
            pressure="high"
        elif (( $(echo "${cpu_pct} > 60" | bc -l) )) || (( $(echo "${mem_pct} > 60" | bc -l) )); then
            pressure="moderate"
        fi

        results=$(echo "${results}" | jq --arg n "${node}" --argjson cpu "${cpu_pct}" \
            --argjson mem "${mem_pct}" --arg p "${pressure}" \
            '. + [{"node": $n, "cpu_percent": $cpu, "memory_percent": $mem, "pressure": $p}]')
    done <<< "${node_info}"

    local high_pressure
    high_pressure=$(echo "${results}" | jq '[.[] | select(.pressure == "high")] | length')

    echo "${results}" | jq --argjson hp "${high_pressure}" \
        '{nodes: ., high_pressure_count: $hp, recommendation: (if $hp > 0 then "Consider adding nodes or scaling down workloads" else "Node capacity is adequate" end)}'
}

# Forecast cloud costs for upcoming months.
# Usage: capacity_cost_forecast <provider> <months>
capacity_cost_forecast() {
    local provider="${1:-aws}"
    local months="${2:-3}"

    local cost_file="${OTTO_HOME}/state/cost-${provider}.json"
    if [[ ! -f "${cost_file}" ]]; then
        log_warn "No cost data for provider ${provider}. Run cost-analyzer first."
        echo '{"error": "No cost data available"}'
        return 0
    fi

    local cost_data
    cost_data=$(cat "${cost_file}")
    local monthly_total
    monthly_total=$(echo "${cost_data}" | jq -r '.monthly_total // 0')
    local growth_rate
    growth_rate=$(echo "${cost_data}" | jq -r '.monthly_growth_rate // 0.05')

    local forecast="[]"
    for i in $(seq 1 "${months}"); do
        local projected
        projected=$(echo "${monthly_total} ${growth_rate} ${i}" | awk '{printf "%.2f", $1 * (1 + $2) ^ $3}')
        forecast=$(echo "${forecast}" | jq --argjson m "${i}" --argjson cost "${projected}" \
            '. + [{"month": $m, "projected_cost": $cost}]')
    done

    jq -n --arg provider "${provider}" --argjson current "${monthly_total}" \
        --argjson forecast "${forecast}" --argjson months "${months}" \
        '{provider: $provider, current_monthly: $current, forecast: $forecast, months_ahead: $months}'
}

# Generate a combined capacity planning report with recommendations.
# Usage: capacity_report
capacity_report() {
    log_info "Generating capacity planning report..."

    local disk_report mem_report
    disk_report=$(capacity_disk_prediction "/" 2>/dev/null) || disk_report='{"error": "unable to collect"}'
    mem_report=$(capacity_memory_prediction "localhost" 2>/dev/null) || mem_report='{"error": "unable to collect"}'

    local k8s_report='{}'
    if command -v kubectl &>/dev/null; then
        k8s_report=$(capacity_k8s_node_pressure 2>/dev/null) || k8s_report='{"error": "unable to collect"}'
    fi

    local recommendations="[]"

    # Disk recommendations
    local disk_sev
    disk_sev=$(echo "${disk_report}" | jq -r '.severity // "unknown"')
    if [[ "${disk_sev}" == "critical" ]]; then
        recommendations=$(echo "${recommendations}" | jq '. + ["CRITICAL: Root disk usage above 90% - immediate action needed"]')
    elif [[ "${disk_sev}" == "warning" ]]; then
        recommendations=$(echo "${recommendations}" | jq '. + ["WARNING: Root disk usage above 80% - plan expansion"]')
    fi

    # Memory recommendations
    local mem_sev
    mem_sev=$(echo "${mem_report}" | jq -r '.severity // "unknown"')
    if [[ "${mem_sev}" == "critical" ]]; then
        recommendations=$(echo "${recommendations}" | jq '. + ["CRITICAL: Memory usage above 90% - investigate memory consumers"]')
    elif [[ "${mem_sev}" == "warning" ]]; then
        recommendations=$(echo "${recommendations}" | jq '. + ["WARNING: Memory usage above 80% - consider adding RAM or optimizing"]')
    fi

    jq -n --argjson disk "${disk_report}" --argjson mem "${mem_report}" \
        --argjson k8s "${k8s_report}" --argjson recs "${recommendations}" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{timestamp: $ts, disk: $disk, memory: $mem, kubernetes: $k8s, recommendations: $recs}'
}
