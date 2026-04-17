# Cloud & Virtualization Integrations

## AWS

### Setup
Use AWS CLI (`aws`). Authenticate via `aws configure` or IAM roles.

### Capabilities
- EC2 instance management, S3 operations, RDS administration
- EKS cluster management, Lambda function management
- IAM policy review, CloudWatch metrics and alarms
- VPC/networking management, Cost Explorer queries

## Google Cloud Platform

### Setup
Use `gcloud` CLI. Authenticate with `gcloud auth login`.

### Capabilities
- GKE cluster management, Cloud Run deployments
- BigQuery operations, IAM management
- Cloud Monitoring and Logging
- Cloud Functions management

## Microsoft Azure

### Setup
Use `az` CLI. Authenticate with `az login`.

### Capabilities
- AKS management, App Service deployments
- CosmosDB administration, Active Directory
- Azure Monitor, Functions management

## DigitalOcean

### Setup
```bash
DIGITALOCEAN_TOKEN=your-api-token
```
Use `doctl` CLI.

## Hetzner

### Setup
```bash
HETZNER_TOKEN=your-api-token
```
Use `hcloud` CLI.

## Hyper-V

### Setup
Requires PowerShell with Hyper-V module on Windows/Windows Server.

### Capabilities
- VM lifecycle management (create, start, stop, snapshot)
- Virtual network and switch management
- Checkpoint/snapshot management

## Proxmox VE

### Setup
Access via Proxmox REST API or `pvesh` CLI on the Proxmox host.

### Capabilities
- VM and container management
- Cluster status monitoring
- Storage and backup management
- Template management

## XCP-ng

### Setup
Access via `xe` CLI or XenAPI.

### Capabilities
- VM lifecycle management
- Pool and storage management
- Network configuration
