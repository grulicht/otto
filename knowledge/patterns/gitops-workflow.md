# GitOps Workflow Pattern

## Concept
Git as the single source of truth for declarative infrastructure and application
configuration. Changes are made via Git commits, and an automated process
ensures the live state matches the desired state in Git.

## Architecture

```
Developer -> Git Commit -> Git Repository
                               |
                          GitOps Agent (ArgoCD/Flux)
                               |
                          Kubernetes Cluster
                               |
                          Drift Detection
                               |
                          Auto-Reconciliation
```

## Key Principles
1. **Declarative** - desired state described declaratively (YAML, HCL)
2. **Versioned** - all changes tracked in Git history
3. **Automated** - approved changes applied automatically
4. **Self-healing** - drift detected and corrected automatically

## Repository Structure
- **Mono-repo:** single repo for all environments (simpler, less isolation)
- **Multi-repo:** separate repos per environment/team (more isolation, more complexity)
- **App + Config separation:** application code in one repo, deployment config in another

## Implementation with ArgoCD
1. Install ArgoCD in management cluster
2. Create Application resources pointing to Git repos
3. Configure sync policies (auto-sync, self-heal, prune)
4. Use ApplicationSets for multi-cluster/multi-env

## Implementation with Flux
1. Bootstrap Flux in the cluster
2. Create GitRepository and Kustomization resources
3. Configure reconciliation intervals
4. Use HelmRelease for Helm-based deployments

## Best Practices
- Use pull-based model (agent pulls from Git, not CI pushes)
- Separate config repos from application code repos
- Use sealed-secrets or SOPS for secrets in Git
- Implement progressive delivery (canary, blue-green)
- Monitor sync status and alert on drift
