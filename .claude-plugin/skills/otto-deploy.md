---
name: deploy
description: "Guided deployment with pre-checks, confirmation, execution, and verification"
user-invocable: true
---

# OTTO Guided Deployment

Execute a deployment with safety checks, plan review, confirmation, and post-deploy verification.

## Arguments

- `[target]` - What to deploy (e.g., app name, service, helm chart)
- `[env]` - Target environment (e.g., staging, production)
- `[version]` - Version/tag to deploy (e.g., v1.2.3, latest commit)

## Steps

### 1. Permission Check
- Determine the user's role via `role_check_permission`
- Production deployments require `confirm` or higher permission level
- If permission is `deny`, stop and explain why

### 2. Pre-flight Checks
- Verify the target exists and is deployable
- Check current state of the target environment
- Validate the version/artifact exists
- Run any configured pre-deploy checks (tests, linting)
- Check for active incidents that might conflict

### 3. Deployment Plan
Present a clear plan showing:
- What will change (diff if available)
- Which environment is targeted
- Rollback strategy
- Estimated duration
- Affected services/dependencies

### 4. Confirmation
- For `confirm` permission level: ask "Proceed with deployment? [Y/n]"
- For `suggest` permission level: present the plan and wait for explicit approval
- For `auto` permission level: proceed automatically (non-production only)

### 5. Execute
- Run the deployment command
- Stream progress to the user
- Log the action via `audit_log`

### 6. Post-deploy Verification
- Run health checks on the deployed service
- Verify the expected version is running
- Check for error rate changes
- Report success or failure

### 7. If Failure
- Present error details
- Suggest rollback if appropriate
- Create an incident task if needed
