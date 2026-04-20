---
name: check
description: "Run health checks on a specific target or all targets"
user-invocable: true
---

# OTTO Health Check

Run targeted health checks using OTTO's fetch scripts.

## Arguments

- `[target]` - Optional. The specific check to run (e.g., kubernetes, docker, ssl, cicd, monitoring). If omitted, runs all available checks.

## Steps

1. Parse the target argument from the user's input
2. If a specific target is given, run `./otto check <target>`
3. If no target, run `./otto check` for all checks
4. Present results with clear status indicators

## Available Checks

Run `./otto check` with these targets:
- `kubernetes` / `k8s` - Pod health, deployments, resource usage
- `docker` - Container status, image health
- `cicd` - Pipeline status, recent builds
- `monitoring` - Alert status, metric health
- `ssl` - Certificate expiration dates
- `backup` - Backup status and freshness
- `database` / `db` - Connection health, replication
- `security` - Recent security events
- `system` - CPU, memory, disk usage

## Output Format

For each check, show:
- Status: PASS / WARN / FAIL
- Details of what was checked
- For failures: what is wrong and suggested remediation
- Timestamp of the check
