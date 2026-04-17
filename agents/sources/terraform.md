---
name: terraform
description: Terraform/OpenTofu infrastructure as code via CLI
type: cli
required_env: []
required_tools:
  - terraform
  - jq
check_command: "terraform version -json 2>/dev/null | jq -r '.terraform_version'"
---

# Terraform

## Connection

OTTO uses the `terraform` or `tofu` (OpenTofu) CLI to manage infrastructure as code.
Terraform reads its configuration from `.tf` files in the working directory and
connects to the configured backend for state management.

```bash
terraform version         # verify installation
terraform providers       # list configured providers
```

For OpenTofu, replace `terraform` with `tofu` in all commands. Set `OTTO_TF_BINARY`
to override the default binary name.

Backend authentication is handled through provider-specific environment variables
(e.g., `AWS_ACCESS_KEY_ID`, `ARM_CLIENT_ID`, `GOOGLE_CREDENTIALS`) or through
shared credentials files.

## Available Data

- **State**: Current infrastructure state, resource attributes, and outputs
- **Plan**: Preview of changes that would be applied
- **Resources**: List of managed resources and their current status
- **Outputs**: Exported values from the configuration
- **Workspaces**: List and manage Terraform workspaces
- **Providers**: List configured providers and their versions
- **Modules**: List used modules and their sources
- **Drift detection**: Compare state with real infrastructure

## Common Queries

### Show current state
```bash
terraform state list
terraform state show <resource-address>
```

### Show outputs
```bash
terraform output -json | jq '.'
```

### Plan changes
```bash
terraform plan -out=tfplan -json 2>/dev/null | jq 'select(.type=="planned_change")'
```

### List workspaces
```bash
terraform workspace list
terraform workspace show
```

### Show resource details
```bash
terraform state show 'module.vpc.aws_vpc.main' | head -30
```

### Detect drift
```bash
terraform plan -detailed-exitcode -json 2>/dev/null
# Exit code 0 = no changes, 1 = error, 2 = changes detected
```

### Show provider versions
```bash
terraform providers -json | jq '.provider_schemas | keys'
```

### Import existing resource
```bash
terraform import <resource-address> <resource-id>
```
