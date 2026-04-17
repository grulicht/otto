# Infrastructure Testing Patterns
tags: testing, terraform, opa, rego, terratest, chaos-engineering, compliance

## Testing Pyramid for Infrastructure

```
         /  Chaos  \          <- Production resilience
        / Integration \       <- Real infrastructure tests
       /   Compliance   \     <- Policy & security checks
      /    Unit Tests     \   <- Syntax & logic validation
     /________________________\
```

## Unit Tests (Fast, Cheap)

Validate syntax, logic, and configuration without provisioning resources.

### Terraform Validate
```bash
# Basic syntax check
terraform init -backend=false
terraform validate

# Format check
terraform fmt -check -recursive

# Static analysis with tflint
tflint --init
tflint --recursive
```

### Ansible Lint
```bash
ansible-lint playbooks/
ansible-playbook --syntax-check playbooks/site.yml
```

### Kubernetes Manifest Validation
```bash
# kubeconform (faster kubeval replacement)
kubeconform -summary -strict manifests/

# Validate with dry-run
kubectl apply --dry-run=server -f manifests/
```

### Helm Chart Testing
```bash
helm lint charts/myapp/
helm template charts/myapp/ | kubeconform -strict
```

## Compliance Tests (OPA/Rego)

Enforce organizational policies as code.

### Open Policy Agent (OPA)

```rego
# policy/terraform.rego
package terraform

# Deny instances without required tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    not resource.change.after.tags.Environment
    msg := sprintf("Instance %v missing 'Environment' tag", [resource.address])
}

# Require encryption on S3 buckets
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not has_encryption(resource)
    msg := sprintf("S3 bucket %v must have encryption enabled", [resource.address])
}
```

```bash
# Run against Terraform plan
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
opa eval --data policy/ --input plan.json "data.terraform.deny"
```

### Kubernetes Policies (Gatekeeper/Kyverno)

```yaml
# Kyverno: require resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-limits
spec:
  validationFailureAction: enforce
  rules:
    - name: check-limits
      match:
        resources:
          kinds: [Pod]
      validate:
        message: "CPU and memory limits are required"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

## Integration Tests (Terratest)

Test real infrastructure by provisioning, validating, and destroying.

```go
// test/vpc_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPC(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../modules/vpc",
        Vars: map[string]interface{}{
            "cidr_block": "10.99.0.0/16",
            "name":       "test-vpc",
        },
    }

    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    vpcID := terraform.Output(t, opts, "vpc_id")
    assert.NotEmpty(t, vpcID)
}
```

**Tips:**
- Run integration tests in isolated accounts/projects
- Use `t.Parallel()` to speed up test suites
- Clean up resources in `defer` blocks
- Tag test resources for easy cleanup

## Chaos Engineering

Test system resilience by injecting failures in production(-like) environments.

### Tools
- **Chaos Monkey:** Randomly terminates instances
- **Litmus Chaos:** Kubernetes-native chaos experiments
- **Gremlin:** Enterprise chaos platform
- **toxiproxy:** Simulate network conditions

### Common Experiments
1. **Instance termination:** Kill a random pod/VM
2. **Network latency:** Add 500ms latency between services
3. **Disk fill:** Fill disk to 95% on a node
4. **DNS failure:** Block DNS resolution
5. **CPU stress:** Consume CPU on critical hosts

```yaml
# Litmus experiment: pod delete
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: pod-delete-test
spec:
  appinfo:
    appns: default
    applabel: app=myservice
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "30"
            - name: CHAOS_INTERVAL
              value: "10"
```

### Principles
- Start small: begin with staging, then production
- Have a hypothesis: "If X fails, the system should Y"
- Have a rollback plan
- Monitor blast radius
- Automate experiments in CI/CD (game days)

## CI/CD Integration

```yaml
# Pipeline stages
stages:
  - lint        # terraform fmt, tflint, ansible-lint
  - validate    # terraform validate, kubeconform
  - policy      # OPA/Rego checks
  - plan        # terraform plan (review)
  - test        # terratest in ephemeral env
  - apply       # deploy to staging
  - chaos       # chaos experiments (staging)
  - promote     # deploy to production
```
