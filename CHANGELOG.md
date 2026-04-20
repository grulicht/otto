# Changelog

All notable changes to OTTO will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-20

### Added

#### Core Framework
- CLAUDE.md plugin definition for Claude Code integration
- `otto` CLI entry point with 15+ commands
- Configuration system with YAML profiles: beginner, balanced, autonomous, paranoid, team-default
- Permission system with granular deny/suggest/confirm/auto per domain and environment
- State management with JSON state file and JSONL structured logging
- Task management with markdown files and YAML frontmatter
- Adaptive heartbeat/loop system with active/normal/idle/turbo/night modes
- Interactive onboarding wizard with tool auto-detection
- `.claude-plugin` marketplace integration
- Multi-language support (English, Czech)

#### Agent System (62 agent definitions)
- 4 core agents: orchestrator (Opus), planner, communicator, learner
- 7 generic agents: reviewer, troubleshooter, generator, executor, auditor, reporter, watcher
- 12 specialist agents: infra, cicd, containers, monitor, security, database, code, project, server-admin, webserver, networking, backup
- 37 data source definitions for all supported integrations
- Custom agent support with drop-in `.md` files

#### Skills (10 Claude Code slash commands)
- `/otto:status`, `/otto:morning`, `/otto:watch`, `/otto:check`
- `/otto:deploy`, `/otto:incident`, `/otto:review`
- `/otto:troubleshoot`, `/otto:knowledge`, `/otto:compliance`

#### Night Watcher
- Overnight monitoring with configurable check intervals
- Morning report generation (brief/detailed/executive)
- Alert aggregation, deduplication, and correlation engine
- Auto-remediation engine (pod restart, disk cleanup, log rotation)
- Critical alert escalation with cooldown
- Schedule-based auto-start/stop

#### Intelligence Layer
- Cost analyzer for AWS, GCP, and Azure
- Compliance checker (K8s, Docker, Terraform, SSL, backups)
- Compliance-as-code engine with policy definitions
- Trend analyzer with exhaustion prediction
- Statistical anomaly detection (Z-score, MAD, IQR, seasonal)
- Knowledge engine with contextual search across 48 knowledge files
- Change tracker (state snapshots and diff between checks)
- Capacity planner with resource exhaustion prediction
- Postmortem auto-generator from incident data
- Dashboard generator (HTML dark-theme + terminal ASCII)
- Scheduled checks with cron-like expressions

#### Data Collection (48 fetch scripts)
- Infrastructure: kubernetes, docker, terraform, ansible, server-health, systemd-services, nginx, proxmox
- Cloud: cloud-aws, cloud-gcp, cloud-azure, digitalocean, hetzner, cloud-digitalocean, cloud-hetzner
- Monitoring: grafana, prometheus, loki, mimir, alloy, zabbix, datadog, newrelic, elk, statuspage
- Communication: slack, telegram, rocketchat, teams, discord, email
- Project: jira, confluence, linear, bitbucket, github, gitlab
- Security: ssl-certs, security-events, vault, wazuh
- Networking: dns-check
- Backup: backup-status, restic, borg, velero
- Incident: pagerduty, opsgenie

#### Actions (8 action scripts)
- deploy (kubectl/helm/argocd with auto-detection)
- rollback (kubectl/helm/argocd)
- scale (kubectl/AWS ASG)
- restart-service (systemctl/docker/kubectl, local and remote via SSH)
- backup-create (restic/borg/velero/pg_dump/mysqldump)
- cert-renew (certbot/cert-manager)
- incident-create (Slack/Telegram/Jira/Grafana notifications)
- reconcile (terraform/kubernetes/ansible drift reconciliation)

#### Communication & ChatOps
- Multi-channel: Slack, Telegram, RocketChat, MS Teams, Discord, Email
- Message templates: Slack Block Kit (5), Telegram MarkdownV2 (3), HTML Email (2), Dashboard HTML (1)
- Alert routing rules (severity/domain/environment-based routing)
- Bidirectional ChatOps (Slack and Telegram command parsing)
- Offline mode with notification queue

#### Knowledge Base (48 files)
- Best practices (14): Kubernetes, Terraform, Docker, CI/CD, Security, Monitoring, Backup, Ansible, Networking, Git, Redis, PostgreSQL, nginx config, Linux hardening
- Troubleshooting (15): Kubernetes, Terraform, Docker, Networking, SSL/TLS, Database, Ansible, CI/CD, nginx, DNS, Redis, PostgreSQL, AWS, Cloud general, Backup failures
- Runbooks (9): Incident response, Deployment rollback, Database recovery, Certificate renewal, Disk space cleanup, SSL renewal, K8s node recovery, K8s pod troubleshooting, Scaling response
- Patterns (10): High availability, Blue-green, Canary, GitOps, Zero-downtime migration, Disaster recovery, Infrastructure testing, Postmortem template, Zero trust networking, Observability stack

#### Team Features
- Team configuration with shared config via Git
- Role-based access control (admin/engineer/viewer/junior)
- On-call integration (schedule, PagerDuty, OpsGenie)
- Shared knowledge base sync
- Audit logging with search, export, and compliance reports
- Incident context memory with similar incident search

#### Advanced Features
- Plugin system (install/uninstall/update from git repos)
- MCP server mode (expose OTTO tools to other AI assistants)
- Web server for HTML status page
- Multi-cluster/multi-cloud orchestration
- Chaos engineering assistant (pod-kill, network-delay, cpu-stress)
- IaC scaffolding (Terraform, Ansible, Helm, Dockerfile, CI/CD, K8s)
- Auto-generated infrastructure documentation

#### Libraries (11)
- colors, logging, error-handling, json-utils, yaml-utils
- platform-detect, version, i18n, state-lock, log-rotate, config-schema

#### Tests (16 BATS test files)
- Unit tests for: config, state, permissions, version, logging, json-utils, yaml-utils, platform-detect, error-handling, heartbeat, knowledge-engine, alert-aggregator, team, role-based, audit-log, compliance-checker

#### CI/CD
- GitHub Actions: ShellCheck, BATS tests, Markdown lint
- Release automation with tag-based releases
- Issue templates: bug report, feature request, integration request
- Pull request template with checklist
