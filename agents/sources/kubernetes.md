---
name: kubernetes
description: Kubernetes cluster management via kubectl CLI
type: cli
required_env: []
required_tools:
  - kubectl
  - jq
check_command: "kubectl cluster-info --request-timeout=5s 2>/dev/null | head -1"
---

# Kubernetes

## Connection

OTTO connects to Kubernetes through `kubectl`, which reads its configuration
from `~/.kube/config` or the path set in `KUBECONFIG`. Multiple clusters
and contexts are supported.

```bash
kubectl config current-context        # show current context
kubectl config get-contexts            # list all available contexts
kubectl config use-context <name>      # switch context
```

For in-cluster operation (running inside a pod), `kubectl` automatically
uses the service account token.

## Available Data

- **Workloads**: Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, Pods
- **Services**: Services, Ingresses, Endpoints, NetworkPolicies
- **Config**: ConfigMaps, Secrets, ServiceAccounts
- **Storage**: PersistentVolumes, PersistentVolumeClaims, StorageClasses
- **Cluster**: Nodes, Namespaces, ResourceQuotas, LimitRanges
- **Events**: Cluster events and warnings
- **Custom Resources**: CRDs and their instances (e.g., ArgoCD Applications, Cert-Manager Certificates)
- **RBAC**: Roles, ClusterRoles, Bindings
- **Metrics**: Resource usage via metrics-server

## Common Queries

### Get cluster health overview
```bash
kubectl get nodes -o wide
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
```

### Check deployment status
```bash
kubectl -n <namespace> get deploy <name> -o json | jq '{
  replicas: .status.replicas,
  ready: .status.readyReplicas,
  updated: .status.updatedReplicas,
  available: .status.availableReplicas,
  conditions: [.status.conditions[] | {type, status, reason}]
}'
```

### Get pod logs
```bash
kubectl -n <namespace> logs <pod> --tail=100
kubectl -n <namespace> logs -l app=<label> --tail=50 --all-containers
```

### Get recent events
```bash
kubectl get events --all-namespaces --sort-by='.lastTimestamp' --field-selector=type=Warning | tail -20
```

### Check resource usage
```bash
kubectl top nodes
kubectl top pods -n <namespace> --sort-by=memory
```

### Describe problematic pods
```bash
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> get pods -o json | jq '[.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | {name: .metadata.name, phase: .status.phase, reason: (.status.containerStatuses // [] | .[0].state | to_entries[0].value.reason // "unknown")}]'
```

### List all ingresses
```bash
kubectl get ingress --all-namespaces -o json | jq '[.items[] | {namespace: .metadata.namespace, name: .metadata.name, hosts: [.spec.rules[].host]}]'
```
