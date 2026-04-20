# Plugin System Guide

OTTO's plugin system lets you extend functionality with custom agents, fetch scripts, action scripts, and knowledge files. Plugins can be shared via git repositories or installed from local directories.

> **Maturity: Experimental** - The plugin system works but may see API changes.

## What Plugins Can Do

A plugin can add any combination of:

- **Agents** - New specialist agents with custom triggers and tool requirements
- **Fetch scripts** - Data collection from new sources (APIs, services, tools)
- **Action scripts** - New executable actions (deployments, restarts, configuration changes)
- **Knowledge files** - Reference documents, runbooks, and patterns
- **Source definitions** - New data source configurations

## Plugin Directory Structure

```
my-plugin/
  plugin.yaml           # Required: plugin metadata
  agents/               # Optional: agent definitions (.md with YAML frontmatter)
  sources/              # Optional: source definitions
  scripts/
    fetch/              # Optional: data gathering scripts
    actions/            # Optional: executable action scripts
  knowledge/            # Optional: reference docs, runbooks, patterns
```

## plugin.yaml Reference

Every plugin must have a `plugin.yaml` at its root. Here is a complete example with all fields:

```yaml
# Required fields
name: my-monitoring-plugin
version: 1.2.0

# Optional fields
description: Adds custom monitoring checks for MyService
author: Jane Doe <jane@example.com>
type: monitoring        # general, monitoring, deploy, security, etc.
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique plugin name. Use lowercase with hyphens. |
| `version` | Yes | Semantic version (e.g., `1.0.0`). |
| `description` | No | Short description of the plugin's purpose. |
| `author` | No | Author name or email. |
| `type` | No | Category: `general`, `monitoring`, `deploy`, `security`, or any custom string. Defaults to `general`. |

## Creating a Plugin Step by Step

### 1. Create the directory structure

```bash
mkdir -p my-plugin/{agents,scripts/fetch,scripts/actions,knowledge}
```

### 2. Write plugin.yaml

```bash
cat > my-plugin/plugin.yaml << 'EOF'
name: myservice-monitor
version: 1.0.0
description: Monitor MyService health and manage deployments
author: Your Name
type: monitoring
EOF
```

### 3. Add a fetch script

Fetch scripts must be executable bash scripts that output JSON to stdout.

```bash
cat > my-plugin/scripts/fetch/myservice-health.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

MYSERVICE_URL="${MYSERVICE_URL:-http://localhost:8080}"

if ! response=$(curl -s --fail --max-time 10 "${MYSERVICE_URL}/health" 2>/dev/null); then
    echo '{"status": "unreachable", "healthy": false}'
    exit 0
fi

echo "${response}" | jq '{
    status: .status,
    healthy: (.status == "ok"),
    uptime: .uptime_seconds,
    version: .version
}'
SCRIPT
chmod +x my-plugin/scripts/fetch/myservice-health.sh
```

### 4. Add an agent

Agent files are Markdown with YAML frontmatter.

```bash
cat > my-plugin/agents/myservice-specialist.md << 'EOF'
---
name: myservice-specialist
description: Specialist agent for MyService monitoring and operations
triggers:
  - check myservice
  - myservice status
  - myservice deploy
tools:
  - curl
  - jq
---

You are a specialist agent for MyService. You can:

- Check service health using the myservice-health fetch script
- Analyze health trends and detect degradation
- Guide deployments with pre/post checks

When checking health, run the myservice-health fetch script and interpret the results.
Report uptime, version, and any anomalies.
EOF
```

### 5. Add knowledge files

```bash
cat > my-plugin/knowledge/myservice-runbook.md << 'EOF'
# MyService Troubleshooting Runbook

## Service won't start
1. Check logs: `journalctl -u myservice -n 50`
2. Verify config: `myservice validate-config`
3. Check port conflicts: `ss -tlnp | grep 8080`

## High latency
1. Check database connections: `myservice db-status`
2. Review recent deployments
3. Check resource usage: CPU, memory, disk I/O
EOF
```

### 6. Validate and install

```bash
# Validate structure
otto plugin validate ./my-plugin

# Install locally
otto plugin install ./my-plugin

# Verify installation
otto plugin info myservice-monitor
otto plugin list
```

## Installing Plugins

### From a git repository

```bash
otto plugin install https://github.com/user/otto-myservice-plugin.git
```

This clones the repository (shallow, depth 1) into `~/.config/otto/plugins/`.

### From a local directory

```bash
otto plugin install /path/to/my-plugin
```

This copies the directory into `~/.config/otto/plugins/`.

## Managing Plugins

### List installed plugins

```bash
otto plugin list
```

Output shows name, version, type, and description for each plugin.

### Update a specific plugin

```bash
otto plugin update myservice-monitor
```

Only works for git-installed plugins (runs `git pull --ff-only`).

### Update all plugins

```bash
otto plugin update
```

### Get plugin details

```bash
otto plugin info myservice-monitor
```

Shows version, type, author, description, contents, and git info.

### Uninstall a plugin

```bash
otto plugin uninstall myservice-monitor
```

Removes the plugin directory from `~/.config/otto/plugins/`.

## How Plugins Get Loaded

When OTTO starts, `plugin_load_all` processes each installed plugin:

1. Validates `plugin.yaml` (must have `name` and `version` fields)
2. Copies `agents/` files to `~/.config/otto/agents/`
3. Copies `sources/` files to `~/.config/otto/sources/`
4. Copies `knowledge/` files to `~/.config/otto/knowledge/`
5. Copies `scripts/fetch/` to `~/.config/otto/scripts/fetch/` and makes them executable
6. Copies `scripts/actions/` to `~/.config/otto/scripts/actions/` and makes them executable

The orchestrator then loads plugin agents from `~/.config/otto/plugins/*/agents/` (priority 6, after custom agents).

## Best Practices

- **Keep plugins focused.** One plugin per integration or domain. Don't bundle unrelated features.
- **Use semantic versioning.** Bump major version for breaking changes.
- **Test scripts independently.** Run fetch and action scripts outside OTTO to verify they work.
- **Don't hardcode paths.** Use `OTTO_DIR` and `OTTO_HOME` environment variables.
- **Make scripts shellcheck-compliant.** Follow the same `set -euo pipefail` pattern as OTTO core.
- **Handle missing tools gracefully.** Check for required commands and exit cleanly with empty JSON if unavailable.
- **Include a README** in your plugin root for human-readable documentation.
- **Output JSON from fetch scripts.** Always output valid JSON to stdout, even on failure (output an empty/default object).
