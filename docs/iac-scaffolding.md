# IaC Scaffolding Guide

OTTO's IaC (Infrastructure as Code) assistant generates project scaffolds and templates for common infrastructure tools, following best practices out of the box.

> **Maturity: Experimental** - Scaffolds work well but template customization options are limited.

## What IaC Scaffolding Does

Instead of starting from scratch or copying boilerplate, OTTO generates complete project structures with:

- Security best practices (non-root users, read-only filesystems, capability drops)
- Standard directory layouts
- Sensible defaults for production use
- Health check configurations
- CI/CD pipeline structure

## Available Scaffolds

| Scaffold | Function | Command |
|----------|----------|---------|
| Terraform module | Complete module with variables, outputs, backend, validation | `iac_scaffold_terraform` |
| Ansible role | Full role directory structure with tasks, handlers, defaults, meta | `iac_scaffold_ansible` |
| Helm chart | Chart with deployment, service, values, HPA, security contexts | `iac_scaffold_helm` |
| Dockerfile | Multi-stage builds for Python, Node.js, Go, and generic apps | `iac_scaffold_dockerfile` |
| CI/CD pipeline | GitHub Actions or GitLab CI pipeline | `iac_scaffold_cicd` |
| Kubernetes manifests | Deployment, service, ingress, and HPA | `iac_scaffold_k8s` |

## Usage

Source the IaC assistant script to access all scaffold functions:

```bash
source scripts/core/iac-assistant.sh
```

### Terraform Module

```bash
# iac_scaffold_terraform <name> <provider> <resources> [output_dir]
iac_scaffold_terraform my-vpc aws "vpc,subnet,security_group" ./infra/my-vpc
```

Generated structure:
```
my-vpc/
  main.tf              # Provider config, backend, resource stubs
  variables.tf         # Environment variable with validation, tags
  outputs.tf           # Output placeholder
  versions.tf          # Provider version pinning
  .terraform-docs.yml  # Auto-doc configuration
```

Best practices applied: `required_version >= 1.5.0`, S3 backend placeholder, variable validation, terraform-docs config.

### Ansible Role

```bash
# iac_scaffold_ansible <name> <role_type> [output_dir]
iac_scaffold_ansible nginx service ./roles/nginx
```

Generated structure:
```
roles/nginx/
  tasks/main.yml       # OS-specific vars, package install, config template
  handlers/main.yml    # Service restart handler
  defaults/main.yml    # Default variables
  vars/                # (empty, for OS-specific vars)
  meta/main.yml        # Galaxy metadata with platform support
  templates/nginx.conf.j2  # Config template placeholder
  files/               # (empty, for static files)
```

Best practices applied: OS-family variable inclusion, tagged tasks, handler notification, Galaxy metadata with platform versions.

### Helm Chart

```bash
# iac_scaffold_helm <name> <app_type> [output_dir]
iac_scaffold_helm myapp web ./charts/myapp
```

Generated structure:
```
charts/myapp/
  Chart.yaml                    # Chart metadata
  values.yaml                   # Defaults with security, autoscaling, resources
  templates/
    deployment.yaml             # Deployment with probes, security context
    _helpers.tpl                # Template helpers (fullname, labels)
    tests/                      # (empty, for chart tests)
```

Best practices applied: `runAsNonRoot`, `readOnlyRootFilesystem`, capability drop, resource requests/limits, HPA config, liveness/readiness probes.

### Dockerfile

```bash
# iac_scaffold_dockerfile <language> <framework> [output_dir]
iac_scaffold_dockerfile python flask ./myapp
iac_scaffold_dockerfile node express ./myapp
iac_scaffold_dockerfile go gin ./myapp
```

Supported languages and what you get:

| Language | Base image | Features |
|----------|-----------|----------|
| `python` | `python:3.12-slim` | Multi-stage, non-root user, health check |
| `node`/`nodejs` | `node:20-alpine` | Multi-stage, `npm ci`, non-root user, health check |
| `go`/`golang` | `golang:1.22-alpine` + `scratch` | Multi-stage, static binary, minimal attack surface |
| Other | `ubuntu:24.04` | Basic non-root setup |

Each also generates a `.dockerignore` excluding `.git`, `.env`, `node_modules`, `__pycache__`, and other common exclusions.

### CI/CD Pipeline

```bash
# iac_scaffold_cicd <platform> <language> [output_dir]
iac_scaffold_cicd github python ./myproject
iac_scaffold_cicd gitlab node ./myproject
```

| Platform | Output | Structure |
|----------|--------|-----------|
| `github` / `github-actions` | `.github/workflows/ci.yml` | test -> build -> deploy (on main) |
| `gitlab` | `.gitlab-ci.yml` | test -> build -> deploy stages |

### Kubernetes Manifests

```bash
# iac_scaffold_k8s <app_name> <type> [output_dir]
iac_scaffold_k8s myapp deployment ./k8s
```

Generated files:
```
k8s/
  deployment.yaml    # Deployment with probes, security context, resource limits
  service.yaml       # ClusterIP service
  ingress.yaml       # Nginx ingress with TLS
  hpa.yaml           # HPA with CPU and memory targets
```

Best practices applied: `runAsNonRoot`, `readOnlyRootFilesystem`, capability drop, resource requests/limits, liveness/readiness probes, TLS ingress, dual-metric HPA.

## Customizing Generated Templates

The generated files are starting points. Common customizations:

1. **Terraform**: Replace the S3 backend stub with your actual backend, add resources to `main.tf`.
2. **Ansible**: Add OS-specific variable files in `vars/`, customize the config template.
3. **Helm**: Add more templates (configmap, secret, serviceaccount), adjust `values.yaml`.
4. **Dockerfile**: Change base image versions, add build arguments, adjust health check endpoints.
5. **CI/CD**: Add actual test commands, configure deployment targets, add secrets.
6. **Kubernetes**: Adjust resource limits, add configmaps, change ingress class.

## Using Scaffolds in a Team Workflow

1. **Standardize on OTTO scaffolds** for new projects to ensure consistent structure.
2. **Run scaffolding once** at project start, then customize the output.
3. **Store generated files in version control** and iterate from there.
4. **Use IaC scaffolding alongside OTTO's compliance checker** to verify generated templates meet your policies.
