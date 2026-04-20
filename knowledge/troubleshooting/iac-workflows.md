# IaC Workflow Troubleshooting

## Terraform State Conflicts in Team Environments
**Symptoms:** `Error acquiring the state lock`, state file corruption, concurrent apply failures.
**Steps:**
1. Check who holds the lock: `terraform force-unlock <LOCK_ID>` (only after confirming no active apply)
2. Enable state locking with DynamoDB (AWS) or equivalent backend
3. Use CI/CD to serialize applies - never run terraform apply from local machines in teams
4. If state is corrupted, restore from backend versioning (S3 versioning, GCS object versioning)
5. Use `terraform state pull` to inspect current state before manual intervention
6. Consider Terraform Cloud or Spacelift for managed state locking

## Ansible Idempotency Failures
**Symptoms:** Tasks report "changed" on every run, unexpected modifications on re-runs.
**Steps:**
1. Check for shell/command modules without `creates`/`removes` guards
2. Replace shell commands with native Ansible modules where possible
3. Use `changed_when: false` for read-only commands
4. Add `creates:` parameter to shell tasks that produce files
5. Test with `--check --diff` to identify non-idempotent tasks
6. Use `ansible-lint` to catch common idempotency issues
7. Verify handlers are not triggered unnecessarily - use `listen` for grouping

## Terraform and Ansible Integration Issues
**Symptoms:** Terraform outputs not available in Ansible, ordering problems, partial deploys.
**Steps:**
1. Use `terraform output -json` to generate Ansible inventory dynamically
2. Write Terraform outputs to a JSON file consumed by Ansible `include_vars`
3. Use Terraform `local-exec` provisioner for Ansible only as last resort
4. Prefer separate pipeline stages: Terraform first, then Ansible with dynamic inventory
5. Store shared state (IPs, endpoints) in SSM Parameter Store or Consul
6. Use terraform-inventory or custom inventory scripts for dynamic hosts

## State Migration Problems
**Symptoms:** Resources lost after backend change, state mv failures, import errors.
**Steps:**
1. Always `terraform state pull > backup.tfstate` before migration
2. Use `terraform init -migrate-state` when changing backends
3. For resource renames: `terraform state mv old_name new_name`
4. For importing existing resources: `terraform import resource_type.name id`
5. Use `terraform state list` to verify all resources after migration
6. Check for circular dependencies when moving resources between modules
7. Use `terraform state rm` + `terraform import` as alternative to `state mv` for complex moves

## Module Version Conflicts
**Symptoms:** Unexpected changes after module update, incompatible provider versions, init failures.
**Steps:**
1. Pin module versions explicitly: `source = "module?ref=v1.2.3"` or `version = "~> 1.2"`
2. Use `terraform init -upgrade` to update providers and modules
3. Check `.terraform.lock.hcl` for provider hash mismatches across platforms
4. Review module changelog before upgrading major versions
5. Use `terraform plan` after any module update to review changes before apply
6. Run `terraform providers lock -platform=linux_amd64 -platform=darwin_amd64` for cross-platform teams

## Provider Authentication Failures
**Symptoms:** `Error configuring provider`, 401/403 errors, expired credentials.
**Steps:**
1. Verify credentials are set: check env vars, shared credentials files, instance profiles
2. For AWS: `aws sts get-caller-identity` to verify active session
3. For GCP: `gcloud auth application-default print-access-token` to verify
4. For Azure: `az account show` to verify logged-in identity
5. Check if tokens/sessions have expired (SSO sessions, STS tokens)
6. In CI/CD: use OIDC federation instead of long-lived credentials
7. Verify provider version supports the authentication method being used

## Plan/Apply Drift Between Environments
**Symptoms:** Plan shows unexpected changes, resources differ from code, environments out of sync.
**Steps:**
1. Run `terraform plan` to identify drift
2. Use `terraform refresh` (or `terraform apply -refresh-only`) to update state
3. Check for manual changes made outside Terraform (console, CLI)
4. Implement drift detection in CI: schedule periodic plan-only runs
5. Use policy-as-code (OPA, Sentinel) to prevent manual changes
6. Tag all Terraform-managed resources to identify manually created ones
7. Use separate `.tfvars` files per environment with clear variable differences

## Secret Injection in IaC Pipelines
**Symptoms:** Secrets exposed in logs, plan output leaking sensitive values, state containing plaintext secrets.
**Steps:**
1. Mark variables as `sensitive = true` in Terraform
2. Use external secret managers (Vault, AWS Secrets Manager) via data sources
3. Never pass secrets as CLI `-var` arguments (visible in process list)
4. Use environment variables prefixed with `TF_VAR_` for secret injection
5. Enable CI/CD secret masking for all secret values
6. Encrypt state backend at rest (S3 SSE, GCS CMEK)
7. In Ansible: use `ansible-vault` for encrypting sensitive files
8. Use `no_log: true` on Ansible tasks handling secrets
