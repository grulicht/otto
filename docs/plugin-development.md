# OTTO Plugin Development Guide

This guide explains how to create plugins for OTTO.

## Plugin Structure

Every OTTO plugin must follow this directory structure:

```
my-plugin/
  plugin.yaml           # Required: Plugin metadata
  agents/               # Optional: Agent definitions (.md files)
  sources/              # Optional: Source definitions
  scripts/fetch/        # Optional: Fetch scripts
  scripts/actions/      # Optional: Action scripts
  knowledge/            # Optional: Knowledge files
```

## plugin.yaml (Required)

The `plugin.yaml` file is the only required file. It must contain at minimum:

```yaml
name: my-plugin
version: 1.0.0
description: Short description of what this plugin does
author: Your Name
type: general
```

### Fields

| Field         | Required | Description                                    |
|---------------|----------|------------------------------------------------|
| `name`        | Yes      | Unique plugin name (lowercase, hyphens allowed)|
| `version`     | Yes      | Semantic version (e.g. `1.0.0`)                |
| `description` | No       | Short description                              |
| `author`      | No       | Author name or email                           |
| `type`        | No       | Plugin type: `general`, `monitoring`, `deploy`, `security`, etc. |

## Adding Agents

Place agent definition files (Markdown with YAML frontmatter) in the `agents/` directory. These will be copied to `~/.config/otto/agents/` when the plugin is loaded.

Example `agents/my-checker.md`:

```markdown
---
name: my-checker
description: Checks my custom service
triggers:
  - check my-service
  - my-service status
tools:
  - curl
  - jq
---

You are a specialist agent that checks the health of My Custom Service...
```

## Adding Fetch Scripts

Fetch scripts in `scripts/fetch/` are executed during data gathering. They must:

- Be executable bash scripts
- Use `set -euo pipefail`
- Output results to stdout as JSON
- Exit 0 on success, non-zero on failure

Example `scripts/fetch/my-metrics.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
curl -s https://my-service.example.com/metrics | jq '{cpu: .cpu, memory: .memory}'
```

## Adding Action Scripts

Action scripts in `scripts/actions/` implement executable actions. They should:

- Accept `--dry-run` flag
- Check permissions via `permission_enforce`
- Output JSON results
- Follow the same patterns as built-in action scripts

## Adding Knowledge

Place any reference documents, runbooks, or knowledge base files in the `knowledge/` directory. These are copied to `~/.config/otto/knowledge/` and become available to the knowledge engine.

## Installing Your Plugin

### From a local directory

```bash
otto plugin install /path/to/my-plugin
```

### From a git repository

```bash
otto plugin install https://github.com/user/otto-my-plugin.git
```

## Testing Your Plugin

1. Validate structure:
   ```bash
   ./scripts/core/plugin-manager.sh validate /path/to/my-plugin
   ```

2. Install locally:
   ```bash
   ./scripts/core/plugin-manager.sh install /path/to/my-plugin
   ```

3. Load and verify:
   ```bash
   ./scripts/core/plugin-manager.sh load
   ./scripts/core/plugin-manager.sh info my-plugin
   ```

## Updating Your Plugin

If your plugin is installed from git, users can update with:

```bash
otto plugin update my-plugin
```

Or update all plugins:

```bash
otto plugin update
```

## Best Practices

- Keep plugins focused on a single domain or integration
- Include a README in your plugin root for documentation
- Use semantic versioning
- Test fetch and action scripts independently before packaging
- Avoid hardcoding paths; use environment variables (`OTTO_DIR`, `OTTO_HOME`)
- Make all scripts shellcheck-compliant
