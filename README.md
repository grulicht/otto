# OTTO

**Operations & Technology Toolchain Orchestrator**

AI-powered DevOps assistant built as a [Claude Code](https://code.claude.com) plugin. OTTO works as an experienced DevOps engineer by your side - managing infrastructure, CI/CD pipelines, monitoring, security, databases, and more.

## Why OTTO?

DevOps is complex. You juggle dozens of tools, hundreds of configs, and thousands of things that can break at 3 AM. OTTO changes that.

**OTTO is like having a senior DevOps engineer available 24/7** - one who knows Terraform AND Ansible AND Kubernetes AND your monitoring stack AND your CI/CD pipelines AND never forgets a runbook.

### What makes OTTO different

- **Not just another chatbot.** OTTO doesn't just answer questions - it monitors your systems, detects anomalies, runs compliance checks, and wakes you up only when something actually needs your attention.
- **Works with YOUR tools.** 100+ integrations across every DevOps domain. OTTO auto-detects what you have installed and adapts.
- **You control the autonomy.** From "explain everything and ask before doing anything" to "just fix it and tell me later" - configurable per tool, per environment, per action.
- **Learns your workflow.** OTTO adapts to your experience level, remembers your preferences, and builds a knowledge base specific to your infrastructure.

## Who is OTTO for?

### DevOps beginners
You're learning DevOps and don't want to pay for an expert? OTTO explains every command before running it, suggests best practices, warns about common mistakes, and teaches as it works. Set it to `beginner` profile and learn by doing.

```
You: "My Kubernetes pod keeps crashing"
OTTO: Checks pod status, reads logs, identifies OOMKilled, explains what it means,
      suggests increasing memory limits, shows the exact kubectl command, and asks
      before making any changes.
```

### Solo DevOps engineers
You're the only DevOps person on the team? OTTO is your force multiplier. Night Watcher monitors everything while you sleep, morning reports tell you what needs attention, and 63 knowledge base files mean you never have to Google "how to rotate SSL certificates" again.

### DevOps teams
Shared configuration via Git, role-based access control, on-call integration with PagerDuty/OpsGenie, team knowledge base, and audit logging. Everyone gets the same tooling, same best practices, same runbooks.

### DevOps architects & experts
Skip the explanations, get straight to the action. Expert mode gives terse output, advanced optimizations, compliance-as-code policies, multi-cluster orchestration, capacity planning, and anomaly detection. OTTO handles the routine so you can focus on architecture.

## Real-World Use Cases

### Morning routine
```bash
otto morning
```
> "Good morning. Overnight: 2 alerts resolved automatically (pod restart, disk cleanup).
> 1 alert needs attention: SSL certificate for api.example.com expires in 12 days.
> All deployments stable. Database backup completed at 03:00.
> Action items: Renew SSL cert (high), review Terraform plan for staging (medium)."

### Incident response
```bash
/otto:incident "API latency spike in production"
```
OTTO creates an incident task, checks Grafana for metrics, queries Prometheus for error rates, reviews recent deployments, searches knowledge base for similar incidents, and suggests remediation steps - all before you finish your coffee.

### Deployment with safety net
```bash
/otto:deploy api-service production v2.5.0
```
OTTO checks permissions (production = confirm mode), runs pre-deploy health checks, shows the deployment plan, waits for your approval, deploys via Helm, monitors rollout status, and rolls back automatically if health checks fail.

### Overnight monitoring
```bash
otto watch
```
OTTO switches to Night Watcher mode: checks every 15 minutes, aggregates alerts, auto-remediates within boundaries (restart crashed pods, clean temp files), escalates critical issues via Slack/Telegram, and generates a detailed morning report.

### Infrastructure review
```bash
/otto:compliance
```
OTTO scans your Kubernetes pods (root containers? missing resource limits?), Docker images (vulnerabilities?), Terraform state (unencrypted storage? public S3?), SSL certificates (expiring soon?), and backups (too old?) - generates a compliance score with specific fixes.

### Troubleshooting
```bash
/otto:troubleshoot "pods in CrashLoopBackOff"
```
OTTO follows a systematic diagnostic: checks pod logs, describes events, reviews resource limits, checks image pull status, examines health probes, searches the knowledge base for matching patterns, and suggests the most likely fix.

### Cost optimization
```bash
otto check cloud-aws
```
OTTO queries AWS Cost Explorer, identifies unused EC2 instances, orphaned EBS volumes, idle RDS databases, and suggests right-sizing - with estimated monthly savings.

See [docs/advanced-features.md](docs/advanced-features.md) for the full list of capabilities.

## Features

- **23 specialized agents** (4 core + 7 generic + 12 specialist) covering all DevOps domains
- **49 data fetch scripts** for real-time monitoring of infrastructure, cloud, CI/CD, databases, and more
- **63 knowledge base files** with best practices, troubleshooting guides, runbooks, and patterns
- **10 Claude Code skills** (`/otto:status`, `/otto:deploy`, `/otto:troubleshoot`, and more)
- **Night Watcher** - overnight monitoring with morning reports, alert aggregation, and auto-remediation
- **Configurable autonomy** - granular permission system (deny/suggest/confirm/auto) per domain and environment
- **Multi-channel communication** - Slack, Telegram, RocketChat, MS Teams, Discord, Email with alert routing
- **ChatOps** - bidirectional commands via Slack and Telegram
- **Knowledge engine** - contextual search across best practices, troubleshooting, runbooks, and patterns
- **Intelligence layer** - anomaly detection, trend analysis, capacity planning, cost optimization, compliance-as-code
- **Dashboard** - HTML dark-theme status page and terminal ASCII dashboard
- **Plugin system** - install community or custom plugins from git repos
- **MCP server** - expose OTTO tools to other AI assistants
- **Team features** - RBAC, on-call integration, shared knowledge, audit logging
- **Chaos engineering** - controlled experiments for resilience testing
- **IaC scaffolding** - generate Terraform, Ansible, Helm, Dockerfile, CI/CD, K8s templates with best practices
- **Custom agents** - drop in your own `.md` agent files without modifying the plugin
- **Adaptive UX** - from beginner-friendly explanations to expert-level terse mode
- **Multi-language** - English and Czech (extensible)

See [docs/feature-maturity.md](docs/feature-maturity.md) for stability levels of each feature.

## Quick Start

### Prerequisites

- [Claude Code](https://code.claude.com) CLI installed
- `jq` and `yq` available in PATH

### Option 1: Claude Code Plugin (recommended)

```bash
# Add OTTO marketplace and install the plugin
claude plugin marketplace add https://github.com/grulicht/otto
claude plugin install otto@otto
```

### Option 2: Manual Installation

```bash
# Clone the repository
git clone https://github.com/grulicht/otto.git
cd otto
./install.sh
```

The setup wizard will:
1. Detect your installed DevOps tools (kubectl, terraform, ansible, docker, etc.)
2. Let you choose a permission profile (beginner, balanced, autonomous, paranoid)
3. Configure your communication channels
4. Create your personal configuration

### First Commands

```bash
otto help               # See all commands
otto agents             # List 23 available agents
otto detect             # See what tools OTTO found
otto status             # System health overview
otto check all          # Run all health checks
otto morning            # Get morning briefing
otto watch              # Start Night Watcher
```

### Claude Code Skills (Slash Commands)

Inside Claude Code, use these skills for guided workflows:

| Skill | What it does |
|-------|-------------|
| `/otto:status` | System health overview with colored indicators |
| `/otto:morning` | Morning briefing from Night Watcher data |
| `/otto:check [target]` | Run health checks (kubernetes, docker, ssl-certs, ...) |
| `/otto:deploy [app] [env] [ver]` | Guided deployment with safety checks |
| `/otto:troubleshoot [symptom]` | Systematic problem diagnosis |
| `/otto:incident [title]` | Create incident with notifications |
| `/otto:review` | DevOps-focused review of current changes |
| `/otto:compliance` | Security and compliance audit with score |
| `/otto:knowledge [topic]` | Search the knowledge base |
| `/otto:watch` | Activate Night Watcher mode |

## Agent Architecture

OTTO uses a layered agent system:

```
Core Agents          Generic Agents         Specialist Agents
(always active)      (universal patterns)   (domain experts)

orchestrator         reviewer               infra (Terraform, Ansible, Cloud)
planner              troubleshooter         cicd (GitLab CI, GitHub Actions, Jenkins)
communicator         generator              containers (K8s, Docker, Helm)
learner              executor               monitor (Grafana, Prometheus, Zabbix)
                     auditor                security (Vault, Trivy, Wazuh)
                     reporter               database (PostgreSQL, MySQL, MongoDB)
                     watcher                code (Git, scripting)
                                            project (Jira, Linear, Notion)
                                            server-admin (Linux, Windows, macOS)
                                            webserver (nginx, Apache, Caddy)
                                            networking (DNS, VPN, SSL/TLS)
                                            backup (Restic, Borg, Velero)
```

**Custom agents**: drop `.md` files into `~/.config/otto/agents/` - OTTO discovers them automatically. See [agents/custom/README.md](agents/custom/README.md).

**Plugins**: install community extensions with `otto plugin install <git-url>`. See [docs/plugins.md](docs/plugins.md).

## Permission Profiles

OTTO never does anything you haven't authorized. Choose your comfort level:

| Profile | Read | Write | Destroy | Best For |
|---------|------|-------|---------|----------|
| `beginner` | ask | ask | deny | Learning DevOps |
| `balanced` | auto | confirm | deny | Daily work |
| `autonomous` | auto | auto | confirm | Dev environments |
| `paranoid` | confirm | suggest | deny | Production |
| `team-default` | auto | confirm | deny | Team setup |

Permissions are granular: different for Kubernetes vs. Terraform vs. databases, different for dev vs. staging vs. production. See [docs/configuration.md](docs/configuration.md).

## Night Watcher

Your infrastructure doesn't sleep. Neither does OTTO.

```bash
otto watch    # Start Night Watcher
otto morning  # Get the morning report
```

Night Watcher:
- Checks all systems every 15 minutes overnight
- Aggregates and deduplicates alerts from all sources
- Auto-remediates within safe boundaries (restart pods, clean disk, rotate logs)
- Escalates critical issues to Slack/Telegram immediately
- Generates a morning report with trends and action items

See [docs/night-watcher.md](docs/night-watcher.md) for configuration.

## Knowledge Base

OTTO ships with **63 knowledge files** covering:

| Category | Files | Topics |
|----------|-------|--------|
| Best Practices | 16 | Kubernetes, Terraform, Docker, CI/CD, Security, Monitoring, Backup, Ansible, Git, Redis, PostgreSQL, nginx, Linux hardening, IaC workflows, Networking, Project management |
| Troubleshooting | 23 | Common issues for K8s, Terraform, Docker, nginx, DNS, SSL/TLS, databases, Ansible, CI/CD, cloud providers, backup failures, IaC, Git, security, server admin, containers, web servers, project management |
| Runbooks | 9 | Incident response, deployment rollback, database recovery, certificate renewal, disk cleanup, SSL renewal, K8s node recovery, pod troubleshooting, scaling response |
| Patterns | 15 | High availability, blue-green, canary, GitOps, zero-downtime migration, disaster recovery, infrastructure testing, postmortem, zero trust, observability, 12-factor app, microservices, event-driven, secrets management, CI/CD design |

Search the knowledge base: `/otto:knowledge kubernetes best practices`

## Supported Integrations

<details>
<summary><b>Infrastructure as Code</b></summary>

- Terraform / OpenTofu
- Ansible
</details>

<details>
<summary><b>CI/CD</b></summary>

- GitLab CI
- GitHub Actions
- Jenkins
- ArgoCD
- Bitbucket Pipelines
- Azure DevOps Pipelines
</details>

<details>
<summary><b>Containers & Orchestration</b></summary>

- Docker / Docker Compose
- Kubernetes
- Helm
- Podman
- K3s / K0s
- Portainer
- KubeSolo
</details>

<details>
<summary><b>Cloud & Virtualization</b></summary>

- AWS
- Google Cloud Platform
- Microsoft Azure
- DigitalOcean
- Hetzner
- Hyper-V
- Proxmox VE
- XCP-ng
</details>

<details>
<summary><b>Monitoring & Observability</b></summary>

- Grafana, Prometheus, Loki, Mimir, Grafana Alloy
- Zabbix, Datadog, ELK Stack, New Relic, StatusPage
</details>

<details>
<summary><b>Security</b></summary>

- HashiCorp Vault, Trivy, Snyk, SonarQube
- SOPS, Sealed Secrets, Falco, cert-manager, OWASP ZAP, Wazuh
</details>

<details>
<summary><b>Databases</b></summary>

- PostgreSQL, MySQL/MariaDB, MongoDB, Redis, ClickHouse, Elasticsearch
</details>

<details>
<summary><b>Communication</b></summary>

- Slack, Telegram, RocketChat, Microsoft Teams, Discord, Email
</details>

<details>
<summary><b>Project Management</b></summary>

- Jira, Confluence, Linear, Trello, Asana, Notion, Redmine
</details>

<details>
<summary><b>Networking & Web</b></summary>

- nginx, Apache, Caddy, Traefik
- DNS (Cloudflare, Route53, BIND, PowerDNS)
- SSL/TLS, VPN (WireGuard, OpenVPN), Firewalls, Service Mesh (Istio, Linkerd)
- SSH, SCP, FTP, SFTP, Rsync, Mail (Postfix, Dovecot, DKIM/SPF/DMARC)
</details>

<details>
<summary><b>Backup & Server Admin</b></summary>

- Restic, BorgBackup, Velero, pg_dump, mysqldump, Cloud backups
- Linux (systemd, cron), macOS (Homebrew), Windows (PowerShell, IIS, AD)
</details>

## Configuration

```yaml
# ~/.config/otto/config.yaml
user:
  experience_level: auto
  role: devops_engineer

permissions:
  default_mode: balanced
  environments:
    production:
      default: suggest
      destructive: deny

communication:
  primary: slack

night_watcher:
  enabled: true
  schedule:
    start: "22:00"
    end: "07:00"
    timezone: "Europe/Prague"
```

See [docs/configuration.md](docs/configuration.md) for all options.

## Documentation

| Guide | Description |
|-------|-------------|
| [Complete Setup Guide](docs/complete-setup-guide.md) | Full walkthrough from install to testing |
| [Getting Started](docs/getting-started.md) | Quick installation and first steps |
| [Configuration](docs/configuration.md) | All config options |
| [Agents](docs/agents.md) | Agent system architecture |
| [Night Watcher](docs/night-watcher.md) | Overnight monitoring setup |
| [Permissions](docs/configuration.md#permissions) | Permission system details |
| [Plugins](docs/plugins.md) | Plugin system and development |
| [MCP Server](docs/mcp-server.md) | OTTO as MCP server |
| [Chaos Engineering](docs/chaos-engineering.md) | Resilience testing |
| [IaC Scaffolding](docs/iac-scaffolding.md) | Generate infrastructure templates |
| [Advanced Features](docs/advanced-features.md) | Dashboard, postmortem, scheduler, anomaly detection, ... |
| [Feature Maturity](docs/feature-maturity.md) | Stability levels (stable/beta/experimental) |
| [Examples](docs/examples/) | Setup guides for beginners, teams, enterprises |

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

## License

[MIT](LICENSE)
