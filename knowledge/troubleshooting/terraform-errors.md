# Terraform Common Errors

## "Error acquiring the state lock"
**Cause:** Another process holds the state lock, or a previous run crashed.
**Fix:**
1. Check if another terraform process is running
2. If crashed: `terraform force-unlock <LOCK_ID>` (use with caution!)
3. Prevention: always use CI/CD for terraform runs, avoid parallel applies

## "Error: Provider requirements cannot be satisfied"
**Cause:** Provider version mismatch or not installed.
**Fix:**
1. Run `terraform init -upgrade`
2. Check provider version constraints in versions.tf
3. Ensure required_providers block is correct

## "Error: Resource already exists"
**Cause:** Resource exists in cloud but not in state.
**Fix:**
1. `terraform import <resource_address> <cloud_id>`
2. Or if you want terraform to manage it: import, then plan

## "Error: Cycle detected"
**Cause:** Circular dependency between resources.
**Fix:**
1. Review depends_on relationships
2. Break the cycle by splitting resources or using data sources
3. Use `terraform graph` to visualize dependencies

## "Error: Invalid count argument"
**Cause:** count/for_each depends on a value not known until apply.
**Fix:**
1. Use -target to apply the dependency first
2. Restructure to avoid computed count values
3. Use locals to pre-compute values where possible

## Drift Detection
**When to check:** After manual changes, before planning.
**Steps:**
1. `terraform plan` - shows differences between state and reality
2. `terraform refresh` - updates state without changing infrastructure
3. Decide: apply to match state, or import/modify state

## State Recovery
1. Never delete state files
2. Enable state versioning on backend (S3 versioning)
3. Use `terraform state pull` to download current state
4. Use `terraform state mv` to rename/move resources in state
