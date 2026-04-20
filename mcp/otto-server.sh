#!/usr/bin/env bash
# OTTO - MCP (Model Context Protocol) Server
# Reads JSON-RPC requests from stdin, dispatches to OTTO CLI commands,
# returns JSON-RPC responses on stdout.
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OTTO_CLI="${OTTO_DIR}/otto"
MCP_CONFIG="${OTTO_DIR}/mcp/mcp-config.json"

# Source required libraries
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"

# Log to stderr so stdout stays clean for JSON-RPC
_mcp_log() {
    echo "[otto-mcp] $*" >&2
}

# Build a JSON-RPC success response
_mcp_response() {
    local id="$1"
    local result="$2"
    jq -n --argjson id "${id}" --argjson result "${result}" \
        '{"jsonrpc": "2.0", "id": $id, "result": $result}'
}

# Build a JSON-RPC error response
_mcp_error() {
    local id="$1"
    local code="$2"
    local message="$3"
    jq -n --argjson id "${id}" --arg code "${code}" --arg message "${message}" \
        '{"jsonrpc": "2.0", "id": $id, "error": {"code": ($code | tonumber), "message": $message}}'
}

# Execute an OTTO command and capture output
_mcp_exec() {
    local cmd="$1"
    shift
    local output
    if output=$("${OTTO_CLI}" "${cmd}" "$@" 2>&1); then
        jq -n --arg output "${output}" '{"status": "success", "output": $output}'
    else
        local exit_code=$?
        jq -n --arg output "${output}" --arg code "${exit_code}" \
            '{"status": "error", "exit_code": ($code | tonumber), "output": $output}'
    fi
}

# Handle initialize method
_handle_initialize() {
    local id="$1"
    local server_info
    server_info=$(jq -n '{
        "protocolVersion": "2024-11-05",
        "capabilities": {
            "tools": {}
        },
        "serverInfo": {
            "name": "otto-devops",
            "version": "1.0.0"
        }
    }')
    _mcp_response "${id}" "${server_info}"
}

# Handle tools/list method
_handle_tools_list() {
    local id="$1"

    if [[ -f "${MCP_CONFIG}" ]]; then
        local tools
        tools=$(jq '{tools: [.tools[] | {
            name: .name,
            description: .description,
            inputSchema: {
                type: "object",
                properties: (if .parameters then (.parameters | to_entries | map({key: .key, value: {type: .value}}) | from_entries) else {} end)
            }
        }]}' "${MCP_CONFIG}")
        _mcp_response "${id}" "${tools}"
    else
        _mcp_response "${id}" '{"tools": []}'
    fi
}

# Handle tools/call method
_handle_tools_call() {
    local id="$1"
    local tool_name="$2"
    local arguments="$3"

    local result
    case "${tool_name}" in
        otto_check)
            local target
            target=$(echo "${arguments}" | jq -r '.target // ""')
            result=$(_mcp_exec "check" ${target:+--target "${target}"})
            ;;
        otto_status)
            result=$(_mcp_exec "status")
            ;;
        otto_deploy)
            local target environment version
            target=$(echo "${arguments}" | jq -r '.target // ""')
            environment=$(echo "${arguments}" | jq -r '.environment // ""')
            version=$(echo "${arguments}" | jq -r '.version // ""')
            result=$(_mcp_exec "deploy" --target "${target}" --environment "${environment}" --version "${version}")
            ;;
        otto_rollback)
            local target environment
            target=$(echo "${arguments}" | jq -r '.target // ""')
            environment=$(echo "${arguments}" | jq -r '.environment // ""')
            result=$(_mcp_exec "rollback" --target "${target}" --environment "${environment}")
            ;;
        otto_incident)
            local title severity
            title=$(echo "${arguments}" | jq -r '.title // ""')
            severity=$(echo "${arguments}" | jq -r '.severity // ""')
            result=$(_mcp_exec "incident" --title "${title}" --severity "${severity}")
            ;;
        otto_knowledge)
            local query
            query=$(echo "${arguments}" | jq -r '.query // ""')
            result=$(_mcp_exec "knowledge" --query "${query}")
            ;;
        otto_compliance)
            result=$(_mcp_exec "compliance")
            ;;
        otto_morning)
            result=$(_mcp_exec "morning")
            ;;
        *)
            _mcp_error "${id}" "-32601" "Unknown tool: ${tool_name}"
            return
            ;;
    esac

    local content
    content=$(jq -n --argjson result "${result}" '{content: [{type: "text", text: ($result | tostring)}]}')
    _mcp_response "${id}" "${content}"
}

# Main loop: read JSON-RPC from stdin, dispatch, respond on stdout
_mcp_main() {
    _mcp_log "OTTO MCP Server starting..."
    _mcp_log "Reading JSON-RPC from stdin..."

    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "${line}" ]] && continue

        # Parse the JSON-RPC request
        local method id params
        method=$(echo "${line}" | jq -r '.method // ""' 2>/dev/null)
        id=$(echo "${line}" | jq '.id // null' 2>/dev/null)
        params=$(echo "${line}" | jq '.params // {}' 2>/dev/null)

        if [[ -z "${method}" ]]; then
            if [[ "${id}" != "null" ]]; then
                _mcp_error "${id}" "-32600" "Invalid request: missing method"
            fi
            continue
        fi

        _mcp_log "Received: method=${method} id=${id}"

        case "${method}" in
            initialize)
                _handle_initialize "${id}"
                ;;
            initialized)
                # Notification, no response needed
                _mcp_log "Client initialized."
                ;;
            tools/list)
                _handle_tools_list "${id}"
                ;;
            tools/call)
                local tool_name arguments
                tool_name=$(echo "${params}" | jq -r '.name // ""')
                arguments=$(echo "${params}" | jq '.arguments // {}')
                _handle_tools_call "${id}" "${tool_name}" "${arguments}"
                ;;
            notifications/*)
                # Notifications don't require responses
                _mcp_log "Notification: ${method}"
                ;;
            *)
                if [[ "${id}" != "null" ]]; then
                    _mcp_error "${id}" "-32601" "Method not found: ${method}"
                fi
                ;;
        esac
    done

    _mcp_log "OTTO MCP Server shutting down."
}

# Run the server
_mcp_main
