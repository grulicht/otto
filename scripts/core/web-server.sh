#!/usr/bin/env bash
# OTTO - Simple Status Page Web Server
# Serves the OTTO dashboard and public status pages via a lightweight HTTP server
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_WEBSERVER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_WEBSERVER_LOADED=1

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

# State directory and PID file
OTTO_STATE_DIR="${OTTO_HOME}/state"
WEBSERVER_PID_FILE="${OTTO_STATE_DIR}/webserver.pid"
WEBSERVER_DEFAULT_PORT=8484

# --- Public API ---

# Start simple HTTP server serving state/dashboard.html
# Uses python3 http.server or busybox httpd as fallback.
#   $1 - Port number (default: 8484)
webserver_start() {
    local port="${1:-${WEBSERVER_DEFAULT_PORT}}"
    local serve_dir="${OTTO_STATE_DIR}"

    mkdir -p "${serve_dir}"

    # Check if already running
    if webserver_status --quiet 2>/dev/null; then
        log_warn "Web server is already running (PID $(cat "${WEBSERVER_PID_FILE}"))."
        return 1
    fi

    # Ensure we have something to serve
    if [[ ! -f "${serve_dir}/dashboard.html" ]]; then
        log_warn "No dashboard.html found. Generating placeholder."
        _webserver_generate_placeholder "${serve_dir}/dashboard.html"
    fi

    # Try python3 first, then busybox httpd
    if command -v python3 &>/dev/null; then
        log_info "Starting HTTP server on port ${port} (python3)..."
        (cd "${serve_dir}" && python3 -m http.server "${port}" --bind 127.0.0.1 &>/dev/null) &
        local pid=$!
    elif command -v busybox &>/dev/null && busybox --list 2>/dev/null | grep -q httpd; then
        log_info "Starting HTTP server on port ${port} (busybox httpd)..."
        busybox httpd -p "127.0.0.1:${port}" -h "${serve_dir}" -f &
        local pid=$!
    else
        log_error "No suitable HTTP server found. Install python3 or busybox."
        return 1
    fi

    echo "${pid}" > "${WEBSERVER_PID_FILE}"
    log_info "Web server started on http://127.0.0.1:${port} (PID ${pid})"
    log_info "Serving files from: ${serve_dir}"
}

# Stop the web server
webserver_stop() {
    if [[ ! -f "${WEBSERVER_PID_FILE}" ]]; then
        log_info "No web server PID file found. Server may not be running."
        return 0
    fi

    local pid
    pid=$(cat "${WEBSERVER_PID_FILE}")

    if kill -0 "${pid}" 2>/dev/null; then
        log_info "Stopping web server (PID ${pid})..."
        kill "${pid}" 2>/dev/null || true
        # Wait briefly for graceful shutdown
        local i=0
        while kill -0 "${pid}" 2>/dev/null && [[ ${i} -lt 10 ]]; do
            sleep 0.5
            i=$((i + 1))
        done
        # Force kill if still running
        if kill -0 "${pid}" 2>/dev/null; then
            kill -9 "${pid}" 2>/dev/null || true
        fi
        log_info "Web server stopped."
    else
        log_info "Web server process (PID ${pid}) is not running."
    fi

    rm -f "${WEBSERVER_PID_FILE}"
}

# Check if server is running
#   --quiet: suppress output, just return exit code
webserver_status() {
    local quiet=false
    [[ "${1:-}" == "--quiet" ]] && quiet=true

    if [[ ! -f "${WEBSERVER_PID_FILE}" ]]; then
        ${quiet} || log_info "Web server is not running (no PID file)."
        return 1
    fi

    local pid
    pid=$(cat "${WEBSERVER_PID_FILE}")

    if kill -0 "${pid}" 2>/dev/null; then
        ${quiet} || log_info "Web server is running (PID ${pid})."
        return 0
    else
        ${quiet} || log_info "Web server is not running (stale PID file)."
        rm -f "${WEBSERVER_PID_FILE}"
        return 1
    fi
}

# Generate dashboard then serve it
#   $1 - Port number (default: 8484)
webserver_generate_and_serve() {
    local port="${1:-${WEBSERVER_DEFAULT_PORT}}"

    log_info "Generating dashboard..."
    _webserver_generate_dashboard

    webserver_start "${port}"
}

