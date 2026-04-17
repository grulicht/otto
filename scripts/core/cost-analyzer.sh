#!/usr/bin/env bash
# OTTO - Cloud Cost Intelligence
# Multi-cloud cost analysis and optimization recommendations.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_COST_ANALYZER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_COST_ANALYZER_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# --- Internal helpers ---

_cost_require_aws() {
    if ! command -v aws &>/dev/null; then
        log_error "AWS CLI not found - install with: pip install awscli"
        return 1
    fi
}

_cost_require_gcloud() {
    if ! command -v gcloud &>/dev/null; then
        log_error "gcloud CLI not found - install from: https://cloud.google.com/sdk"
        return 1
    fi
}

_cost_require_az() {
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI not found - install with: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
        return 1
    fi
}

_cost_month_start() {
    date -u +"%Y-%m-01"
}

_cost_today() {
    date -u +"%Y-%m-%d"
}

_cost_month_end() {
    date -u -d "$(date -u +%Y-%m-01) +1 month" +"%Y-%m-%d" 2>/dev/null || \
        date -u -v1d -v+1m +"%Y-%m-%d" 2>/dev/null || \
        date -u +"%Y-%m-%d"
}

# --- Public API ---

# Get AWS current month spend via Cost Explorer.
# Usage: cost_get_aws_current_month
cost_get_aws_current_month() {
    _cost_require_aws || return 1

    local start end
    start=$(_cost_month_start)
    end=$(_cost_today)

    log_info "Fetching AWS cost data: ${start} to ${end}"

    aws ce get-cost-and-usage \
        --time-period "Start=${start},End=${end}" \
        --granularity MONTHLY \
        --metrics "UnblendedCost" "UsageQuantity" \
        --group-by Type=DIMENSION,Key=SERVICE \
        --output json 2>/dev/null | jq '{
            provider: "aws",
            period: {start: .ResultsByTime[0].TimePeriod.Start, end: .ResultsByTime[0].TimePeriod.End},
            total: (.ResultsByTime[0].Total.UnblendedCost.Amount // "0" | tonumber),
            currency: (.ResultsByTime[0].Total.UnblendedCost.Unit // "USD"),
            by_service: [.ResultsByTime[0].Groups[] | {
                service: .Keys[0],
                cost: (.Metrics.UnblendedCost.Amount | tonumber)
            }] | sort_by(-.cost)
        }'
}

# Get AWS cost forecast for the current month.
# Usage: cost_get_aws_forecast
cost_get_aws_forecast() {
    _cost_require_aws || return 1

    local start end
    start=$(_cost_today)
    end=$(_cost_month_end)

    # Can only forecast if there are remaining days
    if [[ "${start}" == "${end}" ]]; then
        log_info "Last day of month - no forecast available"
        jq -n '{provider: "aws", forecast: "N/A - last day of month"}'
        return 0
    fi

    log_info "Fetching AWS cost forecast: ${start} to ${end}"

    aws ce get-cost-forecast \
        --time-period "Start=${start},End=${end}" \
        --metric UNBLENDED_COST \
        --granularity MONTHLY \
        --output json 2>/dev/null | jq '{
            provider: "aws",
            forecast_total: (.Total.Amount // "0" | tonumber),
            currency: (.Total.Unit // "USD"),
            prediction_intervals: .ForecastResultsByTime
        }'
}

# Find unused AWS resources: unattached EBS, unused EIPs, stopped EC2, old snapshots.
# Usage: cost_find_unused_aws
cost_find_unused_aws() {
    _cost_require_aws || return 1

    log_info "Scanning for unused AWS resources"

    local unused_ebs unused_eips stopped_ec2 old_snapshots

    # Unattached EBS volumes
    unused_ebs=$(aws ec2 describe-volumes \
        --filters Name=status,Values=available \
        --query 'Volumes[].{id:VolumeId,size:Size,type:VolumeType,created:CreateTime}' \
        --output json 2>/dev/null || echo '[]')

    # Unused Elastic IPs
    unused_eips=$(aws ec2 describe-addresses \
        --query 'Addresses[?AssociationId==null].{ip:PublicIp,alloc_id:AllocationId}' \
        --output json 2>/dev/null || echo '[]')

    # Stopped EC2 instances (>7 days)
    stopped_ec2=$(aws ec2 describe-instances \
        --filters Name=instance-state-name,Values=stopped \
        --query 'Reservations[].Instances[].{id:InstanceId,type:InstanceType,name:Tags[?Key==`Name`]|[0].Value,stopped_since:StateTransitionReason}' \
        --output json 2>/dev/null || echo '[]')

    # Old snapshots (>90 days)
    local cutoff_date
    cutoff_date=$(date -u -d "90 days ago" +"%Y-%m-%dT00:00:00Z" 2>/dev/null || \
                  date -u -v-90d +"%Y-%m-%dT00:00:00Z" 2>/dev/null || echo "")

    if [[ -n "${cutoff_date}" ]]; then
        old_snapshots=$(aws ec2 describe-snapshots --owner-ids self \
            --query "Snapshots[?StartTime<='${cutoff_date}'].{id:SnapshotId,size:VolumeSize,started:StartTime,desc:Description}" \
            --output json 2>/dev/null || echo '[]')
    else
        old_snapshots='[]'
    fi

    jq -n \
        --argjson ebs "${unused_ebs}" \
        --argjson eips "${unused_eips}" \
        --argjson ec2 "${stopped_ec2}" \
        --argjson snaps "${old_snapshots}" \
        '{
            provider: "aws",
            unused_ebs_volumes: {count: ($ebs | length), items: $ebs},
            unused_elastic_ips: {count: ($eips | length), items: $eips},
            stopped_instances: {count: ($ec2 | length), items: $ec2},
            old_snapshots: {count: ($snaps | length), items: $snaps},
            estimated_monthly_waste: (
                ([$ebs[] | if .type == "gp3" then .size * 0.08 elif .type == "gp2" then .size * 0.10 else .size * 0.05 end] | add // 0) +
                ([$eips[] | 3.6] | add // 0)
            )
        }'
}

# Get GCP current month billing.
# Usage: cost_get_gcp_billing
cost_get_gcp_billing() {
    _cost_require_gcloud || return 1

    local project
    project=$(gcloud config get-value project 2>/dev/null || echo "")

    if [[ -z "${project}" ]]; then
        log_error "No GCP project configured"
        return 1
    fi

    log_info "Fetching GCP billing for project: ${project}"

    local billing_account
    billing_account=$(gcloud billing projects describe "${project}" \
        --format='value(billingAccountName)' 2>/dev/null || echo "")

    if [[ -z "${billing_account}" ]]; then
        log_warn "No billing account linked to project ${project}"
        jq -n --arg project "${project}" '{provider: "gcp", project: $project, error: "no billing account"}'
        return 0
    fi

    # Use BigQuery export if available, otherwise basic info
    local start
    start=$(_cost_month_start)

    gcloud billing budgets list --billing-account="${billing_account##*/}" \
        --format=json 2>/dev/null | jq --arg project "${project}" '{
            provider: "gcp",
            project: $project,
            budgets: [.[] | {name: .displayName, amount: .amount.specifiedAmount, spent: .budgetFilter}]
        }' 2>/dev/null || \
    jq -n --arg project "${project}" --arg ba "${billing_account}" '{
        provider: "gcp",
        project: $project,
        billing_account: $ba,
        note: "Detailed billing requires BigQuery export. Enable it at: https://cloud.google.com/billing/docs/how-to/export-data-bigquery"
    }'
}

# Get Azure current month billing.
# Usage: cost_get_azure_billing
cost_get_azure_billing() {
    _cost_require_az || return 1

    log_info "Fetching Azure cost data"

    local subscription
    subscription=$(az account show --query 'id' -o tsv 2>/dev/null || echo "")

    if [[ -z "${subscription}" ]]; then
        log_error "No Azure subscription found"
        return 1
    fi

    local start end
    start=$(_cost_month_start)
    end=$(_cost_today)

    az consumption usage list \
        --start-date "${start}" --end-date "${end}" \
        --query '[].{service:consumedService,cost:pretaxCost,currency:currency}' \
        -o json 2>/dev/null | jq --arg sub "${subscription}" '{
            provider: "azure",
            subscription: $sub,
            period: {start: "'"${start}"'", end: "'"${end}"'"},
            total: ([.[].cost] | add // 0),
            currency: (.[0].currency // "USD"),
            by_service: (group_by(.service) | map({
                service: .[0].service,
                cost: ([.[].cost] | add)
            }) | sort_by(-.cost))
        }' 2>/dev/null || \
    jq -n --arg sub "${subscription}" '{
        provider: "azure",
        subscription: $sub,
        error: "Failed to fetch cost data. Ensure consumption API access."
    }'
}

# Generate cost optimization recommendations.
# Usage: cost_recommendations
cost_recommendations() {
    local recommendations='[]'

    # Check AWS if available
    if command -v aws &>/dev/null; then
        local unused
        unused=$(cost_find_unused_aws 2>/dev/null || echo '{}')

        local waste
        waste=$(echo "${unused}" | jq '.estimated_monthly_waste // 0')

        if (( $(echo "${waste} > 0" | bc -l 2>/dev/null || echo 0) )); then
            recommendations=$(echo "${recommendations}" | jq --argjson waste "${waste}" \
                '. + [{
                    provider: "aws",
                    category: "unused_resources",
                    priority: "high",
                    estimated_savings: $waste,
                    recommendation: "Remove unused EBS volumes, release unused Elastic IPs, and terminate stopped instances"
                }]')
        fi

        # Check for Reserved Instance recommendations
        local ri_recs
        ri_recs=$(aws ce get-reservation-purchase-recommendation \
            --service "Amazon Elastic Compute Cloud - Compute" \
            --term-in-years ONE_YEAR \
            --payment-option NO_UPFRONT \
            --lookback-period-in-days SIXTY_DAYS \
            --output json 2>/dev/null || echo '{}')

        local ri_savings
        ri_savings=$(echo "${ri_recs}" | jq '[.Recommendations[]?.RecommendationDetails[]?.EstimatedMonthlySavingsAmount // "0" | tonumber] | add // 0')

        if (( $(echo "${ri_savings} > 0" | bc -l 2>/dev/null || echo 0) )); then
            recommendations=$(echo "${recommendations}" | jq --argjson savings "${ri_savings}" \
                '. + [{
                    provider: "aws",
                    category: "reserved_instances",
                    priority: "medium",
                    estimated_savings: $savings,
                    recommendation: "Purchase Reserved Instances for stable workloads"
                }]')
        fi
    fi

    echo "${recommendations}" | jq '{
        recommendations: .,
        total_potential_savings: ([.[].estimated_savings] | add // 0)
    }'
}

# Combined multi-cloud cost summary.
# Usage: cost_summary
cost_summary() {
    log_info "Generating multi-cloud cost summary"

    local aws_cost='null'
    local gcp_cost='null'
    local azure_cost='null'
    local aws_forecast='null'

    if command -v aws &>/dev/null; then
        aws_cost=$(cost_get_aws_current_month 2>/dev/null || echo 'null')
        aws_forecast=$(cost_get_aws_forecast 2>/dev/null || echo 'null')
    fi

    if command -v gcloud &>/dev/null; then
        gcp_cost=$(cost_get_gcp_billing 2>/dev/null || echo 'null')
    fi

    if command -v az &>/dev/null; then
        azure_cost=$(cost_get_azure_billing 2>/dev/null || echo 'null')
    fi

    local recs
    recs=$(cost_recommendations 2>/dev/null || echo '{"recommendations":[],"total_potential_savings":0}')

    jq -n \
        --argjson aws "${aws_cost}" \
        --argjson aws_forecast "${aws_forecast}" \
        --argjson gcp "${gcp_cost}" \
        --argjson azure "${azure_cost}" \
        --argjson recs "${recs}" \
        '{
            generated_at: (now | todate),
            clouds: {
                aws: $aws,
                aws_forecast: $aws_forecast,
                gcp: $gcp,
                azure: $azure
            },
            recommendations: $recs.recommendations,
            total_potential_savings: $recs.total_potential_savings
        }'
}
