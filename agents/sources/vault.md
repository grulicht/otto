---
name: vault
description: HashiCorp Vault secrets management via vault CLI
type: cli
required_env:
  - VAULT_ADDR
  - VAULT_TOKEN
required_tools:
  - vault
  - jq
check_command: "vault status -format=json 2>/dev/null | jq -r '.sealed'"
---

# Vault

## Connection

OTTO connects to HashiCorp Vault through the `vault` CLI. Authentication
requires `VAULT_ADDR` (server URL) and a valid token or auth method.

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="hvs...."
vault status               # verify connectivity
vault token lookup          # verify token validity
```

Alternative auth methods:
```bash
vault login -method=userpass username=otto
vault login -method=ldap username=otto
vault login -method=approle role_id=... secret_id=...
```

For namespaced Vault (Enterprise), set `VAULT_NAMESPACE`.

## Available Data

- **Secrets**: KV (v1/v2), database credentials, PKI certificates, SSH keys
- **Auth methods**: Token, AppRole, LDAP, Kubernetes, OIDC, userpass
- **Policies**: ACL policies governing access
- **Audit log**: Audit device logs (if configured)
- **Seal status**: Initialization and seal state
- **Leases**: Active leases and their TTLs
- **Mounts**: Secret engine and auth method mounts

## Common Queries

### Check Vault status
```bash
vault status -format=json | jq '{sealed, version, cluster_name}'
```

### Read a KV v2 secret
```bash
vault kv get -format=json secret/myapp/config | jq '.data.data'
```

### List secrets at a path
```bash
vault kv list secret/myapp/
```

### Read a KV v1 secret
```bash
vault read -format=json secret/myapp/config | jq '.data'
```

### Generate database credentials
```bash
vault read -format=json database/creds/myapp-role | jq '{username: .data.username, ttl: .lease_duration}'
```

### List secret engines
```bash
vault secrets list -format=json | jq 'keys'
```

### List auth methods
```bash
vault auth list -format=json | jq 'keys'
```

### Check token capabilities
```bash
vault token capabilities secret/myapp/config
```

### Renew a lease
```bash
vault lease renew <lease-id>
```

### Issue a PKI certificate
```bash
vault write -format=json pki/issue/my-role common_name="app.example.com" | jq '.data.certificate'
```
