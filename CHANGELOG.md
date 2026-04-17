# Changelog

All notable changes to OTTO will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-17

### Added

#### Core Framework
- CLAUDE.md plugin definition for Claude Code integration
- `otto` CLI entry point with 15+ commands (status, agents, check, detect, watch, morning, turbo, tasks, config, permissions, help)
- Configuration system with YAML profiles: beginner, balanced, autonomous, paranoid, team-default
- Permission system with granular deny/suggest/confirm/auto per domain and environment
- State management with JSON state file and JSONL structured logging
- Task management with markdown files and YAML frontmatter (triage/todo/in-progress/done/failed/cancelled)
- Adaptive heartbeat/loop system with active/normal/idle/turbo/night modes
- Interactive installation wizard with tool auto-detection
- `.claude-plugin` marketplace integration

#### Agent System (62 agent definitions)
- 4 core agents: orchestrator (Opus), planner, communicator, learner
- 7 generic agents: reviewer, troubleshooter, generator, executor, auditor, reporter, watcher
- 12 specialist agents: infra, cicd, containers, monitor, security, database, code, project, server-admin, webserver, networking, backup
- 37 data source definitions (Grafana, Prometheus, Loki, Zabbix, Datadog, GitLab, GitHub, Jira, Slack, Telegram, Kubernetes, Docker, Terraform, Ansible, AWS, GCP, Azure, Vault, Wazuh, and more)
- Custom agent support: drop-in `.md` files in `~/.config/otto/agents/` or `agents/custom/`

#### Night Watcher
- Overnight monitoring with configurable check intervals
- Morning report generation (brief/detailed/executive formats)
- Alert aggregation and deduplication engine
- Auto-remediation engine (restart crashed pods, clear disk space, rotate logs)
- Critical alert escalation with cooldown
- Schedule-based auto-start/stop

#### Intelligence Layer
- Cost analyzer for AWS, GCP, and Azure
- Compliance checker (K8s pods, Docker images, Terraform state, SSL, backups)
- Trend analyzer with anomaly detection and exhaustion prediction
- Knowledge engine with contextual search across 34 knowledge base files

#### Data Collection (20 fetch scripts)
- Infrastructure: kubernetes, docker, terraform, ansible, server-health, systemd-services
- Cloud: cloud-aws, cloud-gcp, cloud-azure
- Monitoring: grafana, prometheus
- Security: ssl-certs, security-events, vault
- Networking: dns-check, nginx
- Backup: backup-status, restic
- Code: github, gitlab

#### Actions (7 action scripts)
- deploy (kubectl/helm/argocd with auto-detection)
- rollback (kubectl/helm/argocd)
- scale (kubectl/AWS ASG)
- restart-service (systemctl/docker/kubectl, local and remote via SSH)
- backup-create (restic/borg/velero/pg_dump/mysqldump)
- cert-renew (certbot/cert-manager)
- incident-create (with Slack/Telegram/Jira/Grafana notifications)

#### Communication
- Multi-channel support: Slack, Telegram, RocketChat, MS Teams, Discord, Email
- Message templates: Slack Block Kit (5), Telegram MarkdownV2 (3), HTML Email (2)

#### Knowledge Base (34 files)
- Best practices: Kubernetes, Terraform, Docker, CI/CD, Security, Monitoring, Backup, Ansible, Networking, Git
- Troubleshooting: Kubernetes, Terraform, Docker, Networking, SSL/TLS, Database, Ansible, CI/CD pipelines, nginx, DNS
- Runbooks: Incident response, Deployment rollback, Database recovery, Certificate renewal, Disk space cleanup, SSL renewal, K8s node recovery
- Patterns: High availability, Blue-green deploy, Canary deploy, GitOps workflow, Zero-downtime migration, Disaster recovery, Infrastructure testing

#### Team Features
- Team configuration with shared config via Git
- Role-based access control (admin/engineer/viewer/junior)
- On-call integration (schedule, PagerDuty, OpsGenie)
- Shared knowledge base sync
- Audit logging with search and export
- Team dashboard

#### Adaptive UX
- Experience level detection (beginner/intermediate/advanced/expert/auto)
- Interactive onboarding wizard
- Context-aware knowledge suggestions

#### CI/CD
- GitHub Actions: ShellCheck, BATS tests, Markdown lint
- Release automation with tag-based releases
- Issue templates: bug report, feature request, integration request
- Pull request template with checklist
