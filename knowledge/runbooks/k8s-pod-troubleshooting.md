# Kubernetes Pod Troubleshooting Runbook
tags: kubernetes, k8s, pod, troubleshooting, CrashLoopBackOff, ImagePullBackOff, Pending, OOMKilled, Evicted

## Overview
Step-by-step guide for diagnosing and resolving common Kubernetes pod issues.

## Step 1: Identify the Problem

```bash
# Get pod status
kubectl get pods -n <namespace> -o wide

# Describe the pod for events and conditions
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # previous container logs
```

## CrashLoopBackOff

**What it means:** The container starts, crashes, and Kubernetes restarts it repeatedly.

```bash
# Step 1: Check exit code and reason
kubectl describe pod <pod> -n <ns> | grep -A5 "Last State"

# Step 2: Check logs from crashed container
kubectl logs <pod> -n <ns> --previous

# Step 3: Check if it's a configuration issue
kubectl get pod <pod> -n <ns> -o yaml | grep -A20 "containers:"
```

**Common fixes:**
- Wrong command/entrypoint: check `command` and `args` in pod spec
- Missing ConfigMap/Secret: verify all referenced configs exist
- Failing health check: liveness probe may be too aggressive - increase `initialDelaySeconds`
- Application error: check application logs, environment variables
- Resource limits too low: container OOMKilled before startup completes

## ImagePullBackOff

**What it means:** Kubernetes cannot pull the container image.

```bash
# Step 1: Check the exact error
kubectl describe pod <pod> -n <ns> | grep -A5 "Events"

# Step 2: Verify image exists
docker pull <image>:<tag>

# Step 3: Check image pull secrets
kubectl get secrets -n <ns> | grep docker
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.imagePullSecrets}'
```

**Common fixes:**
- Typo in image name or tag
- Image tag does not exist (check registry)
- Missing `imagePullSecret` for private registry
- Registry authentication expired: recreate secret
- Network: node cannot reach registry (check DNS, firewall, proxy)

## Pending

**What it means:** Pod cannot be scheduled to any node.

```bash
# Step 1: Check scheduling events
kubectl describe pod <pod> -n <ns> | grep -A10 "Events"

# Step 2: Check node resources
kubectl describe nodes | grep -A5 "Allocated resources"
kubectl top nodes

# Step 3: Check taints and tolerations
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

**Common fixes:**
- Insufficient CPU/memory: reduce resource requests or add nodes
- Node selector/affinity mismatch: check `nodeSelector` and `affinity` rules
- Taint not tolerated: add toleration to pod spec
- PVC not bound: check PersistentVolumeClaim status and StorageClass
- Too many pods on nodes: check `maxPods` kubelet config

## OOMKilled

**What it means:** Container exceeded its memory limit and was killed by the kernel.

```bash
# Step 1: Confirm OOMKill
kubectl describe pod <pod> -n <ns> | grep -B2 "OOMKilled"

# Step 2: Check current memory usage
kubectl top pod <pod> -n <ns>

# Step 3: Check memory limits
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[*].resources}'
```

**Common fixes:**
- Increase memory limit in pod spec
- Investigate memory leak in application (heap dumps, profiling)
- Tune JVM heap size (`-Xmx`) for Java applications
- Add memory request = limit for guaranteed QoS class
- Check for unbounded caches or connection pools in application

## Evicted

**What it means:** Pod was evicted from the node due to resource pressure.

```bash
# Step 1: Check eviction reason
kubectl describe pod <pod> -n <ns> | grep -A3 "Status:"

# Step 2: Check node conditions
kubectl describe node <node> | grep -A5 "Conditions"

# Step 3: Check disk pressure
kubectl describe node <node> | grep -A2 "DiskPressure"
```

**Common fixes:**
- DiskPressure: clean up unused images (`crictl rmi --prune`), clean logs
- MemoryPressure: reduce pod memory usage, add nodes
- Set pod priority classes: critical pods survive eviction
- Set resource requests to give pods guaranteed QoS
- Configure `eviction-hard` thresholds on kubelet
- Use `PodDisruptionBudget` to limit simultaneous evictions

## General Tips

```bash
# Interactive debugging - run a shell in the pod
kubectl exec -it <pod> -n <ns> -- /bin/sh

# Run a debug container (K8s 1.23+)
kubectl debug -it <pod> -n <ns> --image=busybox

# Check events for the namespace
kubectl get events -n <ns> --sort-by='.lastTimestamp'

# Check resource quotas
kubectl get resourcequota -n <ns>
kubectl describe resourcequota -n <ns>
```
