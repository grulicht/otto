# IaC Workflow Best Practices

## Terraform + Ansible Integration Patterns
- Use Terraform for infrastructure provisioning, Ansible for configuration management
- Export Terraform outputs as Ansible inventory via `terraform output -json`
- Use a pipeline stage pattern: Terraform apply -> Generate inventory -> Ansible run
- Share data through external stores (SSM, Consul) rather than direct coupling
- Use Terraform `null_resource` + `local-exec` provisioner only for simple post-creation tasks
- Consider Packer for image building instead of Ansible post-provision

## State Management Across Teams
- Use remote backends with state locking (S3+DynamoDB, GCS, Azure Blob, Terraform Cloud)
- One state file per environment per service (avoid monolithic state)
- Use workspaces for ephemeral environments, directories for permanent environments
- Implement state access controls: IAM policies on backend buckets
- Enable backend versioning for state rollback capability
- Run `terraform plan` in CI for every PR to catch issues early
- Never share state files manually - always use the backend

## Environment Promotion
- Use identical Terraform modules across environments with different `.tfvars`
- Promote by merging to environment branches or changing variable files
- Implement progressive delivery: dev -> staging -> canary -> production
- Use feature flags in infrastructure (e.g., module count/for_each toggles)
- Gate production deploys on staging health checks and approval workflows
- Keep environment parity as close as possible (same modules, different scale)

## Module Versioning Strategy
- Use semantic versioning for all shared modules
- Pin exact versions in production, use `~>` constraints in development
- Maintain a CHANGELOG.md for every module
- Test modules independently before publishing new versions
- Use a module registry (Terraform Cloud, Artifactory, Git tags) for distribution
- Avoid referencing modules from `main` branch - always use tagged releases

## Testing IaC (Terratest, Molecule)
- Write unit tests for Terraform modules using Terratest (Go) or tftest (Python)
- Use `terraform validate` and `terraform plan` as fast feedback in CI
- Run integration tests that apply and verify real infrastructure in a sandbox account
- Use Molecule for Ansible role testing with Docker or Vagrant drivers
- Implement contract tests: verify module outputs match expected schema
- Clean up test resources automatically with deferred destroy
- Test edge cases: empty inputs, maximum values, special characters in names

## Drift Detection Automation
- Schedule periodic `terraform plan` runs (e.g., daily) to detect drift
- Alert on any planned changes that were not initiated by a PR
- Use tools like driftctl or Spacelift for continuous drift monitoring
- Tag all IaC-managed resources to distinguish from manually created ones
- Implement auto-remediation for known safe drifts (e.g., ASG size changes)
- Store plan outputs for audit and comparison

## Cost Estimation in Pipelines
- Integrate Infracost into PR workflows for cost change visibility
- Set budget alerts and thresholds in CI (fail PR if cost exceeds limit)
- Use `infracost diff` to show cost delta between current and proposed state
- Tag resources with cost center/team for chargeback
- Review instance types and storage classes in plan output
- Estimate monthly costs before applying major infrastructure changes

## Policy-as-Code Gates
- Use OPA/Rego, Sentinel, or Checkov for automated policy enforcement
- Run policy checks in CI before `terraform apply`
- Common policies: no public S3 buckets, encryption at rest required, approved instance types
- Implement soft (warn) and hard (deny) policy levels
- Version control all policies alongside infrastructure code
- Generate compliance reports from policy evaluation results
- Use pre-commit hooks for fast local policy feedback
