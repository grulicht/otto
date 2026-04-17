# Agents

OTTO uses a layered agent system. Each agent is a Markdown file with YAML
frontmatter that defines its behavior, triggers, and capabilities.

## Agent Types

### Core Agents

Always active. Form the backbone of the system.

| Agent | Model | Role |
|-------|-------|------|
| **orchestrator** | Opus | Central brain - receives requests, delegates to specialists |
| **planner** | Sonnet | Task planning, prioritization, dependency management |
| **communicator** | Sonnet | Multi-channel messaging (Slack, Telegram, etc.) |
| **learner** | Sonnet | Knowledge base management, self-improvement |

### Generic Agents

Universal patterns that work across all DevOps domains.

| Agent | Model | Role |
|-------|-------|------|
| **reviewer** | Sonnet | Universal code/config/IaC review |
| **troubleshooter** | Opus | Systematic problem diagnosis |
| **generator** | Sonnet | Config/script/manifest generation |
| **executor** | Sonnet | Safe command execution with permission checks |
| **auditor** | Sonnet | Security, compliance, and best-practice auditing |
| **reporter** | Haiku | Report generation (health, cost, security) |
| **watcher** | Haiku | Change and anomaly monitoring |

### Specialist Agents

Domain-specific experts loaded based on detected tools.

| Agent | Domain | Key Tools |
|-------|--------|-----------|
| **infra** | Infrastructure | Terraform, Ansible, Cloud CLIs |
| **cicd** | CI/CD | GitLab CI, GitHub Actions, Jenkins, ArgoCD |
| **containers** | Containers | Docker, Kubernetes, Helm, Podman |
| **monitor** | Monitoring | Grafana, Prometheus, Zabbix, Datadog |
| **security** | Security | Vault, Trivy, Wazuh, cert-manager |
| **database** | Databases | PostgreSQL, MySQL, MongoDB, Redis |
| **code** | Code & Git | GitHub, GitLab, Bash, Python, Go |
| **project** | Project Mgmt | Jira, Confluence, Linear, Notion |
| **server-admin** | Servers | Linux, macOS, Windows, systemd |
| **webserver** | Web Servers | nginx, Apache, Caddy, Traefik |
| **networking** | Networking | DNS, SSL/TLS, VPN, firewalls, mail |
| **backup** | Backup | Restic, Borg, Velero |

### Custom Agents

User-defined agents loaded from:
- `agents/custom/` (shipped with plugin)
- `~/.config/otto/agents/` (user personal)

See [Custom Agent Guide](../agents/custom/README.md).

## How Agents Are Selected

1. User sends a request to OTTO
2. The **orchestrator** analyzes the request
3. Based on keywords, context, and detected tools, it selects the best agent
4. If the task is complex, the **planner** breaks it into subtasks
5. Each subtask is delegated to the appropriate agent
6. Results flow back through the orchestrator
7. The **communicator** formats and delivers the response

## Agent File Format

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the agent definition format.
