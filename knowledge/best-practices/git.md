# Git Best Practices
tags: git, version-control, branching, workflow

## Branching Strategies

### Git Flow
- `main` -- production-ready code
- `develop` -- integration branch
- `feature/*` -- new features
- `release/*` -- release preparation
- `hotfix/*` -- production fixes

### Trunk-Based Development (recommended for CI/CD)
- Single `main` branch
- Short-lived feature branches (< 2 days)
- Feature flags for incomplete work
- Continuous integration to main

### GitHub Flow
- `main` is always deployable
- Feature branches from main
- Pull requests for review
- Merge to main triggers deploy

## Commit Messages

Follow Conventional Commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`

```
feat(auth): add OAuth2 login support

Implement Google and GitHub OAuth2 providers using passport.js.
Includes session management and token refresh logic.

Closes #142
```

Rules:
- Subject line max 72 characters
- Use imperative mood ("add" not "added")
- Separate subject from body with blank line
- Explain *why*, not *what* (the diff shows what)

## Pull Request Workflow

- Keep PRs small and focused (< 400 lines changed)
- Write descriptive PR titles and descriptions
- Link to related issues
- Request reviews from relevant team members
- Use PR templates for consistency
- Require at least one approval before merge
- Use squash merge for clean history, or merge commit for preserving context
- Delete branch after merge

## .gitignore

- Start with a language/framework-specific template (gitignore.io)
- Always exclude: `.env`, credentials, secrets, IDE files, build artifacts
- Use global gitignore for personal IDE preferences: `git config --global core.excludesfile ~/.gitignore_global`
- Never commit large binary files

```gitignore
# Common ignores
.env
.env.*
*.log
node_modules/
__pycache__/
.terraform/
*.tfstate*
.vagrant/
*.pem
*.key
```

## Git Hooks

Use pre-commit framework for consistent hooks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: detect-private-key

  - repo: https://github.com/commitizen-tools/commitizen
    rev: v3.13.0
    hooks:
      - id: commitizen
```

Useful hooks:
- **pre-commit:** lint, format, secret detection
- **commit-msg:** validate conventional commit format
- **pre-push:** run tests

## GPG Signing

Sign commits to verify author identity:

```bash
# Generate GPG key
gpg --full-generate-key

# Configure git
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true

# Add public key to GitHub/GitLab
gpg --armor --export <KEY_ID>
```

## Large File Handling

- Use Git LFS for files > 1MB (images, binaries, datasets)
- Never commit build artifacts or dependencies
- Use `.gitattributes` for LFS tracking

```bash
# Install and configure LFS
git lfs install
git lfs track "*.psd"
git lfs track "*.zip"
git add .gitattributes
```
