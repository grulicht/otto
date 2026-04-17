# CI/CD Pipeline Troubleshooting Guide
tags: cicd, pipeline, jenkins, gitlab, github-actions

## Pipeline Stuck / Hanging

**Symptom:** Pipeline job does not progress, no logs updating

**Diagnosis:**
1. Check runner/agent status and availability
2. Look for resource locks or waiting conditions
3. Check if job is queued waiting for manual approval
4. Verify no deadlocked dependencies between stages

**Fix:**
- Cancel and re-trigger the pipeline
- Check runner logs: `journalctl -u gitlab-runner` or Jenkins agent logs
- Increase job timeout and add explicit timeout directives
- Check for interactive prompts blocking execution (e.g., `apt install` without `-y`)

## Runner / Agent Unavailable

**Symptom:** `No matching runner found` or `Waiting for next available executor`

**Diagnosis:**
1. Check runner registration: `gitlab-runner list` or Jenkins node status
2. Verify runner tags match job requirements
3. Check runner service status
4. Ensure runner has network access to the CI server

**Fix:**
```bash
# Re-register GitLab runner
gitlab-runner register

# Restart runner service
sudo systemctl restart gitlab-runner

# Jenkins: reconnect agent from Manage Nodes page
```

## Cache Miss

**Symptom:** Build is slow, dependencies re-downloaded every time

**Diagnosis:**
1. Verify cache key configuration matches expectations
2. Check cache storage backend (S3, GCS, local) accessibility
3. Verify cache has not expired
4. Check for cache key collisions

**Fix:**
```yaml
# GitLab CI example - use proper cache key
cache:
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - node_modules/
    - .pip-cache/
```

## Artifact Too Large

**Symptom:** `artifact upload failed` or storage quota exceeded

**Diagnosis:**
1. Check artifact size limits in CI configuration
2. Review what is being included in artifacts
3. Check storage quota

**Fix:**
- Use `.gitignore`-style patterns to exclude unnecessary files
- Compress artifacts before upload
- Increase artifact size limit in CI server settings
- Use external storage (S3) for large artifacts

## Secret Not Available

**Symptom:** Empty environment variable, `secret not found`, authentication failures in pipeline

**Diagnosis:**
1. Verify secret is defined in CI/CD settings
2. Check secret scope (environment, branch protection)
3. Verify secret name matches (case-sensitive)
4. Check if secret is masked and cannot be printed

**Fix:**
- Re-add the secret in CI/CD variables settings
- Ensure protected secrets are only used on protected branches
- Check for typos in variable names
- Verify secret has not expired (for rotating credentials)

## Timeout During Build

**Symptom:** `Job exceeded maximum execution time`

**Diagnosis:**
1. Check default timeout settings
2. Identify which step is slow
3. Check for network issues during dependency download
4. Look for infinite loops or hanging processes

**Fix:**
```yaml
# Increase timeout
job:
  timeout: 2h

# Or optimize the slow step
# - Use caching for dependencies
# - Parallelize test execution
# - Use smaller base images
```

## OOM (Out of Memory) During Build

**Symptom:** `Killed`, exit code 137, `JavaScript heap out of memory`

**Diagnosis:**
1. Check container/VM memory limits
2. Monitor memory usage during build
3. Identify memory-hungry steps

**Fix:**
```bash
# Node.js: increase heap size
export NODE_OPTIONS="--max-old-space-size=4096"

# Docker: increase memory limit
docker run --memory=4g ...

# Use resource classes with more RAM
# Or split build into smaller parallel jobs
```
