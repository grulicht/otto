# Kubernetes Integration

## Prerequisites
- `kubectl` configured with cluster access
- `helm` for Helm chart operations (optional)
- `velero` for backup operations (optional)

## Auto-Detection
OTTO automatically detects kubectl and reads your kubeconfig to determine
available clusters and contexts.

## What OTTO Can Do

### Monitoring
- List and describe pods, deployments, services, nodes
- Check pod health and restart counts
- Monitor resource usage (CPU, memory)
- Watch for warning events

### Troubleshooting
- Diagnose CrashLoopBackOff, ImagePullBackOff, Pending pods
- Analyze container logs
- Check resource limits and requests
- Verify network policies and service connectivity

### Management (with permission)
- Apply manifests (confirm mode)
- Scale deployments (confirm mode)
- Rollback deployments (confirm mode)
- Restart deployments (confirm mode)

### Helm
- List releases
- Review chart values
- Upgrade/rollback releases (confirm mode)

### Security
- Review RBAC configuration
- Check Pod Security Standards compliance
- Audit network policies

## Permission Mapping

| Action | Default Level |
|--------|--------------|
| get/describe/logs | auto |
| scale | confirm |
| apply | confirm |
| delete | deny |
| exec | confirm |
| rollback | confirm |

## Example Usage
```bash
otto check kubernetes    # Run K8s health check
otto task "fix crashloopbackoff in production namespace"
```
