# Kubernetes Node Recovery Runbook
tags: kubernetes, k8s, node, recovery, kubelet, NotReady

## Overview
Recover a Kubernetes node that is in NotReady state or otherwise unhealthy.

## Step 1: Diagnose NotReady Node

```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check conditions
kubectl get node <node-name> -o jsonpath='{.status.conditions[*].type}{"\n"}{.status.conditions[*].status}'

# Common conditions to check:
# - Ready: False (node is not healthy)
# - MemoryPressure: True (node is low on memory)
# - DiskPressure: True (node is low on disk)
# - PIDPressure: True (too many processes)
# - NetworkUnavailable: True (network plugin issue)
```

## Step 2: Check Kubelet

```bash
# SSH to the node
ssh <node-name>

# Check kubelet status
systemctl status kubelet
journalctl -u kubelet --since "30 minutes ago" --no-pager | tail -50

# Common kubelet issues:
# - Certificate expired
# - Cannot reach API server
# - Container runtime not running
# - Disk space exhausted

# Check container runtime
systemctl status containerd   # or docker, cri-o
crictl ps                     # list running containers
crictl info                   # runtime info
```

## Step 3: Drain the Node

Before making changes, safely evacuate workloads:

```bash
# Drain node (evict pods gracefully)
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s

# Verify pods moved
kubectl get pods -A -o wide | grep <node-name>
```

## Step 4: Fix Underlying Issue

### Disk Pressure
```bash
# Check disk usage
df -h
du -sh /var/log/*
du -sh /var/lib/containerd/*

# Clean up
journalctl --vacuum-size=500M
crictl rmi --prune
find /var/log -name "*.gz" -mtime +7 -delete
```

### Memory Pressure
```bash
# Check memory
free -h
ps aux --sort=-%mem | head -20

# Kill memory-hogging processes if safe
# Or increase node size (cloud)
```

### Kubelet Certificate Expired
```bash
# Check certificate
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# Rotate certificates
sudo kubeadm certs renew all
sudo systemctl restart kubelet
```

### Container Runtime Issues
```bash
# Restart container runtime
sudo systemctl restart containerd
sudo systemctl restart kubelet

# If runtime is corrupted
sudo systemctl stop kubelet
sudo systemctl stop containerd
sudo rm -rf /var/lib/containerd/io.containerd.metadata.v1.bolt/meta.db
sudo systemctl start containerd
sudo systemctl start kubelet
```

### Network Issues
```bash
# Check CNI plugin
ls /etc/cni/net.d/
ls /opt/cni/bin/

# Restart network plugin (example: Calico)
kubectl delete pod -n kube-system -l k8s-app=calico-node --field-selector spec.nodeName=<node-name>

# Check kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide | grep <node-name>
```

## Step 5: Uncordon the Node

After fixing the issue:

```bash
# Restart kubelet if not already done
sudo systemctl restart kubelet

# Wait for node to become Ready
kubectl get node <node-name> -w

# Uncordon to allow scheduling
kubectl uncordon <node-name>
```

## Step 6: Verify Recovery

```bash
# Check node is Ready
kubectl get node <node-name>

# Check all conditions are healthy
kubectl describe node <node-name> | grep -A5 "Conditions:"

# Verify pods are scheduling
kubectl run test-pod --image=busybox --restart=Never --command -- sleep 10
kubectl get pod test-pod -o wide
kubectl delete pod test-pod

# Check node metrics (if metrics-server is installed)
kubectl top node <node-name>
```

## If Node Cannot Be Recovered

For cloud environments, replace the node:

```bash
# Drain the node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force

# Delete the node from cluster
kubectl delete node <node-name>

# Terminate the instance (cloud-specific)
# AWS: aws ec2 terminate-instances --instance-ids <id>
# GCP: gcloud compute instances delete <name>

# Auto-scaling group will create a replacement
# Or manually provision a new node and join it
```
