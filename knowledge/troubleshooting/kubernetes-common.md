# Kubernetes Common Issues

## CrashLoopBackOff
**Symptoms:** Pod repeatedly crashes and restarts.
**Steps:**
1. `kubectl logs <pod> --previous` - check crash logs
2. `kubectl describe pod <pod>` - check events, exit codes
3. Common causes: wrong command/entrypoint, missing config/secrets, OOMKilled, failing health checks
4. Fix: check container args, resource limits, readiness/liveness probes

## ImagePullBackOff
**Symptoms:** Pod stuck in ImagePullBackOff/ErrImagePull.
**Steps:**
1. `kubectl describe pod <pod>` - check image name and pull errors
2. Verify image exists: `docker pull <image>`
3. Check registry credentials: `kubectl get secret -n <ns>`
4. Common causes: typo in image name, missing imagePullSecret, private registry auth

## Pending Pods
**Symptoms:** Pod stays in Pending state.
**Steps:**
1. `kubectl describe pod <pod>` - check events
2. `kubectl get nodes` - check node capacity
3. Common causes: insufficient resources, node affinity/taint mismatch, PVC not bound
4. Fix: add nodes, adjust requests, fix affinity rules, check StorageClass

## OOMKilled
**Symptoms:** Container killed with exit code 137, reason OOMKilled.
**Steps:**
1. `kubectl describe pod <pod>` - confirm OOMKilled
2. Check actual memory usage vs limits
3. Fix: increase memory limits or fix memory leak in application

## Service Not Reachable
**Symptoms:** Cannot connect to a service.
**Steps:**
1. `kubectl get svc` - verify service exists and has endpoints
2. `kubectl get endpoints <svc>` - check if pods are selected
3. `kubectl exec <pod> -- curl <svc>:<port>` - test from within cluster
4. Check: label selectors match, port numbers correct, NetworkPolicy allows traffic

## Node NotReady
**Symptoms:** Node shows NotReady status.
**Steps:**
1. `kubectl describe node <node>` - check conditions
2. SSH to node, check: kubelet status, disk space, memory, Docker/containerd
3. `journalctl -u kubelet` - check kubelet logs
4. Common causes: disk pressure, memory pressure, kubelet crash, network issues
