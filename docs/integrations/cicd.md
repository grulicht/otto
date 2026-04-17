# CI/CD Integrations

## GitLab CI

### Setup
```bash
OTTO_GITLAB_URL=https://gitlab.example.com
OTTO_GITLAB_TOKEN=your-personal-access-token
```
Or use the `glab` CLI (auto-detected).

### Capabilities
- View and debug pipeline status
- Lint .gitlab-ci.yml files
- Analyze job logs for errors
- Trigger/retry/cancel pipelines (with permission)
- Review merge requests

## GitHub Actions

### Setup
Use `gh` CLI (auto-detected). Authenticate with `gh auth login`.

### Capabilities
- View workflow run status
- Debug failing Actions
- Generate workflow YAML files
- Manage repository secrets (with permission)
- Review pull requests

## Jenkins

### Setup
Requires `jenkins-cli.jar` or API access.

### Capabilities
- View job status and build logs
- Lint Jenkinsfiles
- Trigger builds (with permission)
- Analyze build failure patterns

## ArgoCD

### Setup
Use `argocd` CLI. Authenticate with `argocd login`.

### Capabilities
- View application sync status
- Diff desired vs live state
- Sync/rollback applications (with permission)
- Manage application definitions

## Bitbucket Pipelines

### Setup
```bash
OTTO_BITBUCKET_USER=your-username
OTTO_BITBUCKET_TOKEN=your-app-password
```

### Capabilities
- View pipeline status
- Manage pipeline configuration
- Review pull requests

## Azure DevOps Pipelines

### Setup
Use `az devops` CLI extension.

### Capabilities
- View pipeline runs
- Manage variable groups
- Trigger/monitor builds
