# AWS Troubleshooting

## EC2 Instance Unreachable
**Symptoms:** Cannot SSH or connect to EC2 instance, health check failing.
**Steps:**
1. Check instance state: `aws ec2 describe-instance-status --instance-ids <id>`
2. Check system status checks (hypervisor) vs instance status checks (OS)
3. Verify security group allows inbound traffic on required ports
4. Check Network ACLs on the subnet (stateless - need both inbound AND outbound rules)
5. Verify route table has route to internet gateway (for public instances)
6. Check if public IP/EIP is assigned
7. Use EC2 Serial Console or Instance Connect if SSH is down
8. Check system log: `aws ec2 get-console-output --instance-id <id>`
9. If new instance: verify AMI, user data script, key pair

## S3 Access Denied
**Symptoms:** `403 Access Denied` when accessing S3 objects or buckets.
**Steps:**
1. Check IAM policy attached to user/role
2. Check S3 bucket policy: `aws s3api get-bucket-policy --bucket <name>`
3. Check S3 Block Public Access settings (account and bucket level)
4. Verify the request is using correct credentials: `aws sts get-caller-identity`
5. Check for explicit denies - they override all allows
6. If cross-account: both source IAM policy AND bucket policy must allow
7. Check object ownership: objects uploaded by other accounts may not grant bucket owner access
8. Enable S3 access logging or use CloudTrail to diagnose

## RDS Connection Issues
**Symptoms:** Cannot connect to RDS instance, timeouts.
**Steps:**
1. Check RDS instance status: `aws rds describe-db-instances`
2. Verify security group allows inbound on database port (3306/5432)
3. Check if RDS is in a private subnet - need VPN/bastion/VPC peering to connect
4. Verify DNS resolution of RDS endpoint
5. Check if `Publicly Accessible` is set correctly
6. Verify database user credentials and authentication method
7. Check RDS parameter group for `max_connections`
8. Review RDS event logs: `aws rds describe-events`

## EKS Node Not Joining Cluster
**Symptoms:** EC2 instances in node group but not appearing in `kubectl get nodes`.
**Steps:**
1. Check node group status: `aws eks describe-nodegroup`
2. Verify IAM role has required policies: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
3. Check aws-auth ConfigMap: `kubectl -n kube-system get configmap aws-auth -o yaml`
4. SSH to node and check kubelet logs: `journalctl -u kubelet`
5. Verify node can reach EKS API endpoint (VPC endpoint or internet)
6. Check Security Groups: nodes need to communicate with control plane
7. Verify AMI is compatible with EKS version

## IAM Permission Errors
**Symptoms:** `AccessDeniedException`, `UnauthorizedAccess`, `is not authorized to perform`.
**Steps:**
1. Identify who you are: `aws sts get-caller-identity`
2. Check attached policies: `aws iam list-attached-user-policies`, `aws iam list-attached-role-policies`
3. Check inline policies: `aws iam list-user-policies`, `aws iam list-role-policies`
4. Use IAM Policy Simulator: `aws iam simulate-principal-policy`
5. Check for permission boundaries limiting effective permissions
6. Check for SCPs (Service Control Policies) at the organization level
7. Look for explicit denies in any applicable policy
8. Enable CloudTrail and check the `errorCode` and `errorMessage`

## Billing Alerts
**Symptoms:** Unexpected charges, cost spikes.
**Steps:**
1. Check Cost Explorer: `aws ce get-cost-and-usage`
2. Look for idle resources: unattached EBS volumes, unused EIPs, stopped instances with EBS
3. Check for unexpected regions: resources in regions you don't use
4. Review NAT Gateway charges (data processing fees)
5. Check S3 request costs (especially LIST operations)
6. Look for large data transfer charges (cross-AZ, cross-region, internet)
7. Set up AWS Budgets with alerts: `aws budgets create-budget`
8. Use Cost Anomaly Detection for automatic alerts
