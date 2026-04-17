# Custom Agents

Create your own OTTO agents by adding `.md` files to this directory or to `~/.config/otto/agents/`.

## Quick Start

1. Copy `_template.md` to a new file: `cp _template.md my-agent.md`
2. Edit the YAML frontmatter (name, description, triggers, tools)
3. Write the agent instructions in Markdown
4. OTTO will automatically discover and load your agent

## Agent File Format

Each agent is a Markdown file with YAML frontmatter:

```markdown
---
name: my-agent
description: What this agent does
type: custom
domain: general
model: sonnet
triggers:
  - keywords that activate this agent
tools:
  - cli-tools-it-uses
requires:
  - tools-that-must-be-installed
---

# Agent Name

## Role
...

## Capabilities
...

## Instructions
...
```

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique agent identifier (lowercase, hyphens) |
| `description` | Yes | One-line description |
| `type` | Yes | Always `custom` for custom agents |
| `domain` | No | Domain category (infra, cicd, monitoring, etc.) |
| `model` | No | Preferred Claude model (haiku/sonnet/opus, default: sonnet) |
| `triggers` | Yes | Keywords/phrases that activate this agent |
| `tools` | No | CLI tools this agent uses |
| `requires` | No | Tools that must be installed (agent skipped if missing) |

## Agent Locations

OTTO loads custom agents from two directories:

1. **Plugin directory:** `agents/custom/` (shipped with OTTO, version controlled)
2. **User directory:** `~/.config/otto/agents/` (personal, not version controlled)

User agents take precedence over plugin agents with the same name.

## Examples

### Company-Specific Deployment Agent

```markdown
---
name: deploy-myapp
description: Deploy our company application to Kubernetes
type: custom
domain: cicd
model: sonnet
triggers:
  - deploy myapp
  - release myapp
tools:
  - kubectl
  - helm
requires:
  - kubectl
  - helm
---

# MyApp Deployment Agent

## Role
Handles deployment of MyApp to our Kubernetes clusters.

## Instructions
1. Check current deployment status: kubectl get deployments -n myapp
2. Verify Helm chart values in ./helm/myapp/values.yaml
3. Run helm upgrade with appropriate values
4. Verify pods are running and healthy
5. Report deployment status
```

### Custom Monitoring Check

```markdown
---
name: check-endpoints
description: Check health of our critical API endpoints
type: custom
domain: monitoring
model: haiku
triggers:
  - check endpoints
  - api health
tools:
  - curl
requires:
  - curl
---

# Endpoint Health Checker

## Role
Checks health of critical API endpoints and reports status.

## Instructions
1. Read endpoint list from ~/.config/otto/endpoints.yaml
2. Curl each endpoint and check HTTP status
3. Report any endpoints returning non-200 status
4. Measure and report response times
```
