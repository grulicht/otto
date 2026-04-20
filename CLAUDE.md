# OTTO - Operations & Technology Toolchain Orchestrator

OTTO is an AI DevOps assistant that operates as a Claude Code plugin.
It functions as an experienced DevOps engineer - managing infrastructure,
CI/CD, monitoring, security, databases, servers, networking, and more.

## Architecture

OTTO uses a layered agent system:

- **Core agents** (always active): orchestrator, planner, communicator, learner
- **Generic agents** (universal patterns): reviewer, troubleshooter, generator, executor, auditor, reporter, watcher
- **Specialist agents** (domain experts): infra, cicd, containers, monitor, security, database, code, project, server-admin, webserver, networking, backup
- **Custom agents** (user-defined): loaded from `~/.config/otto/agents/` and `agents/custom/`

## Feature Maturity

Features are classified by stability:

- **Stable** - Production-ready, fully tested
  Core agents, permission system, heartbeat, Night Watcher, fetch scripts,
  knowledge engine, config system, task management, CLI

- **Beta** - Functional, needs more testing
  Alert routing, ChatOps, dashboard, postmortem generator, scheduler,
  change tracker, compliance checker, team features, audit log

- **Experimental** - Working but early stage, may change
  Chaos engineering, IaC scaffolding, terminal dashboard, MCP server,
  multi-cluster orchestration, capacity planner, anomaly detector,
  web server, plugin system

## Skills (Slash Commands)

OTTO provides these Claude Code skills:

- `/otto:status` - System health overview
- `/otto:morning` - Morning briefing
- `/otto:watch` - Activate Night Watcher
- `/otto:check [target]` - Run health checks
- `/otto:deploy [target] [env] [version]` - Guided deployment
- `/otto:incident [title]` - Create incident
- `/otto:review` - DevOps-focused code review
- `/otto:troubleshoot [symptom]` - Systematic troubleshooting
- `/otto:knowledge [topic]` - Search knowledge base
- `/otto:compliance` - Run compliance audit

## Configuration

- Default config: `config/default.yaml`
- User config: `~/.config/otto/config.yaml`
- Profiles: `config/profiles/` (beginner, balanced, autonomous, paranoid, team-default)
- Policies: `config/policies.yaml` (compliance-as-code rules)
- Secrets: `~/.config/otto/.env` (never committed)

## Permission System

Every action has a permission level based on the user's configuration:
- `deny` - action is forbidden
- `suggest` - OTTO proposes the action and waits for approval
- `confirm` - OTTO asks "Proceed? [Y/n]" before executing
- `auto` - OTTO executes automatically and reports back

Permissions are configured per domain, per action type, and per environment.
Always check permissions via `scripts/core/permissions.sh` before taking any action.
Production environments should default to `suggest` or `confirm`.

## Agent Loading

The orchestrator loads agents from these directories in order:
1. `agents/core/` - always loaded
2. `agents/generic/` - always loaded
3. `agents/specialists/` - loaded based on detected tools
4. `agents/custom/` - always loaded if present
5. `~/.config/otto/agents/` - user custom agents, always loaded if present
6. `~/.config/otto/plugins/*/agents/` - plugin agents

Agent files are Markdown with YAML frontmatter defining metadata, triggers, and tools.

## Key Scripts

### Core
- `otto` - CLI entry point
- `scripts/core/config.sh` - configuration loading and validation
- `scripts/core/state.sh` - state management
- `scripts/core/permissions.sh` - permission checking
- `scripts/core/heartbeat.sh` - adaptive heartbeat/loop management
- `scripts/core/night-watcher.sh` - Night Watcher mode
- `scripts/core/morning-report.sh` - morning report generation
- `scripts/core/onboarding.sh` - interactive setup wizard

### Intelligence
- `scripts/core/alert-aggregator.sh` - alert aggregation and correlation
- `scripts/core/auto-remediation.sh` - automatic remediation engine
- `scripts/core/cost-analyzer.sh` - cloud cost intelligence
- `scripts/core/compliance-checker.sh` - compliance and security audit
- `scripts/core/compliance-engine.sh` - compliance-as-code policy evaluation
- `scripts/core/trend-analyzer.sh` - trend analysis and prediction
- `scripts/core/anomaly-detector.sh` - statistical anomaly detection
- `scripts/core/knowledge-engine.sh` - contextual knowledge search
- `scripts/core/change-tracker.sh` - diff/change tracking between checks
- `scripts/core/capacity-planner.sh` - capacity planning and prediction
- `scripts/core/postmortem.sh` - auto-generate postmortem documents
- `scripts/core/dashboard.sh` - HTML and terminal dashboard generation

