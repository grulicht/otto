#!/usr/bin/env bash
# OTTO - Fetch Docker status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"containers_running":0,"containers_stopped":0,"images":0,"disk_usage":{},"unhealthy_containers":[]}'

# Graceful exit if docker is not installed
if ! command -v docker &>/dev/null; then
    log_debug "docker not found, skipping Docker fetch"
    echo "${empty_result}"
    exit 0
fi

# Verify Docker daemon connectivity
if ! docker info &>/dev/null 2>&1; then
    log_warn "Cannot connect to Docker daemon"
    echo "${empty_result}"
    exit 0
fi

# Count running containers
containers_running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ') || containers_running=0

# Count stopped containers
containers_stopped=$(docker ps -q --filter "status=exited" --filter "status=dead" --filter "status=created" 2>/dev/null | wc -l | tr -d ' ') || containers_stopped=0

# Count images
images=$(docker images -q 2>/dev/null | wc -l | tr -d ' ') || images=0

# Disk usage
disk_usage="{}"
if docker_df=$(docker system df --format '{{json .}}' 2>/dev/null); then
    disk_usage=$(echo "${docker_df}" | jq -s '{
        images: (map(select(.Type == "Images")) | .[0] // {}),
        containers: (map(select(.Type == "Containers")) | .[0] // {}),
        volumes: (map(select(.Type == "Local Volumes")) | .[0] // {}),
        build_cache: (map(select(.Type == "Build Cache")) | .[0] // {})
    } | {
        images_size: (.images.Size // "0B"),
        containers_size: (.containers.Size // "0B"),
        volumes_size: (.volumes.Size // "0B"),
        build_cache_size: (.build_cache.Size // "0B"),
        reclaimable: (.images.Reclaimable // "0B")
    }' 2>/dev/null) || disk_usage="{}"
fi

# Unhealthy containers
unhealthy_containers=$(docker ps --filter "health=unhealthy" --format '{{json .}}' 2>/dev/null \
    | jq -s '[.[] | {
        id: .ID,
        name: .Names,
        image: .Image,
        status: .Status,
        ports: .Ports
    }]' 2>/dev/null) || unhealthy_containers="[]"

# Assemble final JSON
jq -n \
    --argjson running "${containers_running}" \
    --argjson stopped "${containers_stopped}" \
    --argjson images "${images}" \
    --argjson disk_usage "${disk_usage}" \
    --argjson unhealthy "${unhealthy_containers}" \
    '{
        containers_running: $running,
        containers_stopped: $stopped,
        images: $images,
        disk_usage: $disk_usage,
        unhealthy_containers: $unhealthy
    }'
