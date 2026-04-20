---
name: cloud-aws
description: AWS cloud infrastructure overview (alias for aws source)
type: cli
required_env: []
required_tools:
  - aws
check_command: "aws sts get-caller-identity --output json 2>/dev/null | jq -r '.Account'"
---

# Cloud - AWS

## Connection

Alias for the `aws` source. OTTO connects to AWS through the `aws` CLI.
See `agents/sources/aws.md` for full authentication details.

```bash
aws sts get-caller-identity   # verify authentication
```

## Available Data

- **Compute**: EC2 instances, Lambda functions, ECS/EKS clusters
- **Storage**: S3 buckets, EBS volumes, EFS filesystems
- **Database**: RDS, DynamoDB, ElastiCache instances
- **Networking**: VPCs, subnets, security groups, load balancers
- **Monitoring**: CloudWatch alarms and metrics
- **Cost**: Current billing and cost breakdown
- **IAM**: Users, roles, and policy summary

## Common Queries

### Account overview
```bash
aws ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType}' --output table
```

### Active alarms
```bash
aws cloudwatch describe-alarms --state-value ALARM --output table
```

### S3 bucket list
```bash
aws s3 ls
```

### Current month costs
```bash
aws ce get-cost-and-usage --time-period "Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d)" \
  --granularity MONTHLY --metrics BlendedCost --output json | jq '.ResultsByTime[].Total.BlendedCost'
```
