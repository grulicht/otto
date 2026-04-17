---
name: github
description: GitHub via gh CLI for repositories, PRs, issues, actions, and releases
type: cli
required_env: []
required_tools:
  - gh
  - jq
check_command: "gh auth status"
---

# GitHub

## Connection

OTTO connects to GitHub through the `gh` CLI, which handles authentication
via `gh auth login`. No separate environment variables are needed when `gh`
is already authenticated.

For GitHub Enterprise, set `GH_HOST` to the enterprise hostname.

```bash
gh auth status          # verify authentication
gh auth login           # interactive login
gh auth login --with-token < token.txt  # token-based login
```

## Available Data

- **Repositories**: List, create, clone, and manage repos
- **Pull Requests**: Create, list, review, merge, and check PRs
- **Issues**: Create, list, update, close, and label issues
- **Actions**: List workflow runs, view logs, re-run failed workflows
- **Releases**: List and create releases
- **Gists**: Manage code snippets
- **Checks**: View check suite results and annotations
- **Discussions**: List and manage repository discussions
- **Codespaces**: Manage development environments
- **Security**: View Dependabot alerts and code scanning results

## Common Queries

### List open PRs
```bash
gh pr list --state=open --limit=20
```

### View PR details and checks
```bash
gh pr view <number>
gh pr checks <number>
```

### List recent workflow runs
```bash
gh run list --limit=10
gh run view <run-id> --log-failed
```

### Re-run a failed workflow
```bash
gh run rerun <run-id> --failed
```

### List open issues
```bash
gh issue list --state=open --limit=20
```

### Search across repos
```bash
gh search repos "topic:devops language:go"
gh search issues "label:bug state:open"
```

### View Dependabot alerts
```bash
gh api repos/{owner}/{repo}/dependabot/alerts --jq '.[].security_advisory.summary'
```

### List releases
```bash
gh release list --limit=5
```