### Communication & UX
- `scripts/core/adaptive-ux.sh` - experience level adaptation
- `scripts/core/alert-router.sh` - rule-based alert routing
- `scripts/core/chatops.sh` - bidirectional Slack/Telegram commands
- `scripts/core/terminal-dashboard.sh` - rich terminal UI
- `scripts/core/incident-memory.sh` - incident context tracking
- `scripts/core/offline-cache.sh` - offline mode with queue

### Team & Collaboration
- `scripts/core/team.sh` - team management
- `scripts/core/role-based.sh` - role-based access control
- `scripts/core/audit-log.sh` - audit trail

### Advanced
- `scripts/core/plugin-manager.sh` - plugin system
- `scripts/core/scheduler.sh` - scheduled checks (cron-like)
- `scripts/core/runbook-executor.sh` - interactive runbook execution
- `scripts/core/doc-generator.sh` - auto-generate infrastructure docs
- `scripts/core/multi-cluster.sh` - multi-cluster/multi-cloud orchestration
- `scripts/core/chaos-assistant.sh` - chaos engineering experiments
- `scripts/core/iac-assistant.sh` - IaC scaffolding and pair programming
- `scripts/core/web-server.sh` - simple status page HTTP server

### Libraries
- `scripts/lib/colors.sh` - terminal colors
- `scripts/lib/logging.sh` - structured logging
- `scripts/lib/error-handling.sh` - error handling framework
- `scripts/lib/json-utils.sh` - jq wrappers
- `scripts/lib/yaml-utils.sh` - yq wrappers
- `scripts/lib/platform-detect.sh` - tool detection
- `scripts/lib/version.sh` - version management
- `scripts/lib/i18n.sh` - internationalization
- `scripts/lib/state-lock.sh` - file locking
- `scripts/lib/log-rotate.sh` - log rotation
- `scripts/lib/config-schema.sh` - config validation

## Communication

OTTO supports multiple communication channels: Slack, Telegram, RocketChat,
MS Teams, Discord, and Email. The communicator agent handles message formatting
and delivery. Templates are in `scripts/templates/`.

Alert routing rules can direct alerts to different channels based on severity,
domain, and environment. ChatOps mode enables bidirectional commands via Slack/Telegram.

## Night Watcher

When activated (`otto watch`), OTTO monitors systems overnight:
- Checks all configured integrations on a 15-30 minute interval
- Aggregates and deduplicates alerts from multiple sources
- Escalates critical alerts immediately (with cooldown)
- Auto-remediates within configured boundaries
- Generates comprehensive morning report with trends
- Configuration in `night_watcher` section of config.yaml

## Plugin System

Install community or custom plugins:
```
otto plugin install <git-url>
otto plugin list
otto plugin update
```
See `docs/plugin-development.md` for creating plugins.

## MCP Server

OTTO can run as an MCP server, exposing DevOps tools to other AI assistants.
Config in `mcp/mcp-config.json`.

## State Management

Runtime state is stored in `~/.config/otto/state/`:
- `state.json` - current system state
- `log.jsonl` - structured action log
- `audit.jsonl` - audit trail
- `tasks/` - task queue
- `memory/` - persistent knowledge base
- `night-watch/` - night watcher reports
- `incidents/` - incident context memory
- `snapshots/` - change tracking snapshots
- `cache/` - offline cache
- `baselines/` - anomaly detection baselines
- `scheduler.json` - scheduled check state

## Development

- Shell scripts: `set -euo pipefail`, shellcheck-compliant
- Tests: BATS framework in `tests/`
- CI: GitHub Actions (shellcheck + BATS + markdown lint)
- No external runtime dependencies beyond bash, jq, yq, curl
- Multi-language support via `scripts/lib/i18n.sh`

## Claude Code Skills

OTTO provides Claude Code skills (slash commands) in the `skills/` directory:

- `/otto:status` - System health overview
- `/otto:morning` - Morning briefing from Night Watcher data
- `/otto:watch` - Activate Night Watcher mode
- `/otto:check [target]` - Run health checks
- `/otto:deploy [target] [env] [version]` - Guided deployment
- `/otto:incident [title]` - Create and track an incident
- `/otto:review` - Review changes with DevOps lens
- `/otto:troubleshoot [symptom]` - Systematic troubleshooting
- `/otto:knowledge [topic]` - Search knowledge base
- `/otto:compliance` - Run compliance audit with score

## Commands

```
otto                    # Show help
otto setup              # Run setup wizard
otto status             # System health overview
otto morning            # Get morning briefing
otto watch / unwatch    # Night Watcher on/off
otto turbo              # Turbo mode (1-min checks)
otto check [target]     # Run health checks
otto detect             # Detect installed tools
otto task <desc>        # Create task
otto tasks [status]     # List tasks
otto config [set k v]   # Configuration
otto agents             # List agents
otto permissions        # Permission summary
otto heartbeat          # Heartbeat status
otto version / help     # Info
```
