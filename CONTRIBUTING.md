# Contributing to OTTO

Thank you for your interest in contributing to OTTO! This guide will help you get started.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/grulicht/otto/issues) first
2. Use the **Bug Report** issue template
3. Include: OTTO version, OS, Claude Code version, steps to reproduce

### Suggesting Features

1. Check [existing issues](https://github.com/grulicht/otto/issues) for similar requests
2. Use the **Feature Request** issue template
3. Describe the use case, not just the solution

### Adding Integrations

OTTO is designed to support many DevOps tools. To request or contribute a new integration:

1. Use the **Integration Request** issue template
2. Include: tool name, what operations OTTO should support, relevant APIs/CLIs

### Submitting Code

1. Fork the repository
2. Create a feature branch from `main`: `git checkout -b feature/my-feature`
3. Make your changes following the guidelines below
4. Run tests: `./tests/run.sh`
5. Run shellcheck: `shellcheck scripts/**/*.sh`
6. Commit with a clear message
7. Push and open a Pull Request

## Development Guidelines

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Always include `set -euo pipefail`
- Pass [shellcheck](https://www.shellcheck.net/) without warnings
- Use functions for reusable logic
- Quote all variables: `"${var}"` not `$var`
- Use `[[ ]]` instead of `[ ]` for conditionals
- Add error handling for external commands

### Agent Definitions

Agent markdown files follow this structure:

```markdown
---
name: agent-name
description: What this agent does
type: core | generic | specialist
domain: infra | cicd | containers | monitoring | security | database | code | ...
model: opus | sonnet | haiku
triggers:
  - keyword or pattern that activates this agent
tools:
  - list of CLI tools this agent uses
---

# Agent Name

## Role
What this agent is responsible for.

## Capabilities
What this agent can do.

## Instructions
How this agent should behave.
```

### Configuration

- Use YAML for user-facing configuration
- Use JSON for internal state
- Always provide sensible defaults
- Document every config option

### Tests

- Write BATS tests for all scripts in `scripts/lib/` and `scripts/core/`
- Place unit tests in `tests/unit/`
- Place integration tests in `tests/integration/`
- Use fixtures from `tests/fixtures/`

### Commit Messages

Follow conventional commits:

```
feat: add Zabbix integration
fix: handle empty Prometheus response
docs: update Night Watcher configuration guide
test: add BATS tests for permission system
chore: update shellcheck to v0.10
```

## Creating Custom Agents

See [agents/custom/README.md](agents/custom/README.md) for a complete guide on creating custom agents.

## Project Structure

```
otto/
├── agents/           # Agent definitions (markdown)
│   ├── core/         # Core agents (orchestrator, planner, communicator, learner)
│   ├── generic/      # Generic agents (reviewer, troubleshooter, generator, ...)
│   ├── specialists/  # Domain-specific agents (infra, cicd, containers, ...)
│   ├── sources/      # Data source definitions
│   └── custom/       # User custom agents + template
├── config/           # Default configuration and profiles
├── scripts/          # Bash scripts (core, fetch, actions, lib)
├── knowledge/        # Built-in knowledge base
├── tests/            # BATS test suite
└── docs/             # Documentation
```

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
