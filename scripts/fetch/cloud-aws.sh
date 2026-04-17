#!/usr/bin/env bash
# OTTO - Fetch AWS account overview
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"ec2_instances":0,"rds_instances":0,"s3_buckets":0,"lambda_functions":0,"eks_clusters":0,"monthly_cost_estimate":"unknown","iam_users":0}'

if ! command -v aws &>/dev/null; then
    log_debug "aws CLI not found, skipping AWS fetch"
    echo "${empty_result}"
    exit 0
fi

if ! aws sts get-caller-identity &>/dev/null 2>&1; then
    log_warn "Cannot authenticate to AWS"
    echo "${empty_result}"
    exit 0
fi

ec2_instances=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' --output json 2>/dev/null | jq 'flatten | length' 2>/dev/null) || ec2_instances=0
rds_instances=$(aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier' --output json 2>/dev/null | jq 'length' 2>/dev/null) || rds_instances=0
s3_buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output json 2>/dev/null | jq 'length' 2>/dev/null) || s3_buckets=0
lambda_functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output json 2>/dev/null | jq 'length' 2>/dev/null) || lambda_functions=0
eks_clusters=$(aws eks list-clusters --query 'clusters' --output json 2>/dev/null | jq 'length' 2>/dev/null) || eks_clusters=0
iam_users=$(aws iam list-users --query 'Users[*].UserName' --output json 2>/dev/null | jq 'length' 2>/dev/null) || iam_users=0

monthly_cost_estimate="unknown"
if cost_data=$(aws ce get-cost-and-usage \
    --time-period "Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d)" \
    --granularity MONTHLY --metrics BlendedCost --output json 2>/dev/null); then
    monthly_cost_estimate=$(echo "${cost_data}" | jq -r '.ResultsByTime[-1].Total.BlendedCost.Amount // "unknown"' 2>/dev/null) || monthly_cost_estimate="unknown"
fi

jq -n \
    --argjson ec2 "${ec2_instances}" \
    --argjson rds "${rds_instances}" \
    --argjson s3 "${s3_buckets}" \
    --argjson lambda "${lambda_functions}" \
    --argjson eks "${eks_clusters}" \
    --arg cost "${monthly_cost_estimate}" \
    --argjson iam "${iam_users}" \
    '{
        ec2_instances: $ec2,
        rds_instances: $rds,
        s3_buckets: $s3,
        lambda_functions: $lambda,
        eks_clusters: $eks,
        monthly_cost_estimate: $cost,
        iam_users: $iam
    }'
