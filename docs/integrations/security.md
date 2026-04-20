# Security Integrations

OTTO integrates with security tools for vulnerability scanning, intrusion
detection, secrets management, and runtime protection.

## HashiCorp Vault

### Setup

1. Install Vault CLI: download from [vaultproject.io](https://www.vaultproject.io)
2. Configure OTTO environment (`~/.config/otto/.env`):
   ```bash
   VAULT_ADDR=https://vault.example.com:8200
   VAULT_TOKEN=your-token
   # Or use other auth methods:
   VAULT_ROLE_ID=your-role-id
   VAULT_SECRET_ID=your-secret-id
   ```

### What OTTO Monitors

- Vault seal status and health
- Token expiry and renewal
- Audit log activity
- Secret engine mount status
- Lease expiration warnings

### Configuration

```yaml
security:
  vault:
    enabled: true
    addr: https://vault.example.com:8200
    auth_method: token  # token, approle, kubernetes
    check_seal: true
    monitor_leases: true
```

## Trivy

### Setup

1. Install Trivy: `apt install trivy` or download from [aquasecurity.github.io/trivy](https://aquasecurity.github.io/trivy)
2. No additional OTTO configuration required -- Trivy runs locally.

### What OTTO Monitors

- Container image vulnerabilities (CVEs)
- Filesystem vulnerabilities in running containers
- IaC misconfigurations (Terraform, Kubernetes manifests, Dockerfiles)
- Secret detection in codebases
- SBOM generation

### Usage

OTTO runs Trivy scans automatically during:
- `/otto:review` -- scans changed Dockerfiles and K8s manifests
- `/otto:compliance` -- full vulnerability audit
- Night Watcher -- periodic image scanning

### Configuration

```yaml
security:
  trivy:
    enabled: true
    severity: CRITICAL,HIGH  # minimum severity to report
    ignore_unfixed: true
    scan_images: true
    scan_filesystem: true
    scan_config: true
    skip_dirs:
      - node_modules
      - .git
```

## Wazuh

### Setup

1. Install Wazuh agent on monitored hosts or deploy Wazuh manager
2. Configure OTTO environment (`~/.config/otto/.env`):
   ```bash
   OTTO_WAZUH_URL=https://wazuh.example.com:55000
   OTTO_WAZUH_TOKEN=your-api-token
   # Or username/password:
   OTTO_WAZUH_USER=admin
   OTTO_WAZUH_PASSWORD=your-password
   ```

### What OTTO Monitors

- Active alerts and their severity
- Agent status (connected, disconnected, pending)
- File integrity monitoring (FIM) events
- Vulnerability detection results
- Compliance check results (PCI DSS, GDPR, HIPAA)
- Rootcheck and SCA (Security Configuration Assessment) findings

### Configuration

```yaml
security:
  wazuh:
    enabled: true
    url: https://wazuh.example.com:55000
    min_severity: 7  # minimum alert level to report (1-15)
    monitor_agents: true
    monitor_fim: true
    monitor_vulnerabilities: true
```

## Falco

### Setup

1. Install Falco on Kubernetes nodes or as a DaemonSet:
   ```bash
   helm repo add falcosecurity https://falcosecurity.github.io/charts
   helm install falco falcosecurity/falco \
     --set falcosidekick.enabled=true \
     --set falcosidekick.config.webhook.address=http://otto-webhook:8080/falco
   ```
2. Or install on bare metal: follow [falco.org](https://falco.org) docs

### What OTTO Monitors

- Runtime security events (unexpected process execution, file access, network connections)
- Container escape attempts
- Privilege escalation attempts
- Suspicious system calls
- Custom rule violations

### Configuration

```yaml
security:
  falco:
    enabled: true
    source: webhook  # webhook, grpc, log
    min_priority: warning  # emergency, alert, critical, error, warning, notice, info, debug
    rules:
      - name: terminal_shell_in_container
        priority: warning
      - name: write_below_etc
        priority: error
```

### Integration with Falcosidekick

Falcosidekick forwards Falco alerts to OTTO via webhook. Configure the webhook
URL in Falcosidekick to point to OTTO's alert receiver:

```yaml
# Falcosidekick config
webhook:
  address: http://localhost:8080/api/v1/alerts/falco
```

## Alerting

| Tool | Event | Severity | Default Action |
|------|-------|----------|---------------|
| Vault | Sealed | critical | Immediate alert + incident |
| Vault | Token expiring (<24h) | warning | Notify |
| Trivy | Critical CVE found | critical | Block deploy (if in CI) |
| Trivy | High CVE found | warning | Notify |
| Wazuh | Alert level >= 12 | critical | Immediate alert |
| Wazuh | Agent disconnected | warning | Notify |
| Falco | Priority >= error | critical | Immediate alert |
| Falco | Priority = warning | warning | Notify |

## Compliance

OTTO's compliance checker (`/otto:compliance`) aggregates findings from all
security tools into a unified compliance report covering:

- Vulnerability status (Trivy, Wazuh)
- Runtime security posture (Falco)
- Secrets management health (Vault)
- Configuration hardening (Wazuh SCA, Trivy IaC)

See `knowledge/patterns/secrets-management.md` for secrets management best practices.
