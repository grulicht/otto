# Kubernetes Best Practices

## Resource Management
- Always set resource requests and limits for containers
- Use LimitRange and ResourceQuota for namespace-level controls
- Request:Limit ratio should be close to 1:1 for predictable performance

## Pod Security
- Never run containers as root (use securityContext.runAsNonRoot: true)
- Use read-only root filesystem where possible
- Drop all capabilities and add only what's needed
- Use Pod Security Standards (restricted profile for production)

## Health Checks
- Always define readinessProbe and livenessProbe
- Use startupProbe for slow-starting containers
- Liveness probes should check the process, not dependencies
- Readiness probes should check if the pod can serve traffic

## Labels and Annotations
- Use standard labels: app.kubernetes.io/name, version, component, part-of
- Label everything for consistent filtering and selection
- Use annotations for non-identifying metadata

## Networking
- Use NetworkPolicies to restrict pod-to-pod communication
- Default deny all ingress/egress, then allow what's needed
- Use Services for internal communication, never pod IPs directly

## Storage
- Use PersistentVolumeClaims, not hostPath
- Set appropriate StorageClass and reclaim policies
- Use volumeClaimTemplates for StatefulSets

## Deployments
- Use Deployments for stateless apps, StatefulSets for stateful
- Set PodDisruptionBudgets for high-availability workloads
- Use rolling update strategy with maxSurge and maxUnavailable
- Set terminationGracePeriodSeconds appropriately

## Namespace Organization
- Separate environments by namespaces
- Use namespace-level RBAC
- Apply resource quotas per namespace

## Common Troubleshooting
- CrashLoopBackOff: check logs, resource limits, health probes
- ImagePullBackOff: check image name, registry auth, network
- Pending pods: check node resources, affinity rules, PVC binding
- OOMKilled: increase memory limits, check for memory leaks
