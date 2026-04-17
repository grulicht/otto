#!/usr/bin/env bash
# OTTO - Fetch GCP project overview
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"gke_clusters":0,"compute_instances":0,"cloud_run_services":0,"cloud_sql_instances":0,"project_id":"unknown"}'

if ! command -v gcloud &>/dev/null; then
    log_debug "gcloud CLI not found, skipping GCP fetch"
    echo "${empty_result}"
    exit 0
fi

project_id=$(gcloud config get-value project 2>/dev/null) || project_id="unknown"
if [[ -z "${project_id}" || "${project_id}" == "(unset)" ]]; then
    log_warn "No GCP project configured"
    echo "${empty_result}"
    exit 0
fi

gke_clusters=$(gcloud container clusters list --format=json 2>/dev/null | jq 'length' 2>/dev/null) || gke_clusters=0
compute_instances=$(gcloud compute instances list --format=json 2>/dev/null | jq 'length' 2>/dev/null) || compute_instances=0
cloud_run_services=$(gcloud run services list --format=json 2>/dev/null | jq 'length' 2>/dev/null) || cloud_run_services=0
cloud_sql_instances=$(gcloud sql instances list --format=json 2>/dev/null | jq 'length' 2>/dev/null) || cloud_sql_instances=0

jq -n \
    --argjson gke "${gke_clusters}" \
    --argjson compute "${compute_instances}" \
    --argjson run "${cloud_run_services}" \
    --argjson sql "${cloud_sql_instances}" \
    --arg project "${project_id}" \
    '{
        gke_clusters: $gke,
        compute_instances: $compute,
        cloud_run_services: $run,
        cloud_sql_instances: $sql,
        project_id: $project
    }'
