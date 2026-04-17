#!/usr/bin/env bash
# OTTO - Trend Analysis
# Analyzes trends, predicts resource exhaustion, and detects anomalies.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_TREND_ANALYZER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_TREND_ANALYZER_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# --- Public API ---

# Analyze trend direction and rate of change for a metric.
# Input: metric_name (string), data_points_json (array of {timestamp, value})
# Usage: trend_analyze_metric <metric_name> <data_points_json>
trend_analyze_metric() {
    local metric_name="$1"
    local data_points_json="$2"

    echo "${data_points_json}" | jq --arg name "${metric_name}" '
        sort_by(.timestamp) |
        if length < 2 then
            {metric: $name, direction: "insufficient_data", rate_per_day: 0, data_points: length}
        else
            . as $sorted |
            ($sorted | length) as $n |
            ($sorted | first | .value) as $first_val |
            ($sorted | last | .value) as $last_val |
            ($sorted | first | .timestamp) as $first_ts |
            ($sorted | last | .timestamp) as $last_ts |
            (($last_ts - $first_ts) / 86400) as $days |
            (if $days > 0 then ($last_val - $first_val) / $days else 0 end) as $rate |
            # Calculate mean
            ([$sorted[].value] | add / length) as $mean |
            # Calculate standard deviation
            ([$sorted[].value | (. - $mean) * (. - $mean)] | add / ($n - 1) | sqrt) as $stddev |
            # Determine direction based on linear trend
            (if $rate > ($stddev * 0.1) then "increasing"
             elif $rate < (-$stddev * 0.1) then "decreasing"
             else "stable" end) as $direction |
            {
                metric: $name,
                direction: $direction,
                rate_per_day: ($rate * 100 | round / 100),
                first_value: $first_val,
                last_value: $last_val,
                mean: ($mean * 100 | round / 100),
                stddev: ($stddev * 100 | round / 100),
                data_points: $n,
                period_days: ($days * 100 | round / 100)
            }
        end
    '
}

# Predict when a resource will be exhausted.
# Usage: trend_predict_exhaustion <current_value> <max_value> <rate_per_day>
trend_predict_exhaustion() {
    local current_value="$1"
    local max_value="$2"
    local rate_per_day="$3"

    jq -n \
        --argjson current "${current_value}" \
        --argjson max "${max_value}" \
        --argjson rate "${rate_per_day}" \
        '
        ($max - $current) as $remaining |
        (if $rate > 0 then ($remaining / $rate)
         else null end) as $days_until |
        {
            current_value: $current,
            max_value: $max,
            utilization_pct: ($current / $max * 10000 | round / 100),
            remaining: $remaining,
            rate_per_day: $rate,
            days_until_exhaustion: (if $days_until != null then ($days_until * 10 | round / 10) else null end),
            exhaustion_date: (
                if $days_until != null and $days_until > 0 then
                    (now + ($days_until * 86400) | todate)
                elif $days_until != null and $days_until <= 0 then
                    "ALREADY_EXHAUSTED"
                else
                    "NOT_APPLICABLE (stable or decreasing)"
                end
            ),
            urgency: (
                if $days_until == null then "none"
                elif $days_until <= 0 then "critical"
                elif $days_until <= 1 then "critical"
                elif $days_until <= 7 then "high"
                elif $days_until <= 30 then "medium"
                else "low"
                end
            )
        }
    '
}

