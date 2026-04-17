# Terraform Best Practices

## Project Structure
- Use modules for reusable infrastructure components
- Separate environments using workspaces or directory structure
- Keep root modules small - delegate to child modules
- Use consistent naming: main.tf, variables.tf, outputs.tf, providers.tf, versions.tf

## State Management
- Always use remote state (S3, GCS, Azure Blob, Terraform Cloud)
- Enable state locking (DynamoDB for S3 backend)
- Never edit state manually (use terraform state mv/rm)
- Use separate state files per environment

## Code Quality
- Pin provider and module versions (use ~> for minor version flexibility)
- Use terraform fmt and terraform validate in CI
- Use tflint or checkov for additional linting
- Add descriptions to all variables and outputs
- Use locals for computed values, not repeated expressions

## Security
- Never hardcode secrets in .tf files
- Use variables with sensitive = true for secrets
- Store secrets in Vault, AWS Secrets Manager, or similar
- Enable encryption at rest for state backend
- Review plan output before apply - especially for destructive changes

## Variables
- Provide sensible defaults where possible
- Use validation blocks for input constraints
- Group related variables in .tfvars files per environment
- Use variable types (string, number, bool, list, map, object)

## Modules
- Use semantic versioning for modules
- Document module inputs and outputs
- Minimize required variables (use sensible defaults)
- Test modules independently

## Common Patterns
- Use for_each over count (better state management on changes)
- Use data sources for existing resources
- Use depends_on sparingly (only when implicit dependencies fail)
- Use lifecycle rules (prevent_destroy, ignore_changes) intentionally
