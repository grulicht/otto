---
name: cloud-gcp
description: GCP cloud infrastructure overview (alias for gcp source)
type: cli
required_env: []
required_tools:
  - gcloud
check_command: "gcloud config get-value project 2>/dev/null"
---

# Cloud - GCP

## Connection

Alias for the `gcp` source. OTTO connects to GCP through the `gcloud` CLI.
See `agents/sources/gcp.md` for full authentication details.

```bash
gcloud auth list           # verify authentication
gcloud config get-value project  # check active project
```

## Available Data

- **Compute**: GCE instances, Cloud Run services, GKE clusters
- **Storage**: GCS buckets, Persistent Disks
- **Database**: Cloud SQL, Firestore, Bigtable instances
- **Networking**: VPCs, firewall rules, load balancers
- **Monitoring**: Cloud Monitoring alerts and metrics
- **IAM**: Service accounts, roles, and bindings

## Common Queries

### List compute instances
```bash
gcloud compute instances list --format="table(name,zone,status,machineType.basename(),networkInterfaces[0].accessConfigs[0].natIP)"
```

### Active GKE clusters
```bash
gcloud container clusters list --format="table(name,location,status,currentNodeCount)"
```

### Cloud SQL instances
```bash
gcloud sql instances list --format="table(name,databaseVersion,state,region)"
```

### List GCS buckets
```bash
gcloud storage ls
```
