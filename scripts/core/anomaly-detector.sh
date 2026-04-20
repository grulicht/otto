#!/usr/bin/env bash
# OTTO - AI-Powered Anomaly Detection
# Statistical anomaly detection using Z-score, MAD, IQR, and seasonal analysis
# shellcheck disable=SC2034
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_ANOMALY_DETECTOR_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_ANOMALY_DETECTOR_LOADED=1

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

# Baseline storage directory
OTTO_BASELINES_DIR="${OTTO_HOME}/state/baselines"

# --- Public API ---

# Z-score based anomaly detection.
# Flag data points more than N standard deviations from the mean.
#   $1 - JSON array of numeric values (e.g. '[1.2, 3.4, 5.6]')
#   $2 - Threshold in standard deviations (default: 3)
# Output: JSON object with anomalies array, mean, stddev, threshold
anomaly_detect_zscore() {
    local values_json="${1:?Usage: anomaly_detect_zscore <values_json> [threshold]}"
    local threshold="${2:-3}"

    echo "${values_json}" | jq --argjson threshold "${threshold}" '
        . as $vals |
        ($vals | length) as $n |
        if $n < 2 then
            {error: "Need at least 2 values", anomalies: []}
        else
            ($vals | add / $n) as $mean |
            ([$vals[] | (. - $mean) * (. - $mean)] | add / ($n - 1) | sqrt) as $stddev |
            if $stddev == 0 then
                {mean: $mean, stddev: 0, threshold: $threshold, anomalies: []}
            else
                {
                    mean: $mean,
                    stddev: $stddev,
                    threshold: $threshold,
                    anomalies: [
                        range($n) |
                        . as $i |
                        $vals[$i] as $v |
                        ((($v - $mean) / $stddev) | fabs) as $zscore |
                        select($zscore > $threshold) |
                        {index: $i, value: $v, zscore: ($zscore * 100 | round / 100)}
                    ]
                }
            end
        end
    '
}

# Median Absolute Deviation (MAD) based anomaly detection.
# More robust than Z-score against outliers.
#   $1 - JSON array of numeric values
#   $2 - Threshold multiplier (default: 3)
# Output: JSON object with anomalies, median, mad
anomaly_detect_mad() {
    local values_json="${1:?Usage: anomaly_detect_mad <values_json> [threshold]}"
    local threshold="${2:-3}"

    echo "${values_json}" | jq --argjson threshold "${threshold}" '
        . as $vals |
        ($vals | sort) as $sorted |
        ($sorted | length) as $n |
        if $n < 2 then
            {error: "Need at least 2 values", anomalies: []}
        else
            # Median
            (if $n % 2 == 0 then
                ($sorted[$n/2 - 1] + $sorted[$n/2]) / 2
            else
                $sorted[($n - 1) / 2]
            end) as $median |
            # Absolute deviations from median
            [$vals[] | (. - $median) | fabs] as $abs_devs |
            ($abs_devs | sort) as $sorted_devs |
            ($sorted_devs | length) as $dn |
            (if $dn % 2 == 0 then
                ($sorted_devs[$dn/2 - 1] + $sorted_devs[$dn/2]) / 2
            else
                $sorted_devs[($dn - 1) / 2]
            end) as $mad |
            # Modified Z-score: 0.6745 is the 0.75th quartile of the standard normal distribution
            (if $mad == 0 then 0 else ($mad * 1.4826) end) as $consistency_constant |
            {
                median: $median,
                mad: $mad,
                threshold: $threshold,
                anomalies: [
                    if $consistency_constant > 0 then
                        range($n) |
                        . as $i |
                        $vals[$i] as $v |
                        (((($v - $median) | fabs) / $consistency_constant)) as $modified_zscore |
                        select($modified_zscore > $threshold) |
                        {index: $i, value: $v, modified_zscore: ($modified_zscore * 100 | round / 100)}
                    else
                        empty
                    end
                ]
            }
        end
    '
}

# Interquartile range (IQR) based anomaly detection.
# Flags values below Q1 - 1.5*IQR or above Q3 + 1.5*IQR.
#   $1 - JSON array of numeric values
# Output: JSON object with anomalies, q1, q3, iqr, lower/upper bounds
anomaly_detect_iqr() {
    local values_json="${1:?Usage: anomaly_detect_iqr <values_json>}"

    echo "${values_json}" | jq '
        . as $vals |
        ($vals | sort) as $sorted |
        ($sorted | length) as $n |
        if $n < 4 then
            {error: "Need at least 4 values for IQR", anomalies: []}
        else
            # Q1 (25th percentile) and Q3 (75th percentile)
            ($sorted[($n * 0.25) | floor]) as $q1 |
            ($sorted[($n * 0.75) | floor]) as $q3 |
            ($q3 - $q1) as $iqr |
            ($q1 - 1.5 * $iqr) as $lower |
            ($q3 + 1.5 * $iqr) as $upper |
            {
                q1: $q1,
                q3: $q3,
                iqr: $iqr,
                lower_bound: $lower,
                upper_bound: $upper,
                anomalies: [
                    range($n) |
                    . as $i |
                    $vals[$i] as $v |
                    select($v < $lower or $v > $upper) |
                    {
                        index: $i,
                        value: $v,
                        type: (if $v < $lower then "low" else "high" end)
                    }
                ]
            }
        end
    '
}

