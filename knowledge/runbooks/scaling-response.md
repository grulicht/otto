# Scaling Response Runbook
tags: scaling, autoscaling, HPA, kubernetes, cloud, database, capacity

## Overview
When and how to scale infrastructure in response to load changes, covering Kubernetes HPA, manual scaling, cloud auto-scaling, and database scaling.

## Step 1: Identify Scaling Need

```bash
# Check current resource utilization
kubectl top pods -n <namespace>
kubectl top nodes

# Check HPA status
kubectl get hpa -n <namespace>
kubectl describe hpa <name> -n <namespace>

# Check application metrics
# - Request latency increasing
# - Error rate increasing
# - Queue depth growing
# - CPU/memory utilization above 70-80%
```

## Step 2: Kubernetes HPA Tuning

### Current HPA Status
```bash
# Check HPA details and events
kubectl describe hpa <name> -n <namespace>

# Check metrics availability
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

### HPA Configuration
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 20
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### HPA Tuning Tips
- Target CPU 60-70% to leave room for spikes
- Use `stabilizationWindowSeconds` to prevent flapping (300s for scale-down)
- Set `behavior.scaleDown` conservatively to avoid premature scale-down
- Use custom metrics (requests/sec, queue depth) for more accurate scaling
- Ensure resource requests are accurate - HPA uses requests as the baseline

## Step 3: Manual Scaling (Emergency)

```bash
# Scale deployment immediately
kubectl scale deployment <name> -n <namespace> --replicas=<count>

# Verify pods are starting
kubectl get pods -n <namespace> -w

# Check if nodes have capacity
kubectl describe nodes | grep -A5 "Allocated resources"

# If nodes are full, scale the node pool
# AWS EKS:
aws eks update-nodegroup-config --cluster-name <cluster> --nodegroup-name <ng> --scaling-config minSize=3,maxSize=10,desiredSize=6

# GCP GKE:
gcloud container clusters resize <cluster> --node-pool <pool> --num-nodes=6
```

## Step 4: Cloud Auto-Scaling

### AWS Auto Scaling Group
```bash
# Check current ASG
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <asg>

# Update capacity
aws autoscaling update-auto-scaling-group --auto-scaling-group-name <asg> \
  --min-size 2 --max-size 10 --desired-capacity 4

# Check scaling activities
aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg>
```

### Best Practices
- Use predictive scaling for known patterns (daily/weekly cycles)
- Set appropriate cooldown periods (300s default)
- Use target tracking policies over step scaling
- Monitor ASG events for launch failures
- Use mixed instance types for cost optimization and availability

## Step 5: Database Scaling

### Vertical Scaling (Scale Up)
```bash
# PostgreSQL/MySQL on RDS
aws rds modify-db-instance --db-instance-identifier <id> --db-instance-class db.r6g.xlarge --apply-immediately

# Note: this causes downtime (use Multi-AZ for minimal impact)
```

### Horizontal Scaling (Read Replicas)
```bash
# Create read replica
aws rds create-db-read-replica --db-instance-identifier <replica-id> --source-db-instance-identifier <primary-id>

# Route read traffic to replicas in application
# Use connection pooler (PgBouncer) with read/write splitting
```

### Connection Pooling
- Deploy PgBouncer for PostgreSQL, ProxySQL for MySQL
- Use transaction-level pooling for most workloads
- Set pool size based on: backend connections = CPU cores * 2 + effective_spindle_count
- Monitor pool saturation and wait times

### Redis Scaling
```bash
# Add shards to Redis cluster
redis-cli --cluster add-node <new-node>:<port> <existing-node>:<port>
redis-cli --cluster reshard <existing-node>:<port>

# Add replicas
redis-cli --cluster add-node <new-node>:<port> <master-node>:<port> --cluster-slave
```

## Step 6: Post-Scaling Validation

```bash
# Verify new capacity is healthy
kubectl get pods -n <namespace> -o wide
kubectl top pods -n <namespace>

# Check application health
curl -s <health-endpoint> | jq .

# Verify load distribution
# Check load balancer target health
# Monitor error rates and latency

# Verify HPA metrics are accurate
kubectl get hpa -n <namespace> -w
```

## Decision Matrix

| Signal | Action | Urgency |
|--------|--------|---------|
| CPU > 90% sustained | Scale up immediately | High |
| CPU 70-90% | Tune HPA, increase max replicas | Medium |
| Memory > 85% | Scale up or fix memory leak | High |
| Latency P99 > SLO | Scale up, check bottlenecks | High |
| Queue depth growing | Scale consumers | Medium |
| Disk > 80% | Expand volume, clean up | Medium |
| Connection pool exhausted | Add replicas or pooler | High |