# Compare two time periods and highlight significant changes.
# Usage: trend_compare_periods <current_json> <previous_json>
# Both inputs are arrays of {metric, value}.
trend_compare_periods() {
    local current_json="$1"
    local previous_json="$2"

    jq -n \
        --argjson current "${current_json}" \
        --argjson previous "${previous_json}" \
        '
        # Index previous by metric name
        ($previous | map({(.metric): .value}) | add // {}) as $prev_map |
        [
            $current[] |
            .metric as $m |
            .value as $cur |
            ($prev_map[$m] // null) as $prev |
            {
                metric: $m,
                current: $cur,
                previous: $prev,
                change: (if $prev != null then $cur - $prev else null end),
                change_pct: (
                    if $prev != null and $prev != 0 then
                        (($cur - $prev) / $prev * 10000 | round / 100)
                    else null end
                ),
                significant: (
                    if $prev != null and $prev != 0 then
                        ((($cur - $prev) / $prev) | fabs) > 0.1
                    else false end
                )
            }
        ] |
        {
            comparisons: .,
            significant_changes: [.[] | select(.significant == true)],
            improved: [.[] | select(.change_pct != null and .change_pct < -10)],
            degraded: [.[] | select(.change_pct != null and .change_pct > 10)]
        }
    '
}

# Read last 7 days of night-watch logs and generate trend summary.
# Usage: trend_weekly_summary
trend_weekly_summary() {
    local log_dir="${OTTO_HOME}/state/night-watch"
    local cutoff
    cutoff=$(date -d "7 days ago" +%s 2>/dev/null || date -v-7d +%s 2>/dev/null || echo "0")

    if [[ ! -d "${log_dir}" ]]; then
        log_warn "No night-watch log directory found"
        jq -n '{error: "No night-watch logs found", period: "7d"}'
        return 0
    fi

    # Collect all log entries from the last 7 days
    local all_entries="[]"

    while IFS= read -r logfile; do
        [[ -z "${logfile}" ]] && continue
        local entries
        entries=$(jq -s --argjson cutoff "${cutoff}" '
            [.[] | select((.ts // "" | fromdateiso8601 // 0) >= $cutoff)]
        ' "${logfile}" 2>/dev/null || echo '[]')
        all_entries=$(jq -s '.[0] + .[1]' <(echo "${all_entries}") <(echo "${entries}"))
    done < <(find "${log_dir}" -name "*.jsonl" -type f 2>/dev/null)

    echo "${all_entries}" | jq '{
        period: "7d",
        total_entries: length,
        by_level: (group_by(.level // "unknown") | map({(.[0].level // "unknown"): length}) | add // {}),
        by_action: (group_by(.action // "unknown") | map({(.[0].action // "unknown"): length}) | add // {}),
        remediation_actions: [.[] | select(.action != null)] | length,
        alerts_by_day: (
            group_by(.ts[:10] // "unknown") |
            map({date: .[0].ts[:10], count: length}) |
            sort_by(.date)
        )
    }'
}

# Simple statistical anomaly detection.
# Usage: trend_anomaly_detect <data_points_json> <threshold_stddev>
# data_points_json: array of {timestamp, value}
# threshold_stddev: number of standard deviations to flag (default: 2)
trend_anomaly_detect() {
    local data_points_json="$1"
    local threshold_stddev="${2:-2}"

    echo "${data_points_json}" | jq --argjson threshold "${threshold_stddev}" '
        sort_by(.timestamp) |
        if length < 3 then
            {anomalies: [], error: "Need at least 3 data points", threshold_stddev: $threshold}
        else
            (length) as $n |
            ([.[].value] | add / $n) as $mean |
            ([.[].value | (. - $mean) * (. - $mean)] | add / ($n - 1) | sqrt) as $stddev |
            ($mean - ($stddev * $threshold)) as $lower |
            ($mean + ($stddev * $threshold)) as $upper |
            {
                mean: ($mean * 100 | round / 100),
                stddev: ($stddev * 100 | round / 100),
                threshold_stddev: $threshold,
                lower_bound: ($lower * 100 | round / 100),
                upper_bound: ($upper * 100 | round / 100),
                total_points: $n,
                anomalies: [
                    .[] | select(.value < $lower or .value > $upper) |
                    {
                        timestamp: .timestamp,
                        value: .value,
                        deviation: (((.value - $mean) / (if $stddev > 0 then $stddev else 1 end)) * 100 | round / 100),
                        type: (if .value > $upper then "spike" else "dip" end)
                    }
                ],
                anomaly_count: ([.[] | select(.value < $lower or .value > $upper)] | length),
                anomaly_pct: (([.[] | select(.value < $lower or .value > $upper)] | length) / $n * 10000 | round / 100)
            }
        end
    '
}
