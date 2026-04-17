#!/usr/bin/env bash
# OTTO - Alert Aggregation Engine
# Collects alerts from multiple sources, deduplicates and correlates them.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_ALERT_AGGREGATOR_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_ALERT_AGGREGATOR_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# Default dedup time window in seconds (5 minutes)
ALERT_DEDUP_WINDOW="${ALERT_DEDUP_WINDOW:-300}"

# --- Public API ---

# Generate a unique fingerprint for deduplication.
# Usage: alert_fingerprint <source> <name> <target>
alert_fingerprint() {
    local source="$1"
    local name="$2"
    local target="$3"
    printf '%s|%s|%s' "${source}" "${name}" "${target}" | md5sum | awk '{print $1}'
}

# Remove duplicate alerts within ALERT_DEDUP_WINDOW seconds.
# Usage: alert_deduplicate <alerts_json>
alert_deduplicate() {
    local alerts_json="$1"
    local window="${ALERT_DEDUP_WINDOW}"
    local now
    now=$(date +%s)

    echo "${alerts_json}" | jq --argjson window "${window}" --argjson now "${now}" '
        group_by(.fingerprint)
        | map(
            sort_by(.timestamp) | reverse
            | {
                fingerprint: .[0].fingerprint,
                count: length,
                severity: .[0].severity,
                source: .[0].source,
                name: .[0].name,
                target: .[0].target,
                message: .[0].message,
                first_seen: (last | .timestamp),
                last_seen: (first | .timestamp),
                alerts: map(select(($now - (.timestamp | tonumber)) <= $window))
              }
        )
        | map(select(.alerts | length > 0))
        | map(del(.alerts))
    '
}

# Aggregate alerts from multiple sources JSON.
# Input: JSON array of objects with "source" and "alerts" keys.
# Each alert should have: name, target, severity, message, timestamp.
# Usage: alert_aggregate <sources_json>
alert_aggregate() {
    local sources_json="$1"

    # Flatten all alerts and add fingerprints
    local merged
    merged=$(echo "${sources_json}" | jq '
        [.[] | .source as $src | .alerts[] |
            . + {
                source: $src,
                fingerprint: ([$src, .name, .target] | join("|") | @base64)
            }
        ]
    ')

    # Deduplicate
    alert_deduplicate "${merged}"
}

# Correlate related alerts (e.g., high CPU + OOMKill on the same host).
# Usage: alert_correlate <alerts_json>
alert_correlate() {
    local alerts_json="$1"

    echo "${alerts_json}" | jq '
        # Group by target (host/pod)
        group_by(.target)
        | map(select(length > 1))
        | map({
            host: .[0].target,
            related_alerts: [.[] | {name: .name, severity: .severity, source: .source}],
            likely_cause: (
                if ([.[] | .name] | any(test("OOM|oom|memory"; "i"))) and
                   ([.[] | .name] | any(test("CPU|cpu|load"; "i")))
                then "Resource exhaustion - high CPU and memory pressure"
                elif ([.[] | .name] | any(test("disk|Disk|storage"; "i"))) and
                     ([.[] | .name] | any(test("IO|io|latency"; "i")))
                then "Disk I/O bottleneck"
                elif ([.[] | .name] | any(test("OOM|oom|CrashLoop"; "i")))
                then "Application crash loop due to memory limits"
                elif ([.[] | .name] | any(test("network|Network|connection"; "i")))
                then "Network connectivity issues"
                else "Multiple alerts on same target - investigate manually"
                end
            )
        })
    '
}

# Sort alerts by severity: critical > warning > info.
# Usage: alert_severity_sort <alerts_json>
alert_severity_sort() {
    local alerts_json="$1"

    echo "${alerts_json}" | jq '
        sort_by(
            if .severity == "critical" then 0
            elif .severity == "warning" then 1
            elif .severity == "info" then 2
            else 3 end
        )
    '
}

# Generate a summary of alerts: counts by severity, top affected hosts, top alert types.
# Usage: alert_summary <alerts_json>
alert_summary() {
    local alerts_json="$1"

    local deduped
    deduped=$(alert_deduplicate "${alerts_json}")

    local correlations
    correlations=$(alert_correlate "${alerts_json}")

    local sorted
    sorted=$(echo "${deduped}" | jq '
        sort_by(
            if .severity == "critical" then 0
            elif .severity == "warning" then 1
            elif .severity == "info" then 2
            else 3 end
        )
    ')

    jq -n \
        --argjson groups "${sorted}" \
        --argjson correlations "${correlations}" \
        '{
            total: ($groups | length),
            critical: ([$groups[] | select(.severity == "critical")] | length),
            warning: ([$groups[] | select(.severity == "warning")] | length),
            info: ([$groups[] | select(.severity == "info")] | length),
            groups: $groups,
            correlations: $correlations
        }'
}
