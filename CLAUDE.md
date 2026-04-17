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

## Configuration

- Default config: `config/default.yaml`
- User config: `~/.config/otto/config.yaml`
- Profiles: `config/profiles/` (beginner, balanced, autonomous, paranoid)
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

Agent files are Markdown with YAML frontmatter defining metadata, triggers, and tools.

## Key Scripts

- `otto` - CLI entry point
- `scripts/core/setup.sh` - interactive setup wizard
- `scripts/core/heartbeat.sh` - adaptive heartbeat/loop management
- `scripts/core/permissions.sh` - permission checking
- `scripts/core/config.sh` - configuration loading and validation
- `scripts/core/state.sh` - state management
- `scripts/core/night-watcher.sh` - Night Watcher mode
- `scripts/core/morning-report.sh` - morning report generation
- `scripts/lib/` - shared library functions

## Communication

OTTO supports multiple communication channels: Slack, Telegram, RocketChat,
MS Teams, Discord, and Email. The communicator agent handles message formatting
and delivery. Templates are in `scripts/templates/`.

Only the orchestrator (via communicator) sends external messages.
Specialist agents output to stdout; the orchestrator collects and routes.

## Night Watcher

When activated (`otto watch`), OTTO monitors systems overnight:
- Checks all configured integrations on a 15-30 minute interval
- Escalates critical alerts immediately (if configured)
- Generates a comprehensive morning report on wakeup
- Configuration in `night_watcher` section of config.yaml

## State Management

Runtime state is stored in `~/.config/otto/state/`:
- `state.json` - current system state
- `log.jsonl` - structured action log
- `tasks/` - task queue (triage/todo/in-progress/done/failed/cancelled)
- `memory/` - persistent knowledge base
- `night-watch/` - night watcher reports

## Development

- Shell scripts: `set -euo pipefail`, shellcheck-compliant
- Tests: BATS framework in `tests/`
- CI: GitHub Actions (shellcheck + BATS + markdown lint)
- No external runtime dependencies beyond bash, jq, yq, curl

## Commands

```
otto              # Start interactive mode
otto setup        # Run setup wizard
otto morning      # Get morning briefing
otto watch        # Start Night Watcher
otto status       # System health overview
otto task <desc>  # Create a new task
otto config       # Show current configuration
otto agents       # List available agents
otto help         # Show help
```
