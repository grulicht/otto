# Blue-Green Deployment Pattern

## Concept
Maintain two identical production environments (blue and green).
At any time, only one serves live traffic. Deployments go to the
inactive environment, which then becomes active via traffic switch.

## How It Works

```
1. Blue (LIVE) <-- traffic     Green (IDLE)
2. Blue (LIVE) <-- traffic     Green (deploying new version)
3. Blue (LIVE) <-- traffic     Green (testing new version)
4. Blue (idle)                 Green (LIVE) <-- traffic switched
5. Blue (ready for rollback)   Green (LIVE) <-- traffic
```

## Advantages
- Zero-downtime deployment
- Instant rollback (switch traffic back)
- Full testing of production environment before going live
- Simple to understand and implement

## Disadvantages
- Requires double the infrastructure (cost)
- Database migrations require extra care
- Stateful applications are complex to manage

## Implementation

### Kubernetes
- Two Deployments with different labels
- Service selector points to active environment
- Switch by updating Service selector

### Cloud (AWS)
- Two Auto Scaling Groups behind an ALB
- Switch by updating Target Group weights
- Or use Route53 weighted routing

### Database Considerations
- Schema changes must be backward compatible
- Run migrations before switching traffic
- Consider expand-contract pattern for breaking changes
