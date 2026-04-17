# Deployment Rollback Runbook

## When to Rollback
- Increased error rate after deployment
- Health checks failing
- Critical functionality broken
- Performance degradation beyond acceptable thresholds

## Kubernetes Rollback

### Deployment
```bash
# Check rollout status
kubectl rollout status deployment/<name> -n <namespace>

# View revision history
kubectl rollout history deployment/<name> -n <namespace>

# Rollback to previous revision
kubectl rollout undo deployment/<name> -n <namespace>

# Rollback to specific revision
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=<N>

# Verify rollback
kubectl get pods -n <namespace> -l app=<name>
kubectl rollout status deployment/<name> -n <namespace>
```

### Helm
```bash
# List releases
helm history <release> -n <namespace>

# Rollback to previous
helm rollback <release> -n <namespace>

# Rollback to specific revision
helm rollback <release> <revision> -n <namespace>
```

### ArgoCD
```bash
# Rollback via CLI
argocd app rollback <app-name>

# Or revert Git commit and let ArgoCD sync
git revert <commit-sha>
git push
```

## CI/CD Pipeline Rollback
1. Identify last known good build/artifact
2. Re-deploy that artifact (don't rebuild from old code)
3. If using GitOps: revert the config change in Git

## Post-Rollback
1. Verify service is healthy
2. Notify team about rollback
3. Investigate root cause of the failed deployment
4. Create post-mortem if user-facing impact occurred
