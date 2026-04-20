# Advanced Features Overview

This document covers OTTO's advanced and experimental features. For each feature, you'll find what it does, how to use it, and relevant commands.

## Dashboard (HTML + Terminal)

**Maturity: Beta (HTML) / Experimental (Terminal)**

### HTML Dashboard

The HTML dashboard generates a self-contained status page at `~/.config/otto/state/dashboard.html`.

```bash
source scripts/core/dashboard.sh
# Generate the dashboard (collects system metrics automatically)
dashboard_generate

# View it
open ~/.config/otto/state/dashboard.html    # macOS
xdg-open ~/.config/otto/state/dashboard.html # Linux
```

The dashboard collects CPU, RAM, and disk metrics using `mpstat` (if available) or `/proc/stat`. It also pulls Kubernetes status, service health, and recent incidents.

To serve the dashboard over HTTP, use the web server (see below).

### Terminal Dashboard

The terminal dashboard renders colored status displays with box-drawing characters directly in your terminal.

```bash
source scripts/core/terminal-dashboard.sh

# Draw a status box
tui_box "System Health" "CPU: 45%  RAM: 62%  Disk: 38%"

# Draw a separator
tui_separator

# Draw a table
tui_table "Service|Status|Uptime" "nginx|UP|45d" "postgres|UP|12d"
```

Adapts to terminal dimensions automatically (`$COLUMNS` x `$LINES`).

## Postmortem Generator

**Maturity: Beta**

Auto-generates postmortem documents from incident data, audit logs, and task history.

```bash
source scripts/core/postmortem.sh

# Generate a postmortem for an incident
postmortem_generate "INC-20260417-001"
```

The generator:
1. Finds the incident task across all status directories (triage, todo, in-progress, done, failed, cancelled)
2. Collects related audit log entries from `~/.config/otto/state/audit.jsonl`
3. Fills in the postmortem template from `knowledge/patterns/postmortem-template.md`
4. Saves to `~/.config/otto/state/postmortems/`

Output is a Markdown document with timeline, impact, root cause, and action items sections.

## Runbook Executor

**Maturity: Experimental**

Interactively executes runbooks step by step. Runbooks are Markdown files with structured steps.

```bash
source scripts/core/runbook-executor.sh

# List available runbooks
runbook_list

# Execute a runbook
runbook_execute "database-failover"
```

Runbook directories searched (in order):
1. `<otto-dir>/knowledge/runbooks/`
2. `~/.config/otto/knowledge/runbooks/`

Plugins can add runbooks to the second directory.

## Scheduler

**Maturity: Beta**

Provides cron-like scheduled checks. OTTO evaluates a 5-field cron expression (minute, hour, day-of-month, month, day-of-week) to determine when checks should run.

```bash
source scripts/core/scheduler.sh

# Add a scheduled check
scheduler_add "kubernetes-health" "*/15 * * * *"    # Every 15 minutes
scheduler_add "disk-check" "0 */6 * * *"             # Every 6 hours
scheduler_add "compliance-audit" "0 9 * * 1"         # Monday at 9:00

# List scheduled checks
scheduler_list

# Remove a scheduled check
scheduler_remove "disk-check"

# Run due checks (call this from heartbeat or cron)
scheduler_run_due
```

State is stored in `~/.config/otto/state/scheduler.json`. Supports `*`, specific numbers, `*/N` (every N), and comma-separated lists.

## Change Tracker

**Maturity: Beta**

Takes snapshots of system state and computes diffs between them to detect infrastructure drift.

```bash
source scripts/core/change-tracker.sh

# Take a snapshot of current state
changes_snapshot

# Compare current state to the last snapshot
changes_diff

# List stored snapshots
changes_list_snapshots
```

Snapshots capture:
- System metrics (CPU, RAM, disk usage)
- Kubernetes resources (pods, deployments, services)
- Docker containers
- Network configuration
- Running processes

Snapshots are stored as JSON in `~/.config/otto/state/snapshots/`. The diff output highlights what changed between snapshots, helping you detect unexpected infrastructure drift.

