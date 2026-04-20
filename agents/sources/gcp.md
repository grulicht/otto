---
name: gcp
description: Google Cloud Platform via gcloud CLI for cloud infrastructure management
type: cli
required_env: []
required_tools:
  - gcloud
  - jq
check_command: "gcloud config get-value project 2>/dev/null"
fetch_script: cloud-gcp.sh
---

> **Note:** The fetch script for this source is named `cloud-gcp.sh` (not `gcp.sh`), located in `scripts/fetch/cloud-gcp.sh`.

# Google Cloud Platform

## Connection

OTTO connects to GCP through the `gcloud` CLI, which handles authentication via
service accounts, application default credentials, or user login.

```bash
gcloud auth list                    # list authenticated accounts
gcloud config get-value project     # show current project
gcloud config get-value account     # show current account
```

Authentication methods:
1. User login: `gcloud auth login`
2. Service account: `gcloud auth activate-service-account --key-file=<key.json>`
3. Application default credentials: `gcloud auth application-default login`
4. Workload identity (GKE)

Set project with `gcloud config set project <project-id>` or `--project <project-id>`.

## Available Data

- **Compute Engine**: Instances, disks, images, machine types
- **GKE**: Kubernetes clusters and node pools
- **Cloud Run**: Serverless container services
- **Cloud SQL**: Managed database instances
- **Cloud Storage**: Buckets and objects
- **Cloud Functions**: Serverless functions
- **IAM**: Roles, policies, service accounts
- **Cloud Monitoring**: Metrics and alerting policies
- **Cloud Logging**: Log entries and sinks
- **VPC**: Networks, subnets, firewall rules

## Common Queries

### List compute instances
```bash
gcloud compute instances list --format=json | \
  jq '.[] | {name, zone, machineType: (.machineType | split("/") | last), status, ip: .networkInterfaces[0].accessConfigs[0].natIP}'
```

### List GKE clusters
```bash
gcloud container clusters list --format=json | \
  jq '.[] | {name, location, status, currentNodeCount, currentMasterVersion}'
```

### List Cloud Run services
```bash
gcloud run services list --format=json | \
  jq '.[] | {name: .metadata.name, region: .metadata.labels["cloud.googleapis.com/location"], url: .status.url}'
```

### List Cloud SQL instances
```bash
gcloud sql instances list --format=json | \
  jq '.[] | {name, databaseVersion, state, region, tier: .settings.tier}'
```

### Check Cloud Monitoring alerts
```bash
gcloud alpha monitoring policies list --format=json | \
  jq '.[] | {name: .displayName, enabled, conditions: [.conditions[].displayName]}'
```

### View recent logs
```bash
gcloud logging read "severity>=ERROR AND timestamp>=\"$(date -d '1 hour ago' --iso-8601=seconds)\"" \
  --limit=20 --format=json | jq '.[] | {timestamp, severity, resource: .resource.type, message: .textPayload}'
```
