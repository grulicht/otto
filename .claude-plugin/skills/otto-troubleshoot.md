---
name: troubleshoot
description: "Systematic troubleshooting with symptom gathering, diagnosis, and fix suggestions"
user-invocable: true
---

# OTTO Troubleshooting

Perform systematic troubleshooting for infrastructure and application issues.

## Arguments

- `[symptom]` - Description of the problem. If omitted, ask the user to describe it.

## Steps

### 1. Gather Symptoms
- Parse the symptom description
- Ask clarifying questions if needed:
  - When did it start?
  - What changed recently?
  - Is it intermittent or constant?
  - Which environments are affected?
  - Are there error messages?

### 2. Search Knowledge Base
- Run `knowledge_search` with relevant keywords from the symptom
- Check troubleshooting guides in `knowledge/troubleshooting/`
- Look for matching patterns in known issues

### 3. System Investigation
Based on the symptom, run relevant checks:

- **Application errors**: Check logs, error rates, recent deployments
- **Performance issues**: Check CPU, memory, disk, network metrics
- **Connectivity problems**: Check DNS, network policies, firewall rules, SSL certificates
- **Deployment failures**: Check CI/CD logs, image availability, resource quotas
- **Database issues**: Check connection pools, replication, slow queries, disk space
- **Kubernetes issues**: Check pod status, events, resource limits, node health

### 4. Form Hypotheses
Based on findings, rank possible causes by likelihood:
1. Most likely cause with supporting evidence
2. Second most likely, etc.

### 5. Suggest Fixes
For each hypothesis:
- Explain the likely root cause
- Provide specific commands or steps to fix
- Note any risks of the fix
- Suggest how to verify the fix worked

### 6. Reference Runbooks
If a matching runbook exists in `knowledge/runbooks/`, present it as a step-by-step guide.