# Seasonal anomaly detection.
# Compare current value with same period in previous cycles.
#   $1 - JSON array of {timestamp, value} objects
#   $2 - Period: "hourly", "daily", or "weekly"
# Output: JSON object with anomalies flagged based on historical same-period values
anomaly_detect_seasonal() {
    local values_json="${1:?Usage: anomaly_detect_seasonal <values_json> <period>}"
    local period="${2:-daily}"

    local group_key
    case "${period}" in
        hourly)  group_key='(.timestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%H"))' ;;
        daily)   group_key='(.timestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%u"))' ;;  # day of week
        weekly)  group_key='(.timestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%V"))' ;;  # week number
        *)
            log_error "Invalid period: ${period}. Use hourly, daily, or weekly."
            return 1
            ;;
    esac

    echo "${values_json}" | jq --arg period "${period}" "
        . as \$data |
        [\$data[] | {period_key: ${group_key}, value: .value, timestamp: .timestamp}] |
        group_by(.period_key) |
        [.[] |
            . as \$group |
            (\$group | map(.value)) as \$values |
            (\$values | add / length) as \$mean |
            (\$values | length) as \$n |
            (if \$n > 1 then
                ([\$values[] | (. - \$mean) * (. - \$mean)] | add / (\$n - 1) | sqrt)
            else 0 end) as \$stddev |
            \$group[-1] as \$latest |
            {
                period_key: \$group[0].period_key,
                latest_value: \$latest.value,
                latest_timestamp: \$latest.timestamp,
                historical_mean: (\$mean * 100 | round / 100),
                historical_stddev: (\$stddev * 100 | round / 100),
                sample_count: \$n,
                is_anomaly: (if \$stddev > 0 and \$n > 2 then
                    ((((\$latest.value - \$mean) | fabs) / \$stddev) > 2)
                else false end)
            }
        ] |
        {
            period: \$period,
            groups: .,
            anomalies: [.[] | select(.is_anomaly)]
        }
    "
}

