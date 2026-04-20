# CI/CD Pipeline Design Patterns

## Concept

Continuous Integration and Continuous Delivery/Deployment pipelines automate the
path from code commit to production deployment. Good pipeline design balances
speed, safety, and developer experience.

## Branching Strategies

### Trunk-Based Development
- All developers commit to `main` (trunk) frequently (at least daily)
- Short-lived feature branches (< 2 days) or direct commits
- Feature flags hide incomplete work from users
- Best for: high-trust teams, microservices, continuous deployment
- Requires: strong test suite, feature flags, CI that runs in minutes

### Feature Branching (GitHub Flow)
- Create branch per feature/fix from `main`
- Open pull request when ready for review
- Merge to `main` after approval and passing CI
- Deploy from `main` (continuously or on schedule)
- Best for: most teams, moderate complexity

### GitFlow
- Long-lived `develop` and `main` branches
- Feature branches from `develop`, release branches for stabilization
- Hotfix branches from `main` for urgent production fixes
- Best for: packaged software with versioned releases
- Drawback: complex, slow, merge-heavy

## Environment Promotion

```
Build -> Dev -> Staging -> Production
```

**Principles:**
- Build artifact once, deploy same artifact everywhere
- Promote the artifact, not the code (no rebuilding per environment)
- Environment-specific config injected at deploy time (env vars, config maps)
- Each promotion gate can include: automated tests, manual approval, canary analysis

## Artifact Management

- Store build artifacts in a registry (Docker Hub, ECR, Artifactory, Nexus)
- Tag artifacts with commit SHA and semantic version
- Immutable tags: never overwrite a published artifact
- Retention policy: keep last N releases, clean up old artifacts
- Sign artifacts for provenance (cosign, Notary)

## Test Pyramid in CI

```
         /  E2E Tests  \        <- Few, slow, flaky
        / Integration    \      <- Moderate count
       /   Unit Tests      \    <- Many, fast, reliable
```

**Pipeline stages:**
1. **Lint + Static Analysis**: Fastest, catch formatting and code smells
2. **Unit Tests**: Fast, run on every commit
3. **Integration Tests**: Test service interactions, run on PR
4. **E2E Tests**: Full system tests, run before production deploy
5. **Security Scan**: SAST, dependency audit, container scan

**Key:** Keep the feedback loop fast. Unit tests should complete in < 2 minutes.

## Pipeline-as-Code

Define pipelines in version-controlled files alongside the code.

**Tools and formats:**
- GitHub Actions: `.github/workflows/*.yml`
- GitLab CI: `.gitlab-ci.yml`
- Jenkins: `Jenkinsfile` (Groovy)
- Azure DevOps: `azure-pipelines.yml`
- CircleCI: `.circleci/config.yml`
- Tekton: Kubernetes-native pipeline CRDs

**Best practices:**
- Use reusable workflows/templates for shared logic
- Pin action/image versions (avoid `@latest`)
- Keep pipeline config DRY with anchors, templates, or composite actions
- Store pipeline config in the same repo as the code it builds

## Security Gates

Integrate security checks into the pipeline to shift left.

**Stages:**
1. **Pre-commit**: Secret scanning (gitleaks), linting
2. **Build**: SAST (Semgrep, SonarQube), dependency audit (Snyk, Dependabot)
3. **Post-build**: Container image scanning (Trivy, Grype)
4. **Pre-deploy**: DAST (OWASP ZAP), infrastructure policy (OPA, Kyverno)
5. **Post-deploy**: Runtime security monitoring (Falco)

**Policy:** Define which severity levels block deployment vs. warn.

## Deployment Approval Workflows

Control who can deploy to which environments.

**Patterns:**
- **Automated**: Dev and staging deploy on merge (no approval needed)
- **Manual gate**: Production requires explicit approval in CI/CD UI
- **CODEOWNERS**: Specific teams must approve changes to specific paths
- **Scheduled**: Deploy to production only during business hours
- **Progressive**: Canary to 5% -> monitor -> promote to 100%

**Implementation:**
- GitHub Actions: `environment` with required reviewers
- GitLab CI: `when: manual` with protected environments
- ArgoCD: sync policy with manual sync for production

## Pipeline Optimization

- **Caching**: Cache dependencies (npm, pip, Maven) between runs
- **Parallelism**: Run independent test suites concurrently
- **Incremental builds**: Only rebuild changed components (monorepo tools: Nx, Turborepo, Bazel)
- **Skip conditions**: Skip CI for docs-only changes
- **Self-hosted runners**: Faster builds, cached Docker layers, private network access
- **Pipeline metrics**: Track build duration, failure rate, MTTR