## Offline Mode

**Maturity: Experimental**

Caches fetch results locally and queues notifications for later delivery when the network is unavailable.

```bash
source scripts/core/offline-cache.sh

# Save data to cache
cache_save "kubernetes-status" '{"pods": 12, "healthy": true}'

# Retrieve cached data
cache_get "kubernetes-status"

# Check if online
cache_is_online

# Queue a notification for later
cache_queue_notification '{"channel": "slack", "message": "Alert resolved"}'

# Flush queued notifications (call when back online)
cache_flush_queue
```

Cache is stored in `~/.config/otto/state/cache/`. The notification queue is in `~/.config/otto/state/notification-queue.jsonl`.

## Multi-Cluster Management

**Maturity: Experimental**

Manage multiple Kubernetes clusters and cloud contexts from a single interface.

```bash
source scripts/core/multi-cluster.sh

# List all configured Kubernetes contexts
cluster_list

# Get health status across all clusters
cluster_health_all

# Run a command against a specific context
cluster_exec "production-us-east" "kubectl get pods -A"

# Compare resource usage across clusters
cluster_compare
```

Uses your existing kubeconfig contexts. The current context is marked in the listing. Each function switches context, runs the operation, and switches back.

## Capacity Planner

**Maturity: Experimental**

Predicts resource exhaustion dates using trend analysis on historical metrics.

```bash
source scripts/core/capacity-planner.sh

# Predict when a disk will be full
capacity_disk_prediction /
capacity_disk_prediction /var/lib/docker

# Predict memory exhaustion
capacity_memory_prediction

# Get overall capacity report
capacity_report
```

The planner reads historical data from `~/.config/otto/state/disk-*.json` and uses the trend analyzer to project when usage will reach 100%. The more historical data points available, the more accurate the prediction.

## Anomaly Detector

**Maturity: Experimental**

Statistical anomaly detection using multiple algorithms. Analyzes numeric data series to find outliers.

```bash
source scripts/core/anomaly-detector.sh

# Z-score detection (flag points > N standard deviations from mean)
anomaly_detect_zscore '[10, 12, 11, 13, 50, 12, 11]' 3

# MAD (Median Absolute Deviation) - robust to outliers
anomaly_detect_mad '[10, 12, 11, 13, 50, 12, 11]' 3

# IQR (Interquartile Range)
anomaly_detect_iqr '[10, 12, 11, 13, 50, 12, 11]' 1.5

# Seasonal detection (for periodic patterns)
anomaly_detect_seasonal '[10, 12, 11, 10, 12, 50, 10, 12, 11]' 3 3
```

### Algorithm Details

| Algorithm | Best For | How It Works |
|-----------|----------|-------------|
| **Z-score** | Normally distributed data | Flags points more than N standard deviations from the mean |
| **MAD** | Data with existing outliers | Uses median instead of mean, more robust than Z-score |
| **IQR** | Non-normal distributions | Uses quartile range, flags points beyond Q1 - 1.5*IQR or Q3 + 1.5*IQR |
| **Seasonal** | Periodic metrics (daily/weekly patterns) | Compares each point to the same position in previous periods |

Output is a JSON object with the detected anomalies, statistical parameters, and indices of anomalous points. Baselines are stored in `~/.config/otto/state/baselines/`.

## Web Server

**Maturity: Experimental**

A simple HTTP server that serves the OTTO dashboard and status page.

```bash
source scripts/core/web-server.sh

# Start on default port (8484)
webserver_start

# Start on custom port
webserver_start 9090

# Stop the server
webserver_stop

# Check if running
webserver_status
```

Uses `python3 -m http.server` or `busybox httpd` as fallback. Serves files from `~/.config/otto/state/`, primarily `dashboard.html`.

The PID file is stored at `~/.config/otto/state/webserver.pid`. The server is intended for local or internal network use only -- it has no authentication or HTTPS support.

Access the dashboard at `http://localhost:8484/dashboard.html` after starting.
