---
name: review
description: Review current changes with a DevOps lens for infrastructure and operational concerns
user-invocable: true
---

# OTTO DevOps Review

Review the current changes (staged, unstaged, or a PR) through a DevOps lens, focusing on infrastructure, security, and operational concerns.

## Steps

### 1. Identify Changes
- Run `git diff` and `git diff --cached` to find changes
- Identify file types: Terraform, Kubernetes manifests, Dockerfiles, CI configs, Helm charts, Ansible playbooks

### 2. Review by Category

**Terraform / OpenTofu (.tf files)**
- Check for missing `lifecycle` blocks on critical resources
- Verify state backend is configured
- Look for hardcoded secrets or credentials
- Check for missing variable descriptions and defaults
- Verify provider version constraints

**Kubernetes manifests (.yaml/.yml with K8s resources)**
- Check for missing resource limits/requests
- Verify security contexts (runAsNonRoot, readOnlyRootFilesystem)
- Look for missing health probes (liveness, readiness)
- Check for use of `latest` tag
- Verify namespace is specified

**Dockerfiles**
- Check for `FROM latest` or unpinned base images
- Look for `RUN` commands that could be combined
- Verify multi-stage builds where appropriate
- Check for secrets in build args or ENV
- Verify a non-root USER is set

**CI/CD configs (.github/workflows, .gitlab-ci.yml, Jenkinsfile)**
- Check for pinned action/image versions
- Look for secrets handling issues
- Verify test stages exist before deploy stages
- Check for missing environment protections

**General**
- Look for committed secrets, API keys, passwords
- Check for proper error handling in scripts
- Verify logging and monitoring configuration

### 3. Present Findings
- Group issues by severity (critical/warning/info)
- Provide specific line references
- Suggest fixes for each issue
