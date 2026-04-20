# Chaos Engineering Guide

OTTO includes a chaos engineering assistant that lets you run controlled experiments to validate system resilience in Kubernetes environments.

> **Maturity: Experimental** - Chaos engineering features work for basic experiments but some experiment types require manual setup.

## What is Chaos Engineering?

Chaos engineering deliberately injects failures into a system to verify that it can tolerate unexpected conditions. Instead of waiting for production incidents, you proactively test resilience in controlled environments.

## Available Experiments

| Experiment | Description | Risk Level | Status |
|-----------|-------------|------------|--------|
| `pod-kill` | Kill a random pod matching a label selector | Low | Fully automated |
| `network-delay` | Inject network latency on a service (requires `tc` in container) | Medium | Fully automated |
| `cpu-stress` | Stress CPU cores on a target pod | Medium | Fully automated |
| `disk-fill` | Fill disk on a target pod to test pressure handling | High | Requires manual setup |
| `node-drain` | Drain a Kubernetes node to test pod rescheduling | High | Requires manual setup |

## Safety Mechanisms

OTTO enforces multiple safety checks before running any chaos experiment:

1. **Permission check** - Chaos experiments require at least `suggest` permission level. Configure in your permissions settings.
2. **Production restriction** - Experiments are blocked in `production` and `prod` namespaces by default.
3. **Steady-state validation** - Before the experiment, OTTO checks that all pods are healthy and all deployments have their desired replicas.
4. **Post-experiment validation** - After the experiment, OTTO waits 10 seconds and then validates that the system recovered to steady state.

### Enabling Production Chaos (Use with Extreme Caution)

To allow chaos experiments in production namespaces, add to `~/.config/otto/config.yaml`:

```yaml
chaos:
  allow_production: true
```

This is strongly discouraged unless you have a mature chaos engineering practice with proper blast radius controls.

## Running an Experiment

### Step 1: List available experiments

```bash
# Via the chaos-assistant script
source scripts/core/chaos-assistant.sh
chaos_list_experiments
```

Output:
```json
[
  {"name": "pod-kill", "description": "Kill a random pod matching a label selector", "risk": "low"},
  {"name": "network-delay", "description": "Inject network latency on a service (requires tc)", "risk": "medium"},
  {"name": "cpu-stress", "description": "Stress CPU on a target pod", "risk": "medium"},
  {"name": "disk-fill", "description": "Fill disk on a target pod to test pressure handling", "risk": "high"},
  {"name": "node-drain", "description": "Drain a Kubernetes node to test pod rescheduling", "risk": "high"}
]
```

### Step 2: Run the experiment

```bash
# chaos_run <experiment> <target> <namespace> <duration_seconds>
chaos_run pod-kill "app=myservice" staging 60
```

OTTO will:
1. Check permissions
2. Verify the namespace is not production (unless configured)
3. Validate steady state (all pods healthy, all deployments at desired replicas)
4. Execute the experiment
5. Wait for stabilization
6. Validate steady state again
7. Generate a report

### Step 3: Review the report

The experiment report is stored as JSON in `~/.config/otto/state/chaos/<experiment-id>.json` and printed after the experiment:

```json
{
  "id": "20260417-143022-12345",
  "experiment": "pod-kill",
  "target": "app=myservice",
  "namespace": "staging",
  "duration": "60",
  "status": "completed",
  "timestamp": "2026-04-17T14:30:22Z",
  "report": {
    "summary": "Chaos experiment pod-kill on app=myservice in staging: completed",
    "recommendation": "System recovered successfully. Resilience validated."
  }
}
```

## Experiment Details

### pod-kill

Selects a random pod matching the given label selector and force-deletes it with zero grace period.

```bash
chaos_run pod-kill "app=frontend" staging 60
```

What to observe: Does the ReplicaSet recreate the pod? Does the service remain available during the gap? How long does recovery take?

### network-delay

Injects network latency using `tc` (traffic control) inside the target pod. Requires `tc` to be available in the container.

```bash
chaos_run network-delay "myservice" staging 120
```

The delay defaults to 200ms. To clean up manually:
```bash
kubectl exec -n staging <pod-name> -- tc qdisc del dev eth0 root
```

### cpu-stress

Runs CPU-intensive processes on the target pod for the specified duration.

```bash
chaos_run cpu-stress "mypod-abc123" staging 60
```

What to observe: Do HPA autoscalers kick in? Do health checks still pass? Does the pod get OOMKilled?

## Integration with Night Watcher

If Night Watcher is active during a chaos experiment, it will detect the injected failures and report them. This is actually useful -- it validates that your monitoring and alerting pipeline catches real issues.

Run experiments during a Night Watcher session to verify:
- Alerts fire within expected timeframes
- Alert severity matches the failure type
- Auto-remediation kicks in appropriately (or doesn't for expected chaos)

## Best Practices

- **Start in staging.** Never run your first chaos experiment in production.
- **Start small.** Begin with `pod-kill` (low risk) before trying network or CPU experiments.
- **Have rollback ready.** Know how to undo each experiment before starting.
- **Run during business hours.** Have your team available to respond if something goes wrong.
- **Document your hypotheses.** Before running an experiment, write down what you expect to happen.
- **Review results as a team.** Share chaos experiment reports in your team retrospectives.
- **Gradually increase scope.** Once a service passes pod-kill, try network-delay, then cpu-stress.

## Gotchas

- `network-delay` requires the `tc` command inside the container. Most minimal container images don't include it. You may need to add `iproute2` to your container.
- `cpu-stress` runs in the background. If the pod is killed or restarted, the stress stops automatically.
- `disk-fill` and `node-drain` are not fully automated and will log a warning asking for manual setup.
- Experiment state is stored in `~/.config/otto/state/chaos/`. Clean up old experiment files periodically.