# Store baseline statistics for a metric.
#   $1 - Metric name (used as filename)
#   $2 - JSON array of numeric values
anomaly_baseline_learn() {
    local metric_name="${1:?Usage: anomaly_baseline_learn <metric_name> <data_json>}"
    local data_json="${2:?Usage: anomaly_baseline_learn <metric_name> <data_json>}"

    mkdir -p "${OTTO_BASELINES_DIR}"

    local baseline_file="${OTTO_BASELINES_DIR}/${metric_name}.json"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local baseline
    baseline=$(echo "${data_json}" | jq --arg name "${metric_name}" --arg ts "${timestamp}" '
        . as $vals |
        ($vals | sort) as $sorted |
        ($vals | length) as $n |
        ($vals | add / $n) as $mean |
        (if $n > 1 then
            ([$vals[] | (. - $mean) * (. - $mean)] | add / ($n - 1) | sqrt)
        else 0 end) as $stddev |
        ($sorted[($n * 0.05) | floor]) as $p5 |
        ($sorted[($n * 0.95) | floor]) as $p95 |
        (if $n % 2 == 0 then
            ($sorted[$n/2 - 1] + $sorted[$n/2]) / 2
        else
            $sorted[($n - 1) / 2]
        end) as $median |
        ($sorted | first) as $min |
        ($sorted | last) as $max |
        {
            metric: $name,
            updated_at: $ts,
            sample_count: $n,
            mean: ($mean * 10000 | round / 10000),
            stddev: ($stddev * 10000 | round / 10000),
            median: $median,
            min: $min,
            max: $max,
            p5: $p5,
            p95: $p95
        }
    ')

    echo "${baseline}" > "${baseline_file}"
    log_info "Baseline learned for metric '${metric_name}' (${baseline_file})"
}

# Check if a current value is anomalous against a learned baseline.
#   $1 - Metric name
#   $2 - Current value
# Output: JSON object with is_anomaly, details
anomaly_baseline_check() {
    local metric_name="${1:?Usage: anomaly_baseline_check <metric_name> <current_value>}"
    local current_value="${2:?Usage: anomaly_baseline_check <metric_name> <current_value>}"

    local baseline_file="${OTTO_BASELINES_DIR}/${metric_name}.json"

    if [[ ! -f "${baseline_file}" ]]; then
        log_warn "No baseline found for metric '${metric_name}'. Run anomaly_baseline_learn first."
        jq -n --arg metric "${metric_name}" '{metric: $metric, is_anomaly: false, reason: "no_baseline"}'
        return 0
    fi

    jq --argjson current "${current_value}" '
        . as $b |
        ($b.mean) as $mean |
        ($b.stddev) as $stddev |
        (if $stddev > 0 then ((($current - $mean) | fabs) / $stddev) else 0 end) as $zscore |
        ($current < $b.p5 or $current > $b.p95) as $outside_percentile |
        ($zscore > 3) as $zscore_anomaly |
        {
            metric: $b.metric,
            current_value: $current,
            baseline_mean: $b.mean,
            baseline_stddev: $b.stddev,
            baseline_p5: $b.p5,
            baseline_p95: $b.p95,
            zscore: ($zscore * 100 | round / 100),
            is_anomaly: ($zscore_anomaly or $outside_percentile),
            reasons: [
                (if $zscore_anomaly then "zscore_exceeds_3_stddev" else empty end),
                (if $current < $b.p5 then "below_p5" else empty end),
                (if $current > $b.p95 then "above_p95" else empty end),
                (if $current < $b.min then "below_historical_min" else empty end),
                (if $current > $b.max then "above_historical_max" else empty end)
            ]
        }
    ' "${baseline_file}"
}

# Run anomaly detection on latest fetch results vs. baselines.
# Scans state/baselines/ and checks recent values from state/state.json.
anomaly_report() {
    local baselines_dir="${OTTO_BASELINES_DIR}"
    local state_file="${OTTO_HOME}/state/state.json"

    if [[ ! -d "${baselines_dir}" ]]; then
        log_info "No baselines directory. Learn baselines first with anomaly_baseline_learn."
        return 0
    fi

    local anomaly_count=0
    local checked_count=0
    local report_items="[]"

    for baseline_file in "${baselines_dir}"/*.json; do
        [[ -f "${baseline_file}" ]] || continue

        local metric_name
        metric_name=$(basename "${baseline_file}" .json)

        # Try to get current value from state.json
        local current_value=""
        if [[ -f "${state_file}" ]]; then
            current_value=$(jq -r ".metrics.\"${metric_name}\" // empty" "${state_file}" 2>/dev/null || true)
        fi

        if [[ -z "${current_value}" ]]; then
            log_debug "No current value for metric '${metric_name}', skipping."
            continue
        fi

        checked_count=$((checked_count + 1))

        local result
        result=$(anomaly_baseline_check "${metric_name}" "${current_value}")

        local is_anomaly
        is_anomaly=$(echo "${result}" | jq -r '.is_anomaly')

        if [[ "${is_anomaly}" == "true" ]]; then
            anomaly_count=$((anomaly_count + 1))
            log_warn "ANOMALY: ${metric_name} = ${current_value} ($(echo "${result}" | jq -r '.reasons | join(", ")'))"
        fi

        report_items=$(echo "${report_items}" | jq --argjson item "${result}" '. + [$item]')
    done

    # Output report
    jq -n \
        --argjson items "${report_items}" \
        --argjson anomaly_count "${anomaly_count}" \
        --argjson checked_count "${checked_count}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            timestamp: $timestamp,
            metrics_checked: $checked_count,
            anomalies_found: $anomaly_count,
            results: $items
        }'

    if [[ ${anomaly_count} -gt 0 ]]; then
        log_warn "Anomaly report: ${anomaly_count} anomalies found out of ${checked_count} metrics checked."
    else
        log_info "Anomaly report: No anomalies found (${checked_count} metrics checked)."
    fi
}

# --- CLI entrypoint ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    action="${1:-help}"
    shift || true

    case "${action}" in
        zscore)   anomaly_detect_zscore "$@" ;;
        mad)      anomaly_detect_mad "$@" ;;
        iqr)      anomaly_detect_iqr "$@" ;;
        seasonal) anomaly_detect_seasonal "$@" ;;
        learn)    anomaly_baseline_learn "$@" ;;
        check)    anomaly_baseline_check "$@" ;;
        report)   anomaly_report ;;
        help|*)
            cat <<EOF
Usage: $(basename "$0") <action> [arguments]

Actions:
    zscore <values_json> [threshold]       Z-score anomaly detection
    mad <values_json> [threshold]          MAD anomaly detection
    iqr <values_json>                      IQR anomaly detection
    seasonal <values_json> <period>        Seasonal anomaly detection
    learn <metric_name> <data_json>        Learn baseline for metric
    check <metric_name> <current_value>    Check value against baseline
    report                                 Run anomaly report on all baselines
    help                                   Show this help
EOF
            ;;
    esac
fi
