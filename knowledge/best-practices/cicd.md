# CI/CD Best Practices

## Pipeline Design
- Keep pipelines fast (under 10 minutes for CI, under 30 for full CD)
- Fail fast - run linting and unit tests first
- Use parallel stages where possible
- Cache dependencies between runs
- Use matrix builds for multi-platform/version testing

## Build Artifacts
- Build once, deploy many (same artifact across environments)
- Tag artifacts with git SHA and semantic version
- Store artifacts in a dedicated registry
- Sign artifacts for integrity verification
- Clean up old artifacts regularly

## Testing
- Unit tests in CI, integration tests in staging
- Gate deployments on test results
- Use test coverage thresholds (don't decrease)
- Run security scanning (SAST, dependency audit) in pipeline

## Deployment Strategies
- Blue-green: zero-downtime, instant rollback
- Canary: gradual rollout, early problem detection
- Rolling: incremental update, resource efficient
- Feature flags: decouple deployment from release

## Secrets in CI/CD
- Use CI/CD platform's secret management (not env vars in code)
- Rotate CI/CD secrets regularly
- Limit secret access to specific pipeline stages
- Never print secrets in logs

## GitOps
- Infrastructure and app config in Git (single source of truth)
- Pull-based deployments (ArgoCD, Flux)
- Automated drift detection and reconciliation
- Separate config repos from application repos

## Monitoring
- Alert on pipeline failures
- Track deployment frequency, lead time, failure rate (DORA metrics)
- Log all deployments with who/what/when/where
