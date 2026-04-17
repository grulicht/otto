# OTTO

**Operations & Technology Toolchain Orchestrator**

AI-powered DevOps assistant built as a [Claude Code](https://code.claude.com) plugin. OTTO works as an experienced DevOps engineer by your side - managing infrastructure, CI/CD pipelines, monitoring, security, databases, and more.

## Features

- **16 specialized agents** covering all DevOps domains (IaC, CI/CD, containers, monitoring, security, databases, networking, backup, and more)
- **7 generic agents** for universal tasks (review, troubleshoot, generate, execute, audit, report, watch)
- **Custom agents** - drop in your own `.md` agent files without modifying the plugin
- **100+ tool integrations** across 15+ domains (Terraform, Ansible, Kubernetes, Docker, Grafana, Prometheus, AWS, GCP, Azure, and many more)
- **Night Watcher** - overnight monitoring with morning reports
- **Configurable autonomy** - granular permission system (deny/suggest/confirm/auto) per domain and environment
- **Multi-channel communication** - Slack, Telegram, RocketChat, MS Teams, Discord, Email
- **Knowledge engine** - built-in best practices, troubleshooting guides, and runbook automation
- **Adaptive experience** - adjusts behavior from beginner-friendly explanations to expert-level terse mode

## Quick Start

### Prerequisites

- [Claude Code](https://code.claude.com) CLI installed
- `jq` and `yq` available in PATH

### Installation

```bash
# Clone the repository
git clone https://github.com/grulicht/otto.git

# Run the setup wizard
cd otto
./install.sh
```

The setup wizard will:
1. Detect your installed DevOps tools (kubectl, terraform, ansible, docker, etc.)
2. Let you choose a permission profile (beginner, balanced, autonomous, paranoid)
3. Configure your communication channels
4. Create your personal configuration

### First Run

```bash
# Start OTTO
otto

# Or use specific commands
otto setup          # Re-run setup wizard
otto morning        # Get morning briefing
otto watch          # Start Night Watcher mode
otto status         # System health overview
```

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

### Custom Agents

Add your own agents by placing `.md` files in `~/.config/otto/agents/` or in the `agents/custom/` directory. See [agents/custom/README.md](agents/custom/README.md) for the template and instructions.

## Permission Profiles

| Profile | Description | Best For |
|---------|-------------|----------|
| `beginner` | Explains everything, always asks before acting | Learning DevOps |
| `balanced` | Read operations auto, writes need confirmation | Daily DevOps work |
| `autonomous` | Maximum automation, minimal confirmations | Dev environments |
| `paranoid` | Everything requires explicit approval | Production systems |

## Night Watcher

OTTO can monitor your systems overnight and deliver a morning report:

```bash
otto watch    # Start Night Watcher
otto morning  # Get the morning report
```

The morning report includes:
- System health overview
- Alert summary and trends
- Deployment and pipeline status
- Security events
- Action items prioritized by urgency

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

- Grafana
- Prometheus
- Loki
- Mimir
- Grafana Alloy
- Zabbix
- Datadog
- ELK Stack (Elasticsearch, Logstash, Kibana)
- New Relic
- StatusPage
</details>

<details>
<summary><b>Security</b></summary>

- HashiCorp Vault
- Trivy
- Snyk
- SonarQube
- SOPS / Sealed Secrets
- Falco
- cert-manager
- OWASP ZAP
- Wazuh
</details>

<details>
<summary><b>Databases</b></summary>

- PostgreSQL
- MySQL / MariaDB
- MongoDB
- Redis
- ClickHouse
- Elasticsearch
</details>

<details>
<summary><b>Communication</b></summary>

- Slack
- Telegram
- RocketChat
- Microsoft Teams
- Discord
- Email (SMTP/Gmail)
</details>

<details>
<summary><b>Project Management</b></summary>

- Jira / Confluence
- Linear
- Trello
- Asana
- Notion
- Redmine
</details>

<details>
<summary><b>Networking & Web</b></summary>

- nginx / Apache / Caddy / Traefik
- DNS (Cloudflare, Route53, BIND, PowerDNS)
- SSL/TLS (Let's Encrypt, cert-manager, OpenSSL)
- VPN (WireGuard, OpenVPN)
- SSH / SCP / FTP / SFTP / Rsync
- Mail (Postfix, Dovecot, DKIM/SPF/DMARC)
- Firewalls (iptables, nftables, UFW)
- Service Mesh (Istio, Linkerd)
</details>

<details>
<summary><b>Backup</b></summary>

- Restic
- BorgBackup
- Velero (Kubernetes)
- Database-specific (pg_dump, mysqldump, mongodump)
- Cloud backups (AWS Backup, GCP Snapshots, Azure Backup)
</details>

<details>
<summary><b>Server Administration</b></summary>

- Linux (systemd, package management, cron)
- macOS (Homebrew, launchd)
- Windows (PowerShell, IIS, Active Directory)
</details>

## Configuration

OTTO uses YAML configuration with sensible defaults:

```yaml
# ~/.config/otto/config.yaml
user:
  experience_level: auto    # beginner | intermediate | advanced | expert | auto
  role: devops_engineer

permissions:
  default_mode: balanced    # beginner | balanced | autonomous | paranoid
  environments:
    production:
      default: suggest
      destructive: deny

communication:
  primary: slack
  channels:
    slack:
      enabled: true
      bot_token: ${OTTO_SLACK_TOKEN}

night_watcher:
  enabled: true
  schedule:
    start: "22:00"
    end: "07:00"
    timezone: "Europe/Prague"
```

See [docs/configuration.md](docs/configuration.md) for the full reference.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

## License

[MIT](LICENSE)
