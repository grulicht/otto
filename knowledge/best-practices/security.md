# Security Best Practices

## Secrets Management
- Never store secrets in code, config files, or environment variables in repos
- Use secret managers: HashiCorp Vault, AWS Secrets Manager, SOPS, Sealed Secrets
- Rotate secrets regularly (at least every 90 days)
- Use short-lived credentials where possible (IAM roles, service accounts)

## Access Control
- Follow principle of least privilege
- Use RBAC everywhere (Kubernetes, cloud IAM, database roles)
- Require MFA for all administrative access
- Review and audit permissions regularly
- Use separate accounts for different environments

## Network Security
- Default deny all, explicitly allow what's needed
- Use TLS/SSL for all communications
- Implement network segmentation
- Use Web Application Firewalls (WAF) for public-facing services
- Monitor for unusual network patterns

## Container Security
- Scan images for vulnerabilities before deployment
- Use minimal base images (distroless, Alpine)
- Run containers as non-root
- Use Pod Security Standards in Kubernetes
- Monitor runtime behavior (Falco, Wazuh)

## CI/CD Security
- Sign commits and verify signatures
- Scan dependencies for vulnerabilities (Dependabot, Snyk)
- Use SAST/DAST tools in pipeline
- Pin action/plugin versions to specific SHA
- Separate CI/CD credentials per environment

## Compliance
- Maintain audit logs for all changes
- Document security policies and procedures
- Regular vulnerability assessments
- Incident response plan tested regularly
- Data encryption at rest and in transit
