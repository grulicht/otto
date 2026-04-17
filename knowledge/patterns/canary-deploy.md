# Canary Deployment Pattern

## Concept
Gradually roll out a new version to a small subset of users/traffic
before rolling it out to the entire production. Monitor for issues
at each stage, roll back if problems detected.

## Stages

```
Stage 1:  [new: 5%]  [old: 95%]    <- initial canary
Stage 2:  [new: 25%] [old: 75%]    <- if metrics OK
Stage 3:  [new: 50%] [old: 50%]    <- if metrics OK
Stage 4:  [new: 100%]              <- full rollout
```

## Key Metrics to Watch
- Error rate (should not increase)
- Latency (p50, p95, p99)
- Success rate of key transactions
- Resource usage (CPU, memory)
- Business metrics (conversions, signups)

## Implementation

### Kubernetes (native)
```yaml
# Canary Deployment (small replica count)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
spec:
  replicas: 1  # small fraction
```
Both deployments share the same Service selector.

### Kubernetes (Istio)
Use VirtualService traffic splitting:
```yaml
- route:
  - destination:
      host: myapp
      subset: stable
    weight: 95
  - destination:
      host: myapp
      subset: canary
    weight: 5
```

### ArgoCD Rollouts
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
      - setWeight: 5
      - pause: {duration: 10m}
      - setWeight: 25
      - pause: {duration: 10m}
      - setWeight: 50
      - pause: {duration: 10m}
```

## Automated Canary Analysis
Use tools like Kayenta (Spinnaker) or Flagger to automatically
compare canary metrics against baseline and promote/rollback.
