# Feature Maturity Guide

OTTO features are classified into three maturity levels. This helps you decide which features are safe for production and which need caution.

## Maturity Levels

- **Stable** - Production-ready, fully tested, API unlikely to change. Safe for critical workflows.
- **Beta** - Functional and usable, but needs more real-world testing. API may have minor changes.
- **Experimental** - Working but early stage. API may change significantly between versions.

## Feature Matrix

| Feature | Maturity | Scripts | Promotion Criteria |
|---------|----------|---------|-------------------|
| Core agents (orchestrator, planner, communicator, learner) | Stable | `agents/core/` | N/A |
| Generic agents (reviewer, troubleshooter, generator, executor, auditor, reporter, watcher) | Stable | `agents/generic/` | N/A |
| Specialist agents (infra, cicd, containers, monitor, security, database, etc.) | Stable | `agents/specialists/` | N/A |
| Permission system | Stable | `scripts/core/permissions.sh` | N/A |
| Heartbeat / loop management | Stable | `scripts/core/heartbeat.sh` | N/A |
| Night Watcher | Stable | `scripts/core/night-watcher.sh` | N/A |
| Fetch scripts (Kubernetes, Docker, cloud, CI/CD, monitoring) | Stable | `scripts/fetch/` | N/A |
| Knowledge engine | Stable | `scripts/core/knowledge-engine.sh` | N/A |
| Configuration system | Stable | `scripts/core/config.sh` | N/A |
| Task management | Stable | `scripts/core/state.sh` | N/A |
| CLI | Stable | `otto` | N/A |
| Morning report | Stable | `scripts/core/morning-report.sh` | N/A |
| Onboarding wizard | Stable | `scripts/core/onboarding.sh` | N/A |
| Alert routing | Beta | `scripts/core/alert-router.sh` | More production routing rule testing, edge case coverage |
| Alert aggregation | Beta | `scripts/core/alert-aggregator.sh` | Validate correlation accuracy at scale |
| ChatOps (Slack/Telegram) | Beta | `scripts/core/chatops.sh` | Test bidirectional commands across more platforms |
| HTML Dashboard | Beta | `scripts/core/dashboard.sh` | Cross-browser testing, accessibility audit |
| Postmortem generator | Beta | `scripts/core/postmortem.sh` | Validate output quality across incident types |
| Scheduler | Beta | `scripts/core/scheduler.sh` | Long-running stability testing, cron edge cases |
| Change tracker | Beta | `scripts/core/change-tracker.sh` | Test with large state diffs, performance validation |
| Compliance checker | Beta | `scripts/core/compliance-checker.sh`, `scripts/core/compliance-engine.sh` | More policy rule coverage, audit by security team |
| Team management | Beta | `scripts/core/team.sh` | Multi-team production testing |
| Role-based access control | Beta | `scripts/core/role-based.sh` | Security audit, permission escalation testing |
| Audit log | Beta | `scripts/core/audit-log.sh` | Log rotation at scale, compliance validation |
| Auto-remediation | Beta | `scripts/core/auto-remediation.sh` | Wider remediation action coverage, safety validation |
| Cost analyzer | Beta | `scripts/core/cost-analyzer.sh` | Multi-cloud cost model validation |
| Trend analyzer | Beta | `scripts/core/trend-analyzer.sh` | Statistical model accuracy validation |
| Adaptive UX | Beta | `scripts/core/adaptive-ux.sh` | User feedback across experience levels |
| Incident memory | Beta | `scripts/core/incident-memory.sh` | Long-term memory retention testing |
| Chaos engineering | Experimental | `scripts/core/chaos-assistant.sh` | Production safety audit, disk-fill and node-drain implementation |
| IaC scaffolding | Experimental | `scripts/core/iac-assistant.sh` | Template customization, more language/framework coverage |
| Terminal dashboard | Experimental | `scripts/core/terminal-dashboard.sh` | Terminal compatibility testing, responsive layout |
| MCP server | Experimental | `mcp/otto-server.sh` | Protocol compliance testing, authentication support |
| Multi-cluster orchestration | Experimental | `scripts/core/multi-cluster.sh` | Multi-cloud provider testing, failover scenarios |
| Capacity planner | Experimental | `scripts/core/capacity-planner.sh` | Prediction accuracy validation with real data |
| Anomaly detector | Experimental | `scripts/core/anomaly-detector.sh` | False positive rate tuning, seasonal model validation |
| Web server | Experimental | `scripts/core/web-server.sh` | Security hardening, authentication, HTTPS support |
| Plugin system | Experimental | `scripts/core/plugin-manager.sh` | Dependency resolution, version conflict handling |
| Runbook executor | Experimental | `scripts/core/runbook-executor.sh` | More runbook format support, error recovery |
| Doc generator | Experimental | `scripts/core/doc-generator.sh` | Output format options, template customization |
| Offline mode | Experimental | `scripts/core/offline-cache.sh` | Cache invalidation, queue reliability testing |

## Guidelines

**Stable features** are safe for production use. They have been tested across multiple environments, have comprehensive test coverage, and their APIs are frozen for the current major version.

**Beta features** work correctly in typical scenarios and are suitable for staging environments and non-critical production use. Report any issues you encounter to help promote them to stable.

**Experimental features** are functional but may have rough edges. Use them in development and testing environments. Their command-line interfaces and configuration options may change between minor versions. Feedback is especially valuable for these features.
