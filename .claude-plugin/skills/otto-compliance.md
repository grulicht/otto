---
name: otto:compliance
description: Run a compliance and security audit across infrastructure with a scored report
user-invocable: true
---

# OTTO Compliance Audit

Run a comprehensive compliance and security audit across all detected infrastructure.

## Steps

### 1. Detect Available Infrastructure
Run `./otto detect` to identify what tools and platforms are available for auditing.

### 2. Run Compliance Checks
Execute checks for each detected domain by sourcing the compliance checker:

- **Kubernetes** (`compliance_check_k8s_pods`): Root containers, resource limits, health probes, hostNetwork, privileged containers
- **Docker** (`compliance_check_docker_images`): Latest tag usage, vulnerability scanning with trivy
- **Terraform**: State encryption, provider pinning, sensitive variable handling
- **SSL/TLS**: Certificate expiration, key strength, protocol versions
- **Backups**: Backup freshness, retention policy compliance

### 3. Calculate Score
Run `compliance_score` to get an overall compliance score (0-100):
- Pass = full points
- Warning = half points
- Fail = zero points (critical failures count double)

### 4. Generate Report
Present the report with:

**Summary**
- Overall score: X/100
- Total checks: N (P passed, F failed, W warnings)

**Findings by Category**
For each category (kubernetes, docker, terraform, ssl, backups):
- List each check with PASS/WARN/FAIL status
- For failures: details and remediation steps

**Critical Issues**
Highlight any critical severity failures that need immediate attention.

**Recommendations**
Top 3-5 actionable items to improve the compliance score.

### 5. Log the Audit
Record the audit run via `audit_log` for tracking compliance over time.
