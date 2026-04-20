# Secrets Management Pattern

## Concept

Centralized, secure management of sensitive data (API keys, passwords, certificates,
tokens) with access control, audit logging, and automatic rotation. Never store
secrets in code, environment files committed to Git, or container images.

## HashiCorp Vault Integration

**Architecture:**
- Vault server stores and manages secrets
- Applications authenticate and fetch secrets at runtime
- Dynamic secrets: Vault generates short-lived credentials on demand

**Common auth methods:**
- Kubernetes: Service account token auth
- AppRole: Machine-to-machine auth with role_id + secret_id
- AWS/GCP/Azure: Cloud IAM identity auth
- OIDC: SSO integration

**Usage pattern:**
```bash
# Write a secret
vault kv put secret/myapp/db username=admin password=s3cret

# Read a secret
vault kv get -format=json secret/myapp/db | jq '.data.data'

# Dynamic database credentials
vault read database/creds/myapp-role
```

## Sidecar Injection

A sidecar container fetches secrets and writes them to a shared volume.

**Vault Agent Injector (Kubernetes):**
- Annotate pods to inject Vault Agent as init + sidecar container
- Secrets rendered to files in a shared tmpfs volume
- Templates support dynamic formatting

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "myapp"
  vault.hashicorp.com/agent-inject-secret-db: "secret/data/myapp/db"
```

## Sealed Secrets (Kubernetes)

Encrypt secrets for safe storage in Git.

**Workflow:**
1. Install Sealed Secrets controller in cluster
2. Encrypt with `kubeseal`: `kubeseal --format yaml < secret.yaml > sealed-secret.yaml`
3. Commit `sealed-secret.yaml` to Git (safe -- only the cluster can decrypt)
4. Controller decrypts and creates the actual Secret in-cluster

## External Secrets Operator

Sync secrets from external providers into Kubernetes Secrets.

**Supported backends:** Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, 1Password, Doppler

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: myapp-secrets
  data:
    - secretKey: db-password
      remoteRef:
        key: secret/data/myapp/db
        property: password
```

## SOPS (Secrets OPerationS)

Encrypt specific values in YAML/JSON files using cloud KMS or PGP.

**Workflow:**
1. Create `.sops.yaml` config with encryption rules
2. `sops --encrypt secrets.yaml > secrets.enc.yaml`
3. Commit encrypted file to Git
4. Decrypt at deploy time: `sops --decrypt secrets.enc.yaml`
5. Integrates with Flux (Kustomize decryption) and ArgoCD (plugin)

**Key management:** AWS KMS, GCP KMS, Azure Key Vault, age, PGP

## Environment Variable Injection

Inject secrets as environment variables at runtime.

**Methods:**
- Kubernetes Secrets mounted as env vars
- Vault Agent template rendering to `.env` file
- Cloud-native: AWS Parameter Store, GCP Secret Manager
- CI/CD: pipeline variables (GitHub Actions secrets, GitLab CI variables)
- Docker: `--env-file` with secrets fetched at deploy time

**Caution:** Env vars can leak via process listings, crash dumps, or child processes.
Prefer file-based secrets or API-based fetching where possible.

## Rotation Strategies

### Automated rotation
- Vault dynamic secrets: credentials auto-expire (TTL-based)
- AWS Secrets Manager: built-in rotation with Lambda functions
- Database credential rotation: create new user, update references, drop old user

### Zero-downtime rotation
1. Add new secret alongside old one
2. Update application to accept both
3. Verify new secret works
4. Remove old secret
5. Update application to use only new secret

### Rotation schedule
- API keys and tokens: 90 days
- Database passwords: 30-90 days
- TLS certificates: before expiry (automate with cert-manager)
- SSH keys: annually or on personnel changes

## Best Practices

- Never log secrets or include them in error messages
- Use short-lived, scoped credentials (principle of least privilege)
- Audit all secret access (who read what, when)
- Encrypt secrets at rest and in transit
- Use separate secret stores per environment
- Automate rotation -- manual rotation is a security risk
- Scan code for accidentally committed secrets (gitleaks, truffleHog)
- Revoke compromised secrets immediately, then rotate
