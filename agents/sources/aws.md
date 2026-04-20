---
name: aws
description: Amazon Web Services via aws CLI for cloud infrastructure management
type: cli
required_env: []
required_tools:
  - aws
  - jq
check_command: "aws sts get-caller-identity --output json 2>/dev/null | jq -r '.Account'"
fetch_script: cloud-aws.sh
---

> **Note:** The fetch script for this source is named `cloud-aws.sh` (not `aws.sh`), located in `scripts/fetch/cloud-aws.sh`.

# AWS

## Connection

OTTO connects to AWS through the `aws` CLI, which handles authentication via
environment variables, shared credentials file (`~/.aws/credentials`), IAM
instance profiles, or SSO.

```bash
aws sts get-caller-identity   # verify authentication and account
aws configure list             # show current configuration
```

Authentication methods (in priority order):
1. Environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
2. AWS profile: `AWS_PROFILE` or `--profile <name>`
3. Shared credentials file: `~/.aws/credentials`
4. IAM instance role (EC2/ECS/Lambda)
5. SSO: `aws sso login --profile <name>`

Set the region with `AWS_DEFAULT_REGION` or `--region <region>`.

## Available Data

- **EC2**: Instances, security groups, AMIs, EBS volumes, load balancers
- **ECS/EKS**: Container services, clusters, task definitions
- **S3**: Buckets, objects, bucket policies
- **RDS**: Database instances, snapshots, parameter groups
- **Lambda**: Functions, invocations, layers
- **CloudWatch**: Metrics, alarms, log groups
- **IAM**: Users, roles, policies, access keys
- **Route53**: DNS zones and records
- **CloudFormation**: Stacks and resources
- **SSM**: Parameter Store, Session Manager, patch compliance
- **Cost Explorer**: Cost and usage reports

## Common Queries

### List EC2 instances
```bash
aws ec2 describe-instances --output json | jq '[.Reservations[].Instances[] | {
  id: .InstanceId, name: (.Tags // [] | map(select(.Key=="Name")) | .[0].Value // "unnamed"),
  state: .State.Name, type: .InstanceType, az: .Placement.AvailabilityZone
}]'
```

### Check CloudWatch alarms
```bash
aws cloudwatch describe-alarms --state-value ALARM --output json | \
  jq '[.MetricAlarms[] | {name: .AlarmName, state: .StateValue, reason: .StateReason}]'
```

### List ECS services
```bash
aws ecs list-clusters --output json | jq -r '.clusterArns[]' | while read -r cluster; do
  aws ecs list-services --cluster "${cluster}" --output json | jq -r '.serviceArns[]'
done
```

### Get RDS instance status
```bash
aws rds describe-db-instances --output json | jq '[.DBInstances[] | {
  id: .DBInstanceIdentifier, engine: .Engine, status: .DBInstanceStatus, az: .AvailabilityZone
}]'
```

### List recent CloudWatch log events
```bash
aws logs filter-log-events --log-group-name <group> --start-time "$(date -d '1 hour ago' +%s)000" \
  --filter-pattern "ERROR" --limit 20 --output json | jq '.events[] | {timestamp: .timestamp, message: .message}'
```

### SSM Parameter Store
```bash
aws ssm get-parameters-by-path --path "/myapp/" --recursive --with-decryption --output json | \
  jq '[.Parameters[] | {name: .Name, type: .Type}]'
```
