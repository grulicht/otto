# OTTO - Operations & Technology Toolchain Orchestrator
## Kompletni implementacni plan

**Typ:** Claude Code Plugin (AI DevOps Assistant)
**Licence:** MIT
**Repo:** GitHub
**Datum:** 2026-04-17
**Verze planu:** 1.0

---

## OBSAH

1. [Vize a cile](#1-vize-a-cile)
2. [Architektura](#2-architektura)
3. [Agent system](#3-agent-system)
4. [Kompletni mapa integraci](#4-kompletni-mapa-integraci)
5. [Permission system](#5-permission-system)
6. [Night Watcher](#6-night-watcher)
7. [Struktura projektu](#7-struktura-projektu)
8. [Implementacni faze](#8-implementacni-faze)
9. [GitHub repo setup](#9-github-repo-setup)
10. [Rizika a mitigace](#10-rizika-a-mitigace)

---

## 1. VIZE A CILE

### Vize
OTTO je AI DevOps assistant ve forme Claude Code pluginu, ktery funguje jako
zkuseny DevOps engineer po vasi strane. Umi vse co umi clovek na pozici
DevOps - od spravy infrastruktury, pres CI/CD, monitoring, security,
az po nocni hlldani systemu a ranni reporty.

### Cilova skupina
- **Zacatecnici** - lide co s DevOps zacinaji, nechteji/nemuzou platit experta
- **DevOps engineeri** - zrychleni a automatizace rutinnich uloh
- **DevOps architekti/experti** - pokrocile analyzy, druhy nazor, automatizace
- **DevOps tymy** - sdilena znalostni baze, team workflows
- **Firmy** - snizeni nakladu, konzistentni procesy

### Klicove diferenciatory oproti Kvido
1. **DevOps-first** - kazdy agent je DevOps specialista
2. **Univerzalni kompatibilita** - podporuje vsechny hlavni DevOps nastroje
3. **Konfigurovatelna autonomie** - granularni permission system
4. **Multi-audience** - adaptuje se na uroven uzivatele
5. **Night Watcher** - nocni monitoring s rannimi reporty
6. **Production-ready** - testovane, dokumentovane, bezpecne
7. **Multi-channel komunikace** - Slack, Telegram, RocketChat, Teams, Discord, Email
8. **DevOps Knowledge Engine** - vestevene best practices a troubleshooting

---

## 2. ARCHITEKTURA

### High-Level Overview

```
+------------------------------------------------------------------+
|                        Claude Code CLI                            |
|                     (runtime platforma)                           |
+------------------------------------------------------------------+
|                    OTTO Plugin vrstva                              |
|                                                                    |
|  +------------------+  +------------------+  +------------------+  |
|  |   Agent Layer    |  |  Script Layer    |  |  Config Layer    |  |
|  |                  |  |                  |  |                  |  |
|  |  Markdown agent  |  |  Bash skripty    |  |  YAML config     |  |
|  |  definice s      |  |  pro fetch,      |  |  + profily       |  |
|  |  YAML frontmatter|  |  actions, utils  |  |  + permissions   |  |
|  +------------------+  +------------------+  +------------------+  |
|                                                                    |
|  +------------------+  +------------------+  +------------------+  |
|  |  State Layer     |  | Knowledge Layer  |  | Template Layer   |  |
|  |  JSON state +    |  | Best practices,  |  | Message sablony  |  |
|  |  task queue      |  | runbooks, guides |  | pro vsechny      |  |
|  +------------------+  +------------------+  | kanaly           |  |
|                                              +------------------+  |
+------------------------------------------------------------------+
|                       MCP Servery                                  |
|  Grafana, Slack, Atlassian, Google Calendar, Gmail, ...           |
+------------------------------------------------------------------+
|                    Systemove nastroje                              |
|  kubectl, terraform, ansible, docker, git, aws, helm, ...        |
+------------------------------------------------------------------+
```

### Tech Stack
- **Runtime:** Claude Code CLI
- **Agenti:** Markdown + YAML frontmatter
- **Skripty:** Bash (set -euo pipefail, shellcheck-compliant)
- **Config:** YAML (user-facing) + JSON (interni stav)
- **Zavislosti:** jq, yq, curl (bezne dostupne)
- **Testy:** BATS (Bash Automated Testing System)
- **CI/CD:** GitHub Actions
- **Dokumentace:** Markdown

---

## 3. AGENT SYSTEM

### 3.1 Core Agents

#### Orchestrator (Opus)
- Hlavni mozek systemu
- Prijima uzivatelsle pozadavky a deleguje na specialisty
- Rozhoduje ktery agent je nejlepsi pro dany ukol
- Spravuje heartbeat/loop cyklus
- Koordinuje Night Watcher rezim

#### Planner
- Prioritizuje a planuje praci
- Rozkladá slozite ukoly na mensi tasky
- Spravuje task queue a dependency graph
- Rozhoduje o poradi vykonavani

#### Communicator
- Multi-channel komunikace (Slack, Telegram, RocketChat, Teams, Discord, Email)
- Message templating a formatting per kanal
- Morning briefing, evening summary, night reports
- Triage notifikace s emoji voting
- Thread management

#### Learner
- Spravuje knowledge base
- Self-improvement - analyzuje vzory a navrhuje zlepseni
- Uci se z uzivatelovych preferenci
- Udrzuje runbook databazi
- Archivuje a cistl stara data

### 3.2 Specialist Agents

#### Infrastructure Agent (Infra)
**Zodpovednost:** IaC, cloud provideri, virtualizace, servery
**Nastroje:**
- Terraform / OpenTofu: plan, apply, state, drift detection, moduly
- Ansible: playbook lint/run, inventory, role development, vault
- AWS: EC2, S3, RDS, Lambda, EKS, IAM, CloudWatch, Cost Explorer, VPC
- GCP: GKE, Cloud Run, BigQuery, IAM, Monitoring, Cloud Functions
- Azure: AKS, App Service, CosmosDB, AD, Monitor, Functions
- DigitalOcean: Droplets, DOKS, Spaces
- Hetzner: Server management, volumes, networks
- Hyper-V: VM management, snapshots, networking
- Proxmox VE: VM/CT management, clustering, storage, backup
- XCP-ng/XenServer: pool management, VM lifecycle

#### CI/CD Agent
**Zodpovednost:** Pipeline management, build/deploy automation
**Nastroje:**
- GitLab CI: pipeline debug, .gitlab-ci.yml lint/generate, job log analysis
- GitHub Actions: workflow debug, generation, secret management
- Jenkins: Jenkinsfile lint, job triggering, log analysis
- ArgoCD: sync status, app management, rollback, diff preview
- Bitbucket Pipelines: pipeline management, configuration
- Azure DevOps Pipelines: pipeline management, variable groups

#### Container & Orchestration Agent
**Zodpovednost:** Kontejnery, orchestrace, service mesh
**Nastroje:**
- Docker: Dockerfile optimization, image security scan, build troubleshooting
- Kubernetes: kubectl operations, manifest generation, troubleshooting, HPA, RBAC
- Helm: chart development, values review, release management
- Podman: rootless container management
- K3s / K0s: lightweight cluster setup a management
- Portainer: container management UI, stack deployment
- KubeSolo: single-node Kubernetes management
- Docker Compose: multi-container orchestration

#### Monitoring & Observability Agent
**Zodpovednost:** Monitoring, alerting, logging, tracing, metriky
**Nastroje:**
- Grafana: dashboard management, panel queries, annotations
- Prometheus: PromQL queries, alert rules, target health
- Loki: LogQL queries, log pattern detection
- Mimir: long-term metric storage, multi-tenant queries
- Grafana Alloy: telemetry collector configuration, pipeline management
- Zabbix: host/trigger monitoring, template management
- Datadog: metric queries, monitor management, APM
- ELK Stack: Elasticsearch queries, Kibana dashboards, index management
- New Relic: NRQL queries, alert policies, SLI/SLO tracking
- StatusPage: status page management, incident communication
- PagerDuty / OpsGenie: incident management, on-call schedules

#### Security Agent
**Zodpovednost:** Security scanning, compliance, secret management
**Nastroje:**
- HashiCorp Vault: secret management, policy review, audit
- Trivy: image/filesystem/IaC vulnerability scanning
- Snyk: dependency scanning, fix suggestions
- SonarQube: code quality, security hotspots
- SOPS: encrypted secrets management
- Sealed Secrets: Kubernetes secret encryption
- Falco: runtime security monitoring
- cert-manager: TLS certificate lifecycle
- OWASP ZAP: web application scanning
- Wazuh: SIEM, intrusion detection, compliance monitoring, log analysis

#### Database Agent
**Zodpovednost:** Database operations, optimization, backup
**Nastroje:**
- PostgreSQL: query optimization, migration review, backup/restore, EXPLAIN
- MySQL / MariaDB: performance tuning, slow query analysis, replication
- MongoDB: index optimization, aggregation pipelines, sharding
- Redis: memory analysis, key patterns, replication, sentinel
- ClickHouse: query optimization, table engine selection
- Elasticsearch: index management, mapping review, cluster health

#### Code & Scripting Agent
**Zodpovednost:** Version control, code review, scripting, automation
**Nastroje:**
- Git: branch strategy, merge conflicts, history analysis
- GitHub: PR review, Actions, Issues, Projects, Dependabot
- GitLab: MR review, CI, Issues, Package Registry
- Bitbucket: PR review, Pipelines
- Gitea / Forgejo: self-hosted git management
- Bash scripting: generation, debugging, optimization
- Python scripting: automation, boto3, fabric
- Go scripting: tooling, CLI development
- PowerShell: Windows automation, Azure cmdlets
- Makefiles / Taskfile: task runners, build automation

#### Project & Collaboration Agent
**Zodpovednost:** Project management, dokumentace, komunikace
**Nastroje:**
- Jira: issue management, JQL, sprint tracking
- Confluence: documentation generation, page updates
- Linear: issue tracking, project management
- Trello: board/card management
- Asana: task management
- Notion: documentation, databases
- Redmine: issue tracking (legacy)

#### Server Administration Agent
**Zodpovednost:** OS-level sprava, system administration
**Nastroje:**
- Linux: systemd, journalctl, package management (apt/yum/dnf), cron, users/groups
- Unix/BSD: FreeBSD/OpenBSD system management
- macOS: Homebrew, launchd, system preferences
- Windows: PowerShell, IIS, Windows Services, Group Policy, Active Directory
- SSH: remote management, key management, tunneling, config
- Systemd: service management, timer creation, journal analysis

#### Web Server Agent
**Zodpovednost:** Web server konfigurace a management
**Nastroje:**
- nginx: config generation, optimization, SSL setup, reverse proxy, load balancing
- Apache (httpd): vhost config, mod_rewrite, .htaccess, SSL
- Caddy: automatic HTTPS, Caddyfile management
- Traefik: IngressRoute, middleware, Let's Encrypt

#### Networking Agent
**Zodpovednost:** Sit, DNS, VPN, firewally, certifikaty
**Nastroje:**
- DNS: Cloudflare, Route53, BIND, PowerDNS, record management
- SSL/TLS: certifikat management, Let's Encrypt, cert-manager, OpenSSL
- VPN: WireGuard, OpenVPN, IPsec - setup, config, troubleshooting
- Firewall: iptables, nftables, firewalld, UFW, cloud security groups
- Load Balancing: nginx, HAProxy, cloud LB
- Service Mesh: Istio, Linkerd
- File Transfer: SSH/SCP, FTP/SFTP, Rsync - config, troubleshooting, automation
- Mail: Postfix, Dovecot, DKIM/SPF/DMARC, relay configuration

#### Backup Agent
**Zodpovednost:** Zalohovani, obnova, disaster recovery
**Nastroje:**
- Restic: backup management, repository maintenance, restore
- Borg / BorgBackup: deduplicated backups, pruning, repository management
- Velero: Kubernetes backup/restore, migration
- pg_dump / mysqldump: database-specific backups
- Cloud backups: AWS Backup, GCP snapshots, Azure Backup
- rsync-based: custom backup scripts, rotation

---

## 4. KOMPLETNI MAPA INTEGRACI

### Prehledova tabulka

| Domena | Nastroje | Priorita |
|--------|----------|----------|
| IaC | Terraform, OpenTofu, Ansible | P0 |
| CI/CD | GitLab CI, GitHub Actions, Jenkins, ArgoCD, Bitbucket, Azure DevOps | P0 |
| Containers | Docker, Kubernetes, Helm, Podman, K3s/K0s, Portainer, KubeSolo, Compose | P0 |
| Cloud | AWS, GCP, Azure, DigitalOcean, Hetzner, Hyper-V, Proxmox VE, XCP-ng | P0-P1 |
| Monitoring | Grafana, Prometheus, Loki, Mimir, Alloy, Zabbix, Datadog, ELK, New Relic, StatusPage | P0 |
| Security | Vault, Trivy, Snyk, SonarQube, SOPS, Sealed Secrets, Falco, cert-manager, OWASP ZAP, Wazuh | P1 |
| Databases | PostgreSQL, MySQL, MongoDB, Redis, ClickHouse, Elasticsearch | P1 |
| Git/Code | Git, GitHub, GitLab, Bitbucket, Gitea/Forgejo | P0 |
| Scripting | Bash, Python, Go, PowerShell, Makefiles, Taskfile | P0 |
| Communication | Slack, RocketChat, Telegram, MS Teams, Discord, Email | P0-P1 |
| Project Mgmt | Jira, Confluence, Linear, Trello, Asana, Notion, Redmine | P1 |
| Servers | Linux, Unix, macOS, Windows, SSH, systemd | P0 |
| Web Servers | nginx, Apache, Caddy, Traefik | P1 |
| Networking | DNS, SSL/TLS, VPN, Firewall, LB, Service Mesh, SSH/FTP/Rsync, Mail | P1 |
| Backup | Restic, Borg, Velero, pg_dump, cloud backups | P1 |
| Incident Mgmt | PagerDuty, OpsGenie, StatusPage | P1 |

### Prioritizace
- **P0** = Faze 1-3 (zakladni funkcionalita)
- **P1** = Faze 4-6 (rozsirena funkcionalita)
- **P2** = Faze 7+ (pokrocile funkce)

---

## 5. PERMISSION SYSTEM

### Filozofie
Kazdy uzivatel si muze nastavit jak moc autonomni OTTO bude.
System pracuje s 4 urovnemi opravneni:

```
deny     -> zakazano, OTTO tuto akci neprovede ani nenavrhne
suggest  -> OTTO navrhne akci a ceka na schvaleni
confirm  -> OTTO se zepta "Provest? [Y/n]" a ceka na odpoved
auto     -> OTTO provede automaticky a informuje zpetne
```

### Konfigurace (config.yaml)

```yaml
permissions:
  # Globalni vychozi chovani
  default_mode: suggest

  # Per-prostredi eskalace
  environments:
    development:
      default: auto
    staging:
      default: confirm
    production:
      default: suggest
      destructive: deny

  # Per-domena pravidla
  domains:
    infrastructure:
      read_state: auto
      plan: auto
      apply: confirm
      destroy: deny
      import: confirm

    kubernetes:
      get: auto
      describe: auto
      logs: auto
      scale: confirm
      apply: confirm
      delete: deny
      exec: confirm
      rollback: confirm

    ci_cd:
      view: auto
      trigger_build: confirm
      retry_job: auto
      cancel_job: confirm
      modify_pipeline: suggest
      deploy: confirm

    monitoring:
      query: auto
      create_alert: confirm
      silence_alert: confirm
      acknowledge: auto
      dashboard_edit: confirm

    database:
      select: auto
      explain: auto
      migrate_dry_run: auto
      migrate_execute: confirm
      backup: auto
      restore: confirm
      drop: deny

    security:
      scan: auto
      rotate_secret: confirm
      modify_policy: suggest
      revoke_access: deny

    communication:
      read: auto
      send_dm: auto
      send_channel: confirm
      create_incident: confirm
      page_oncall: suggest

    git:
      read: auto
      commit: confirm
      push: confirm
      force_push: deny
      branch_delete: confirm

    scripts:
      dry_run: auto
      execute_safe: confirm
      execute_unsafe: suggest

    servers:
      read_status: auto
      restart_service: confirm
      modify_config: suggest
      reboot: deny

    backup:
      create: auto
      list: auto
      restore: confirm
      delete: deny

  # Preddefinovane profily
  profiles:
    paranoid:
      description: "Vse vyzaduje potvrzeni, idealni pro production"
      default_mode: suggest
    balanced:
      description: "Cteni auto, zapisy confirm, destrukce deny"
      default_mode: confirm
    autonomous:
      description: "Maximum automatizace, pro dev prostredi"
      default_mode: auto
    beginner:
      description: "Vse vysvetli a ceka, ucici rezim"
      default_mode: suggest
      explain_before_action: true
      show_tutorials: true
```

### Eskalacni matice

| Akce \ Prostredi | Dev | Staging | Production |
|-------------------|-----|---------|------------|
| Read/Query | auto | auto | auto |
| Plan/DryRun | auto | auto | auto |
| Apply/Execute | auto | confirm | suggest |
| Modify config | confirm | suggest | suggest |
| Delete/Destroy | confirm | deny | deny |
| Restart/Reboot | auto | confirm | suggest |
| Scale up | auto | confirm | confirm |
| Scale down | confirm | confirm | suggest |
| Rollback | confirm | confirm | confirm |
| Force operations | deny | deny | deny |

---

## 6. NIGHT WATCHER

### Koncept
Night Watcher je rezim kde OTTO bezi pres noc (nebo kdykoli uzivatel
neni u PC) a aktivne monitoruje vsechny nakonfigurovane systemy.
Rano dostane uzivatel kompletni report.

### Architektura

```
Uzivatel: "otto good night" / "otto watch"
    |
    v
+-- Night Watcher Mode aktivovan --+
|                                    |
|  Heartbeat: kazdych 15-30 min      |
|                                    |
|  Kontroluje:                       |
|  - System health (CPU, RAM, disk)  |
|  - Monitoring alerts               |
|  - CI/CD pipeline status           |
|  - Kubernetes pod health           |
|  - Security events                 |
|  - Database health                 |
|  - SSL certifikat expirace         |
|  - Backup status                   |
|  - Deployment status               |
|  - Log anomalie                    |
|                                    |
|  Pri kritickem alertu:             |
|  -> Okamzita notifikace (dle cfg)  |
|  -> Pokus o auto-remediation       |
|     (v ramci permissions)          |
|                                    |
|  Loguje vsechno do:                |
|  state/night-watch/YYYY-MM-DD.json |
+------------------------------------+
    |
    v (rano nebo pri "otto good morning")
+-- Morning Report / Dawn Briefing --+
|                                     |
|  Obsahuje:                          |
|  1. Executive Summary               |
|    - Celkovy stav: OK/WARN/CRIT    |
|    - Pocet alertu pres noc          |
|    - Nejvaznejsi udalosti           |
|                                     |
|  2. System Health Overview           |
|    - Per-server/cluster status      |
|    - Resource utilization trends    |
|    - Anomalie vs. normal provoz     |
|                                     |
|  3. Deployments & Changes            |
|    - Co se deploylo pres noc        |
|    - Pipeline vysledky              |
|    - Merge requesty/PR status       |
|                                     |
|  4. Security Events                  |
|    - Failed login attempts          |
|    - Vulnerability alerts           |
|    - Certificate warnings           |
|                                     |
|  5. Action Items                     |
|    - Co je treba resit HNED         |
|    - Co muze pockat                 |
|    - Doporucene kroky               |
|                                     |
|  6. Trends & Insights               |
|    - Week-over-week porovnani       |
|    - Predikce (disk space, certs)   |
+-------------------------------------+
```

### Konfigurace

```yaml
night_watcher:
  enabled: true
  schedule:
    start: "22:00"       # Kdy zacit nocni rezim
    end: "07:00"         # Kdy ukoncit a generovat report
    timezone: "Europe/Prague"
  heartbeat_interval: 900  # 15 minut (sekundy)
  
  # Co monitorovat
  checks:
    system_health: true
    monitoring_alerts: true
    cicd_pipelines: true
    kubernetes_pods: true
    security_events: true
    database_health: true
    ssl_certificates: true
    backup_status: true
    log_anomalies: true
  
  # Eskalace pri kritickem alertu
  critical_escalation:
    enabled: true
    channels:
      - type: slack_dm
      - type: telegram
      - type: email
    cooldown: 1800  # 30 minut mezi eskalacemi
  
  # Auto-remediation v noci
  auto_remediation:
    enabled: false  # Defaultne vypnuto, uzivatel musi explicitne zapnout
    allowed_actions:
      - restart_crashed_pods
      - clear_disk_space_temp
      - rotate_logs
    forbidden_actions:
      - scale_infrastructure
      - modify_configs
      - database_operations
  
  # Report
  morning_report:
    format: detailed  # brief | detailed | executive
    delivery:
      - type: slack_dm
      - type: email
    include_trends: true
    include_predictions: true
```

---

## 7. STRUKTURA PROJEKTU

```
otto/
|-- CLAUDE.md                       # Hlavni plugin definice
|-- README.md                       # Dokumentace projektu
|-- LICENSE                         # MIT licence
|-- CONTRIBUTING.md                 # Prispivaci guidelines
|-- CHANGELOG.md                    # Historie zmen
|-- CODE_OF_CONDUCT.md              # Kodex chovani
|-- SECURITY.md                     # Security policy
|-- marketplace.json                # Claude Code marketplace metadata
|-- install.sh                      # Jednoducha instalace
|-- otto                            # CLI entry point (bash)
|-- .github/
|   |-- workflows/
|   |   |-- ci.yml                  # Hlavni CI pipeline
|   |   |-- release.yml             # Release automation
|   |   |-- shellcheck.yml          # Bash linting
|   |   `-- bats.yml                # Test runner
|   |-- ISSUE_TEMPLATE/
|   |   |-- bug_report.md
|   |   |-- feature_request.md
|   |   `-- integration_request.md
|   |-- PULL_REQUEST_TEMPLATE.md
|   `-- CODEOWNERS
|-- config/
|   |-- default.yaml                # Vychozi konfigurace
|   `-- profiles/
|       |-- beginner.yaml           # Profil pro zacatecniky
|       |-- balanced.yaml           # Vyvazeny profil
|       |-- autonomous.yaml         # Plne autonomni
|       `-- paranoid.yaml           # Maximalni opatrnost
|-- agents/
|   |-- core/
|   |   |-- orchestrator.md         # Hlavni mozek (Opus)
|   |   |-- planner.md              # Task planning & scheduling
|   |   |-- communicator.md         # Multi-channel komunikace
|   |   `-- learner.md              # Knowledge & self-improvement
|   |-- specialists/
|   |   |-- infra.md                # IaC + Cloud + Virtualizace
|   |   |-- cicd.md                 # CI/CD pipelines
|   |   |-- containers.md           # Docker + K8s + Helm
|   |   |-- monitor.md              # Monitoring + Observability
|   |   |-- security.md             # Security + Compliance
|   |   |-- database.md             # Database operations
|   |   |-- code.md                 # Git + Code review + Scripting
|   |   |-- project.md              # Project management
|   |   |-- server-admin.md         # OS & server administration
|   |   |-- webserver.md            # Web server management
|   |   |-- networking.md           # Networking, DNS, VPN, certs
|   |   `-- backup.md               # Backup & disaster recovery
|   `-- sources/
|       |-- grafana.md
|       |-- prometheus.md
|       |-- loki.md
|       |-- mimir.md
|       |-- zabbix.md
|       |-- datadog.md
|       |-- elk.md
|       |-- newrelic.md
|       |-- alloy.md
|       |-- statuspage.md
|       |-- gitlab.md
|       |-- github.md
|       |-- bitbucket.md
|       |-- jira.md
|       |-- confluence.md
|       |-- slack.md
|       |-- telegram.md
|       |-- rocketchat.md
|       |-- teams.md
|       |-- discord.md
|       |-- email.md
|       |-- kubernetes.md
|       |-- docker.md
|       |-- terraform.md
|       |-- ansible.md
|       |-- aws.md
|       |-- gcp.md
|       |-- azure.md
|       |-- digitalocean.md
|       |-- hetzner.md
|       |-- hyperv.md
|       |-- proxmox.md
|       |-- vault.md
|       |-- wazuh.md
|       `-- pagerduty.md
|-- scripts/
|   |-- core/
|   |   |-- setup.sh                # Interactive setup wizard
|   |   |-- heartbeat.sh            # Adaptive heartbeat management
|   |   |-- permissions.sh          # Permission check & enforcement
|   |   |-- config.sh               # Config loading & validation
|   |   |-- state.sh                # State management
|   |   |-- night-watcher.sh        # Night Watcher rezim
|   |   `-- morning-report.sh       # Morning report generator
|   |-- fetch/
|   |   |-- grafana.sh
|   |   |-- prometheus.sh
|   |   |-- loki.sh
|   |   |-- zabbix.sh
|   |   |-- kubernetes.sh
|   |   |-- terraform.sh
|   |   |-- ansible.sh
|   |   |-- docker.sh
|   |   |-- gitlab.sh
|   |   |-- github.sh
|   |   |-- cloud-aws.sh
|   |   |-- cloud-gcp.sh
|   |   |-- cloud-azure.sh
|   |   |-- server-health.sh
|   |   |-- ssl-certs.sh
|   |   |-- backup-status.sh
|   |   `-- security-events.sh
|   |-- actions/
|   |   |-- deploy.sh
|   |   |-- rollback.sh
|   |   |-- scale.sh
|   |   |-- restart-service.sh
|   |   |-- backup-create.sh
|   |   |-- cert-renew.sh
|   |   `-- incident-create.sh
|   |-- templates/
|   |   |-- slack/
|   |   |   |-- morning-briefing.json
|   |   |   |-- night-report.json
|   |   |   |-- alert-notification.json
|   |   |   |-- task-update.json
|   |   |   `-- triage-request.json
|   |   |-- telegram/
|   |   |   |-- morning-briefing.txt
|   |   |   `-- alert-notification.txt
|   |   |-- rocketchat/
|   |   |-- teams/
|   |   |-- discord/
|   |   `-- email/
|   |       |-- morning-briefing.html
|   |       `-- alert-notification.html
|   `-- lib/
|       |-- logging.sh              # Structured logging
|       |-- error-handling.sh       # Error handling framework
|       |-- json-utils.sh           # JSON manipulation helpers
|       |-- yaml-utils.sh           # YAML parsing helpers
|       |-- platform-detect.sh      # Detect available tools
|       |-- permission-check.sh     # Permission enforcement
|       |-- version.sh              # Version management
|       `-- colors.sh               # Terminal color helpers
|-- knowledge/
|   |-- best-practices/
|   |   |-- kubernetes.md
|   |   |-- terraform.md
|   |   |-- docker.md
|   |   |-- cicd.md
|   |   |-- security.md
|   |   |-- monitoring.md
|   |   `-- backup.md
|   |-- troubleshooting/
|   |   |-- kubernetes-common.md
|   |   |-- terraform-errors.md
|   |   |-- docker-issues.md
|   |   |-- networking.md
|   |   |-- ssl-tls.md
|   |   `-- database.md
|   |-- runbooks/
|   |   |-- incident-response.md
|   |   |-- deployment-rollback.md
|   |   |-- database-recovery.md
|   |   |-- certificate-renewal.md
|   |   `-- disk-space-cleanup.md
|   `-- patterns/
|       |-- high-availability.md
|       |-- blue-green-deploy.md
|       |-- canary-deploy.md
|       |-- gitops-workflow.md
|       `-- zero-downtime-migration.md
|-- tests/
|   |-- unit/
|   |   |-- test_config.bats
|   |   |-- test_permissions.bats
|   |   |-- test_state.bats
|   |   |-- test_logging.bats
|   |   `-- test_platform_detect.bats
|   |-- integration/
|   |   |-- test_setup.bats
|   |   |-- test_heartbeat.bats
|   |   `-- test_night_watcher.bats
|   `-- fixtures/
|       |-- sample-config.yaml
|       |-- sample-state.json
|       `-- mock-responses/
|-- docs/
|   |-- getting-started.md
|   |-- configuration.md
|   |-- agents.md
|   |-- permissions.md
|   |-- night-watcher.md
|   |-- integrations/
|   |   |-- monitoring.md
|   |   |-- cicd.md
|   |   |-- cloud.md
|   |   |-- kubernetes.md
|   |   `-- communication.md
|   `-- examples/
|       |-- beginner-setup.md
|       |-- team-setup.md
|       |-- enterprise-setup.md
|       `-- night-watcher-setup.md
`-- state/                           # Runtime (gitignored)
    |-- state.json
    |-- log.jsonl
    |-- tasks/
    |   |-- triage/
    |   |-- todo/
    |   |-- in-progress/
    |   |-- done/
    |   |-- failed/
    |   `-- cancelled/
    |-- memory/
    |   |-- projects/
    |   |-- people/
    |   |-- decisions/
    |   |-- learnings/
    |   `-- runbooks/
    |-- night-watch/
    |   `-- YYYY-MM-DD.json
    `-- dashboard.html
```

---

## 8. IMPLEMENTACNI FAZE

### FAZE 0: Zaklad projektu (Tyden 1)

**Cil:** Funkcni GitHub repo s CI/CD a zakladni strukturou.

| # | Ukol | Popis |
|---|------|-------|
| 0.1 | GitHub repo | Vytvorit repo, .gitignore, LICENSE (MIT), README.md |
| 0.2 | Repo meta | CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CODEOWNERS |
| 0.3 | Issue templates | Bug report, feature request, integration request |
| 0.4 | PR template | Standardni PR template |
| 0.5 | GitHub Actions | CI pipeline (shellcheck, BATS, markdown lint) |
| 0.6 | Adresarova struktura | Vytvorit kompletni adresarovou strukturu (prazdne soubory) |
| 0.7 | CLAUDE.md | Hlavni plugin definice - zakladni verze |
| 0.8 | marketplace.json | Plugin metadata pro Claude Code marketplace |
| 0.9 | install.sh | Instalacni skript (git clone + symlink + setup) |
| 0.10 | config/default.yaml | Vychozi konfigurace |
| 0.11 | config/profiles/ | 4 zakladni profily (beginner, balanced, autonomous, paranoid) |

**Deliverable:** Prazdny ale plne nastaveny repo s CI/CD.

---

### FAZE 1: Core Framework (Tyden 2-3)

**Cil:** Funkcni zakladni framework - config, stav, logování, heartbeat.

| # | Ukol | Popis |
|---|------|-------|
| 1.1 | scripts/lib/logging.sh | Structured logging (JSON + human-readable) |
| 1.2 | scripts/lib/error-handling.sh | Trap handlers, error reporting, graceful degradation |
| 1.3 | scripts/lib/json-utils.sh | jq wrapper funkce |
| 1.4 | scripts/lib/yaml-utils.sh | yq wrapper funkce |
| 1.5 | scripts/lib/colors.sh | Terminal output formatting |
| 1.6 | scripts/lib/version.sh | Verze management |
| 1.7 | scripts/core/config.sh | Config loading, validation, merging (default + user + profile) |
| 1.8 | scripts/core/state.sh | State management (JSON state file, task queue) |
| 1.9 | scripts/core/permissions.sh | Permission system implementation |
| 1.10 | scripts/lib/platform-detect.sh | Auto-detect installed tools (kubectl, terraform, ...) |
| 1.11 | scripts/core/heartbeat.sh | Adaptive heartbeat/loop system |
| 1.12 | scripts/core/setup.sh | Interactive setup wizard |
| 1.13 | otto (CLI) | CLI entry point - command dispatcher |
| 1.14 | Unit testy | BATS testy pro vsechny lib/ a core/ skripty |

**Deliverable:** `otto setup` funguje, detekuje nastroje, vytvori konfiguraci.

---

### FAZE 2: Core Agents (Tyden 4-5)

**Cil:** Funkcni agentni system s orchestraci a komunikaci.

| # | Ukol | Popis |
|---|------|-------|
| 2.1 | agents/core/orchestrator.md | Hlavni orchestrator agent - delegace, rozhodovani, heartbeat |
| 2.2 | agents/core/planner.md | Task planning, prioritizace, dependency graph |
| 2.3 | agents/core/communicator.md | Multi-channel komunikace (zaklad) |
| 2.4 | agents/core/learner.md | Knowledge base management, self-improvement |
| 2.5 | Slack integrace | Slack source + fetch skript + templates |
| 2.6 | Telegram integrace | Telegram bot source + fetch skript + templates |
| 2.7 | RocketChat integrace | RocketChat source + fetch + templates |
| 2.8 | MS Teams integrace | Teams source + fetch + templates |
| 2.9 | Discord integrace | Discord source + fetch + templates |
| 2.10 | Email integrace | SMTP/Gmail source + templates |
| 2.11 | Morning briefing | Ranni prehled - sablonya + logika |
| 2.12 | Task management | Markdown task queue s YAML frontmatter |
| 2.13 | Knowledge base | Struktura memory/ + index management |
| 2.14 | Integracni testy | Testy pro agentni orchestraci |

**Deliverable:** OTTO komunikuje pres Slack/Telegram, ridi tasky, uci se.

---

### FAZE 3: DevOps Specialist Agents - Tier 1 (Tyden 6-9)

**Cil:** Hlavni DevOps agenti pro kazdodenni praci.

| # | Ukol | Popis |
|---|------|-------|
| **Infrastructure Agent** | | |
| 3.1 | agents/specialists/infra.md | Agent definice |
| 3.2 | Terraform integrace | plan, apply, state, drift detection, modules |
| 3.3 | OpenTofu integrace | Kompatibilni s Terraform integraci |
| 3.4 | Ansible integrace | playbook lint/run, inventory, roles, vault |
| **CI/CD Agent** | | |
| 3.5 | agents/specialists/cicd.md | Agent definice |
| 3.6 | GitLab CI integrace | Pipeline debug, lint, job log analysis |
| 3.7 | GitHub Actions integrace | Workflow debug, generation, secrets |
| 3.8 | Jenkins integrace | Jenkinsfile lint, job trigger, logs |
| 3.9 | ArgoCD integrace | Sync status, rollback, diff |
| 3.10 | Bitbucket Pipelines | Pipeline management |
| 3.11 | Azure DevOps Pipelines | Pipeline management |
| **Container Agent** | | |
| 3.12 | agents/specialists/containers.md | Agent definice |
| 3.13 | Docker integrace | Dockerfile optimization, image scan, compose |
| 3.14 | Kubernetes integrace | kubectl, manifesty, troubleshooting, HPA, RBAC |
| 3.15 | Helm integrace | Chart dev, values review, release mgmt |
| 3.16 | Podman integrace | Rootless containers |
| 3.17 | K3s/K0s integrace | Lightweight clusters |
| 3.18 | Portainer integrace | Container management |
| 3.19 | KubeSolo integrace | Single-node K8s |
| **Monitoring Agent** | | |
| 3.20 | agents/specialists/monitor.md | Agent definice |
| 3.21 | Grafana integrace | Dashboard, panels, alerts (MCP + fetch) |
| 3.22 | Prometheus integrace | PromQL, alert rules, targets |
| 3.23 | Loki integrace | LogQL, patterns, labels |
| 3.24 | Mimir integrace | Long-term metrics, multi-tenant |
| 3.25 | Grafana Alloy integrace | Telemetry collector config |
| 3.26 | Zabbix integrace | Hosts, triggers, templates |
| 3.27 | Datadog integrace | Metrics, monitors, APM |
| 3.28 | ELK Stack integrace | Elasticsearch, Kibana, Logstash |
| 3.29 | New Relic integrace | NRQL, alerts, SLI/SLO |
| 3.30 | StatusPage integrace | Status page management |
| **Code & Scripting Agent** | | |
| 3.31 | agents/specialists/code.md | Agent definice |
| 3.32 | Git/GitHub/GitLab/Bitbucket | PR/MR review, branching, history |
| 3.33 | Gitea/Forgejo integrace | Self-hosted git |
| 3.34 | Bash/Python/Go/PS/Make | Script generation, review, optimization |
| **Server Admin Agent** | | |
| 3.35 | agents/specialists/server-admin.md | Agent definice |
| 3.36 | Linux integrace | systemd, package mgmt, users, cron, journalctl |
| 3.37 | macOS integrace | Homebrew, launchd |
| 3.38 | Windows integrace | PowerShell, IIS, Services, AD |

**Deliverable:** OTTO umi spravovat infra, CI/CD, kontejnery, monitoring, kod, servery.

---

### FAZE 4: DevOps Specialist Agents - Tier 2 (Tyden 10-13)

**Cil:** Doplnkove agenti pro kompletni pokryti DevOps.

| # | Ukol | Popis |
|---|------|-------|
| **Security Agent** | | |
| 4.1 | agents/specialists/security.md | Agent definice |
| 4.2 | Vault integrace | Secret management, policies, audit |
| 4.3 | Trivy integrace | Image/FS/IaC scanning |
| 4.4 | Snyk integrace | Dependency scanning |
| 4.5 | SonarQube integrace | Code quality, security hotspots |
| 4.6 | SOPS + Sealed Secrets | Encrypted secrets |
| 4.7 | Falco integrace | Runtime security |
| 4.8 | cert-manager integrace | TLS lifecycle |
| 4.9 | OWASP ZAP integrace | Web app scanning |
| 4.10 | Wazuh integrace | SIEM, IDS, compliance |
| **Database Agent** | | |
| 4.11 | agents/specialists/database.md | Agent definice |
| 4.12 | PostgreSQL integrace | Query opt, migrations, backup, EXPLAIN |
| 4.13 | MySQL/MariaDB integrace | Performance, slow queries, replication |
| 4.14 | MongoDB integrace | Indexes, aggregations, sharding |
| 4.15 | Redis integrace | Memory analysis, sentinel |
| 4.16 | ClickHouse integrace | Query optimization |
| 4.17 | Elasticsearch integrace | Index mgmt, cluster health |
| **Cloud Agent (rozsireni)** | | |
| 4.18 | AWS integrace | EC2, S3, RDS, Lambda, EKS, IAM, VPC, Cost Explorer |
| 4.19 | GCP integrace | GKE, Cloud Run, BigQuery, IAM |
| 4.20 | Azure integrace | AKS, App Service, CosmosDB, AD |
| 4.21 | DigitalOcean integrace | Droplets, DOKS, Spaces |
| 4.22 | Hetzner integrace | Servers, volumes, networks |
| 4.23 | Hyper-V integrace | VM management, snapshots |
| 4.24 | Proxmox VE integrace | VM/CT, clustering, storage |
| **Project Agent** | | |
| 4.26 | agents/specialists/project.md | Agent definice |
| 4.27 | Jira + Confluence | Issues, JQL, sprints, pages |
| 4.28 | Linear integrace | Issue tracking |
| 4.29 | Trello integrace | Boards, cards |
| 4.30 | Asana integrace | Tasks |

**Deliverable:** OTTO pokryva security, databaze, cloud, project management.

---

### FAZE 5: Networking, Web, Backup (Tyden 14-16)

**Cil:** Specialni domeny pro kompletni DevOps pokryti.

| # | Ukol | Popis |
|---|------|-------|
| **Web Server Agent** | | |
| 5.1 | agents/specialists/webserver.md | Agent definice |
| 5.2 | nginx integrace | Config gen, SSL, reverse proxy, optimization |
| 5.3 | Apache integrace | Vhosts, mod_rewrite, .htaccess, SSL |
| 5.4 | Caddy integrace | Auto HTTPS, Caddyfile |
| 5.5 | Traefik integrace | IngressRoute, middleware |
| **Networking Agent** | | |
| 5.6 | agents/specialists/networking.md | Agent definice |
| 5.7 | DNS integrace | Cloudflare, Route53, BIND, PowerDNS |
| 5.8 | SSL/TLS integrace | Cert management, Let's Encrypt, OpenSSL |
| 5.9 | VPN integrace | WireGuard, OpenVPN, IPsec |
| 5.10 | Firewall integrace | iptables, nftables, UFW, security groups |
| 5.11 | Load balancing | nginx LB, HAProxy, cloud LB |
| 5.12 | Service Mesh | Istio, Linkerd |
| 5.13 | SSH/SCP integrace | Remote management, key mgmt, tunneling |
| 5.14 | FTP/SFTP integrace | File transfer config |
| 5.15 | Rsync integrace | Sync automation |
| 5.16 | Mail integrace | Postfix, Dovecot, DKIM/SPF/DMARC |
| **Backup Agent** | | |
| 5.17 | agents/specialists/backup.md | Agent definice |
| 5.18 | Restic integrace | Backup, restore, repository mgmt |
| 5.19 | Borg integrace | Deduplicated backups, pruning |
| 5.20 | Velero integrace | Kubernetes backup/restore |
| 5.21 | Database backups | pg_dump, mysqldump, mongodump |
| 5.22 | Cloud backups | AWS Backup, GCP snapshots, Azure Backup |
| 5.23 | Rsync-based backups | Custom scripts, rotation |
| **PagerDuty/OpsGenie** | | |
| 5.24 | Incident management | On-call, escalation, incident lifecycle |

**Deliverable:** OTTO pokryva web servery, sit, backup, incident management.

---

### FAZE 6: Night Watcher & Intelligence (Tyden 17-19)

**Cil:** Nocni monitoring, incident response, knowledge engine.

| # | Ukol | Popis |
|---|------|-------|
| 6.1 | scripts/core/night-watcher.sh | Night Watcher core logic |
| 6.2 | scripts/core/morning-report.sh | Morning report generation |
| 6.3 | Night Watcher konfigurace | YAML config pro nocni rezim |
| 6.4 | Health check framework | Unifikovany system pro health checks vsech integrations |
| 6.5 | Alert aggregation | Sbirani a deduplication alertu z vice zdroju |
| 6.6 | Auto-remediation engine | Konfigurovatelne automaticke opravy (v ramci permissions) |
| 6.7 | Incident Response Pipeline | Alert -> triage -> diagnostika -> fix -> postmortem |
| 6.8 | Runbook automation | Cteni a semi-automaticke vykonavani runbooku |
| 6.9 | Cost intelligence | Cloud spending monitoring, unused resources, right-sizing |
| 6.10 | Compliance checks | CIS benchmarks, policy-as-code, audit trail |
| 6.11 | Trend analysis | Week-over-week porovnani, predikce (disk, certs, costs) |
| 6.12 | Night Watcher templates | Slack/Telegram/Email sablony pro nocni reporty |

**Deliverable:** Night Watcher funguje, generuje morning reporty, incident pipeline.

---

### FAZE 7: Knowledge Engine & Onboarding (Tyden 20-22)

**Cil:** Vestevena znalostni baze a system pro vsechny urovne uzivatelu.

| # | Ukol | Popis |
|---|------|-------|
| 7.1 | knowledge/best-practices/ | Kubernetes, Terraform, Docker, CI/CD, Security, Monitoring, Backup |
| 7.2 | knowledge/troubleshooting/ | K8s common issues, TF errors, Docker, networking, SSL, DB |
| 7.3 | knowledge/runbooks/ | Incident response, rollback, DB recovery, cert renewal, cleanup |
| 7.4 | knowledge/patterns/ | HA, blue-green, canary, GitOps, zero-downtime migration |
| 7.5 | Beginner mode | Vysvetlujici rezim - tutorials, best practices, varovani |
| 7.6 | Expert mode | Strucny rezim - zadne vysvetlovanl, pokrocile optimalizace |
| 7.7 | Adaptive detection | AI odhadne uroven uzivatele z interakci |
| 7.8 | Interactive tutorials | Guided walkthrough pro bezne DevOps ukoly |
| 7.9 | "Ask OTTO" mode | Q&A rezim - DevOps otazky s kontextovou odpovedi |

**Deliverable:** Knowledge engine funguje, onboarding pro vsechny urovne.

---

### FAZE 8: Multi-User & Team Features (Tyden 23-25)

**Cil:** Podpora pro tymy a sdilene prostredi.

| # | Ukol | Popis |
|---|------|-------|
| 8.1 | Team config | Sdilena konfigurace pro tym (git-friendly) |
| 8.2 | Shared knowledge base | Tymova znalostni baze (runbooks, decisions, learnings) |
| 8.3 | Role-based features | Ruzne pohledy pro ruzne role v tymu |
| 8.4 | Team notifications | Tymove kanaly, rotace on-call, eskalace |
| 8.5 | Shared dashboards | Tymovy prehled |
| 8.6 | Onboarding guide | Automaticky generovany onboarding pro nove cleny tymu |

**Deliverable:** OTTO funguje pro tymy, sdili znalosti, podporuje role.

---

### FAZE 9: Polish & Release (Tyden 26-28)

**Cil:** Production-ready release.

| # | Ukol | Popis |
|---|------|-------|
| 9.1 | Kompletni BATS test suite | Unit + integration testy, >80% coverage |
| 9.2 | shellcheck compliance | Vsechny skripty prochazi shellcheck bez warningu |
| 9.3 | Dokumentace | Kompletni docs/ - getting started, config, kazda integrace |
| 9.4 | README.md finalizace | Screenshots/GIFs, feature list, quick start |
| 9.5 | CHANGELOG.md | Kompletni historie zmen |
| 9.6 | Release automation | GitHub Actions pro tagging, release notes, changelog |
| 9.7 | Marketplace submission | Publish do Claude Code marketplace |
| 9.8 | Performance optimizace | Minimalizace API calls, caching, lazy loading |
| 9.9 | Security audit | Review vsech skriptu pro bezpecnostni problemy |
| 9.10 | Community setup | Discussion board, contributing guide, issue triage |
| 9.11 | Migration guide from Kvido | Pro uzivatele co prechazi z Kvida |
| 9.12 | Demo/showcase | Priklad kompletniho setupu pro prezentaci |

**Deliverable:** OTTO v1.0 release na GitHub + Claude Code marketplace.

---

## 9. GITHUB REPO SETUP

### Repository Settings
- **Nazev:** `otto` (nebo `otto-devops`)
- **Popis:** "OTTO - AI DevOps Assistant | Claude Code Plugin | Your DevOps autopilot"
- **Topics:** `devops`, `ai`, `claude`, `automation`, `infrastructure`, `kubernetes`,
  `terraform`, `monitoring`, `claude-code-plugin`, `sre`
- **Homepage:** README
- **License:** MIT

### Branch Protection (main)
- Require PR reviews (1 reviewer)
- Require status checks (shellcheck, BATS, markdown-lint)
- No force push
- No deletion

### GitHub Actions Workflows
1. **ci.yml** - Na kazdy PR: shellcheck, BATS testy, markdown lint
2. **release.yml** - Na tag: generuje release notes, changelog update
3. **shellcheck.yml** - Dedickovany shellcheck pro vsechny .sh soubory
4. **bats.yml** - Dedickovany test runner

### Issue Labels
- `bug` - Neco nefunguje
- `feature` - Nova funkcionalita
- `integration` - Nova integrace s nastrojem
- `agent` - Zmena/novy agent
- `docs` - Dokumentace
- `good first issue` - Pro nove prispevovatele
- `help wanted` - Potrebujeme pomoc
- `priority: critical` / `high` / `medium` / `low`
- `domain: infra` / `cicd` / `containers` / `monitoring` / `security` / `database` / `networking`

---

## 10. RIZIKA A MITIGACE

| Riziko | Dopad | Pravdepodobnost | Mitigace |
|--------|-------|-----------------|----------|
| Claude Code zmeni plugin API | Vysoki | Stredni | Abstrakce vrstva, rychla reakce na zmeny |
| Prilis mnoho integraci = diluted quality | Vysoki | Vysoka | Fazovany pristup, P0 integrace prvni, kvalita > kvantita |
| Naklady na Claude API (Opus) | Stredni | Vysoka | Tiered model selection (Haiku/Sonnet/Opus dle slozitosti) |
| Bash limitace pro slozitou logiku | Stredni | Stredni | Jednoduche skripty, slozitou logiku resi AI |
| Security - unik credentials | Vysoki | Nizka | .env v .gitignore, docs o secret management, audit |
| Night Watcher false positives | Stredni | Vysoka | Konfigurovatelne prahy, cooldown, postupne ladeni |
| Single-maintainer bottleneck | Vysoki | Vysoka | Community building, good contributor docs, modularni architektura |

---

## SOUHRN

- **Celkem fazi:** 10 (0-9)
- **Odhadovany rozsah:** ~28 tydnu pro kompletni v1.0
- **P0 funkcionalita (Faze 0-3):** ~9 tydnu = zakladni pouzitelny produkt
- **Celkem integraci:** 100+ nastroju across 15+ domen
- **Celkem agentu:** 4 core + 12 specialists = 16 agentu
- **Celkem source definici:** 35+ MCP/fetch zdroju

Dalsi krok: Potvrdit nazev -> Vytvorit GitHub repo -> Zahajit Fazi 0.