# Generate minimal public status page (no sensitive data)
# Output: state/public-status.html
webserver_public_status_page() {
    local output_file="${OTTO_STATE_DIR}/public-status.html"
    local state_file="${OTTO_STATE_DIR}/state.json"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    mkdir -p "${OTTO_STATE_DIR}"

    # Read basic status from state.json if available
    local overall_status="unknown"
    local last_check="N/A"
    if [[ -f "${state_file}" ]]; then
        overall_status=$(json_get "${state_file}" ".status" "unknown")
        last_check=$(json_get "${state_file}" ".last_heartbeat" "N/A")
    fi

    local status_color="gray"
    case "${overall_status}" in
        healthy|ok|green) status_color="#22c55e" ;;
        warning|degraded|yellow) status_color="#eab308" ;;
        critical|error|red) status_color="#ef4444" ;;
        *) status_color="#9ca3af" ;;
    esac

    cat > "${output_file}" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OTTO - System Status</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; display: flex; flex-direction: column; align-items: center; padding: 2rem; }
        .header { text-align: center; margin-bottom: 2rem; }
        .header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
        .header p { color: #94a3b8; }
        .status-card { background: #1e293b; border-radius: 12px; padding: 2rem; text-align: center; min-width: 320px; }
        .status-indicator { width: 16px; height: 16px; border-radius: 50%; display: inline-block; margin-right: 8px; }
        .status-text { font-size: 1.5rem; font-weight: 600; }
        .meta { margin-top: 1rem; color: #94a3b8; font-size: 0.875rem; }
        .footer { margin-top: 2rem; color: #475569; font-size: 0.75rem; }
    </style>
</head>
<body>
    <div class="header">
        <h1>System Status</h1>
        <p>OTTO DevOps Monitor</p>
    </div>
    <div class="status-card">
        <span class="status-indicator" style="background: ${status_color};"></span>
        <span class="status-text">${overall_status^}</span>
        <div class="meta">Last checked: ${last_check}</div>
    </div>
    <div class="footer">Generated: ${timestamp}</div>
</body>
</html>
HTMLEOF

    log_info "Public status page generated: ${output_file}"
}

# --- Internal helpers ---

_webserver_generate_placeholder() {
    local file="$1"
    cat > "${file}" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>OTTO Dashboard</title>
    <style>
        body { font-family: sans-serif; background: #0f172a; color: #e2e8f0; display: flex; justify-content: center; align-items: center; height: 100vh; }
        .msg { text-align: center; }
        h1 { margin-bottom: 1rem; }
    </style>
</head>
<body>
    <div class="msg">
        <h1>OTTO Dashboard</h1>
        <p>Run <code>otto morning</code> or <code>otto status</code> to generate dashboard data.</p>
    </div>
</body>
</html>
HTMLEOF
}

_webserver_generate_dashboard() {
    local state_file="${OTTO_STATE_DIR}/state.json"
    local output_file="${OTTO_STATE_DIR}/dashboard.html"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    mkdir -p "${OTTO_STATE_DIR}"

    # Gather state data
    local status="unknown"
    local last_heartbeat="N/A"
    local active_tasks=0
    if [[ -f "${state_file}" ]]; then
        status=$(json_get "${state_file}" ".status" "unknown")
        last_heartbeat=$(json_get "${state_file}" ".last_heartbeat" "N/A")
    fi

    # Count tasks
    for dir in "${OTTO_STATE_DIR}/tasks/todo" "${OTTO_STATE_DIR}/tasks/in-progress"; do
        if [[ -d "${dir}" ]]; then
            active_tasks=$((active_tasks + $(ls "${dir}" 2>/dev/null | wc -l)))
        fi
    done

    cat > "${output_file}" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="60">
    <title>OTTO Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; max-width: 1200px; margin: 0 auto; }
        .card { background: #1e293b; border-radius: 12px; padding: 1.5rem; }
        .card h3 { color: #94a3b8; font-size: 0.875rem; text-transform: uppercase; margin-bottom: 0.5rem; }
        .card .value { font-size: 2rem; font-weight: 700; }
        .header { text-align: center; margin-bottom: 2rem; }
        .header h1 { font-size: 2rem; }
        .header .subtitle { color: #94a3b8; }
        .footer { text-align: center; color: #475569; font-size: 0.75rem; margin-top: 2rem; }
    </style>
</head>
<body>
    <div class="header">
        <h1>OTTO Dashboard</h1>
        <p class="subtitle">Operations & Technology Toolchain Orchestrator</p>
    </div>
    <div class="grid">
        <div class="card">
            <h3>System Status</h3>
            <div class="value">${status^}</div>
        </div>
        <div class="card">
            <h3>Last Heartbeat</h3>
            <div class="value" style="font-size:1rem;">${last_heartbeat}</div>
        </div>
        <div class="card">
            <h3>Active Tasks</h3>
            <div class="value">${active_tasks}</div>
        </div>
        <div class="card">
            <h3>Dashboard Generated</h3>
            <div class="value" style="font-size:1rem;">${timestamp}</div>
        </div>
    </div>
    <div class="footer">Auto-refreshes every 60 seconds</div>
</body>
</html>
HTMLEOF

    log_info "Dashboard generated: ${output_file}"
}

# --- CLI entrypoint ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    action="${1:-help}"
    shift || true

    case "${action}" in
        start)    webserver_start "$@" ;;
        stop)     webserver_stop ;;
        status)   webserver_status ;;
        serve)    webserver_generate_and_serve "$@" ;;
        public)   webserver_public_status_page ;;
        help|*)
            cat <<EOF
Usage: $(basename "$0") <action> [arguments]

Actions:
    start [port]    Start HTTP server (default port: ${WEBSERVER_DEFAULT_PORT})
    stop            Stop the HTTP server
    status          Check if server is running
    serve [port]    Generate dashboard and start server
    public          Generate public status page
    help            Show this help
EOF
            ;;
    esac
fi
