# OTTO Roadmap

## Wave 1: Gaps & Foundation (P0) - COMPLETED

### 1.1 Fetch scripts (48 total)
- [x] All 28 missing fetch scripts implemented
- [x] Total: 48 fetch scripts covering all source definitions

### 1.2 BATS tests (36+ total)
- [x] 16 unit tests (Wave 1)
- [x] 20 additional unit tests (gap-fill)
- [x] 5 integration tests (gap-fill)

### 1.3 Skills / Slash Commands (10 total)
- [x] otto-status, otto-morning, otto-watch, otto-check
- [x] otto-deploy, otto-incident, otto-review
- [x] otto-troubleshoot, otto-knowledge, otto-compliance

## Wave 2: Intelligence (P1) - COMPLETED

- [x] Dashboard generator (HTML + terminal ASCII)
- [x] Postmortem generator
- [x] Runbook executor (interactive step-by-step)
- [x] Scheduled checks with cron expressions
- [x] Diff/Change tracking (state snapshots)
- [x] Multi-language support (English + Czech)

## Wave 3: Communication & UX (P2) - COMPLETED

- [x] Alert routing rules (severity/domain/env-based)
- [x] ChatOps (bidirectional Slack/Telegram)
- [x] Terminal dashboard (colored ASCII UI)
- [x] Incident memory (context tracking, similar incident search)
- [x] Auto-generated documentation (infra overview, ADRs)
- [x] Offline mode (cache + notification queue)

## Wave 4: Advanced (P2-P3) - COMPLETED

- [x] Plugin/Extension system (install/update from git)
- [x] Web UI / Status Page (simple HTTP server)
- [x] MCP Server mode (expose OTTO as MCP tools)
- [x] AI anomaly detection (Z-score, MAD, IQR, seasonal)
- [x] Infrastructure drift reconciliation (terraform/k8s/ansible)

## Wave 5: Visionary (P3) - COMPLETED

- [x] Multi-cluster/Multi-cloud orchestration
- [x] Chaos Engineering assistant
- [x] IaC pair-programming (scaffolding)
- [x] Capacity planning predictor
- [x] Compliance-as-Code engine

## Wave 6: Technical Debt - COMPLETED

- [x] Knowledge base expansion (48 -> 57+ files)
- [x] Config schema validation (scripts/lib/config-schema.sh)
- [x] State file locking (scripts/lib/state-lock.sh)
- [x] Log rotation (scripts/lib/log-rotate.sh)
- [x] Comprehensive documentation (16+ doc files)
- [x] Missing source definitions filled (15 new)
- [x] Example custom agent plugin

## Future Ideas

- [ ] More languages (de, es, fr, ja, ...)
- [ ] Grafana dashboard import/export
- [ ] Terraform module registry integration
- [ ] Slack App manifest for easy bot setup
- [ ] VS Code extension integration
- [ ] Mobile notifications (push)
- [ ] AI-powered log analysis
- [ ] Cost anomaly detection
- [ ] SLA/SLO tracking dashboard
- [ ] Dependency graph visualization
