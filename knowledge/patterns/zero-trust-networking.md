# Zero Trust Networking Pattern

## Principles
- **Never trust, always verify** - no implicit trust based on network location
- **Least privilege access** - grant minimum permissions needed for each request
- **Assume breach** - design as if attackers are already inside the network
- **Verify explicitly** - authenticate and authorize every request
- **Encrypt everything** - all traffic encrypted regardless of network segment

## Identity Verification
- Authenticate every service-to-service call (mutual TLS, JWT, SPIFFE/SPIRE)
- Use short-lived credentials (certificates valid for hours, not years)
- Implement service identity via service mesh (Istio, Linkerd)
- Tie identity to workload, not network location or IP address
- Use OIDC/SAML for human authentication with MFA required

## Micro-Segmentation
- Replace flat networks with fine-grained network policies
- Default deny all traffic, explicitly allow required paths
- Kubernetes NetworkPolicies for pod-to-pod control
- Cloud security groups scoped to individual services
- Use service mesh for L7 policy enforcement (HTTP method, path, headers)

### Example Kubernetes NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
spec:
  podSelector:
    matchLabels:
      app: api-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - port: 5432
```

## Least Privilege
- Service accounts with minimal permissions per service
- RBAC scoped to specific resources and operations
- Time-bound access for administrative operations
- No standing privileges - use just-in-time access (Teleport, Boundary)
- Separate read and write roles for data services

## Continuous Verification
- Re-authenticate on every request, not just at session start
- Monitor for anomalous behavior (unusual API calls, data volumes, timing)
- Implement adaptive authentication (step-up auth for sensitive operations)
- Log and audit all access decisions for forensics
- Use context-aware policies (device posture, location, time of day)

## Encryption Everywhere
- Mutual TLS (mTLS) for all service-to-service communication
- Encrypt data at rest (volume encryption, database TDE)
- Use separate encryption keys per tenant/service
- Rotate keys automatically (cert-manager, Vault)
- No plaintext secrets in environment variables or config files

## Implementation with Service Mesh

### Istio
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: api-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-server
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/frontend"]
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/*"]
```

## Monitoring and Detection
- Log all authentication and authorization decisions
- Alert on authentication failures from service identities
- Monitor certificate expiration and rotation
- Track lateral movement patterns
- Use network flow logs to detect unexpected communication paths
- Integrate with SIEM for correlation and alerting
