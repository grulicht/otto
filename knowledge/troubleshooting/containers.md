# Container Troubleshooting (Docker & Kubernetes)

## Image Build Failures

### Multi-stage build issues
**Symptoms:** Build fails at COPY --from=<stage> or wrong artifacts in final image.
**Steps:**
1. Verify stage names match: `FROM golang:1.21 AS builder` -> `COPY --from=builder`
2. Build specific stage to debug: `docker build --target builder -t debug .`
3. Check that source paths in COPY --from match the build stage filesystem
4. Ensure intermediate stages produce expected output: run them standalone

### Build context too large
**Fix:**
1. Check `.dockerignore` -- exclude `node_modules`, `.git`, build artifacts
2. Use `docker build --no-cache` if cache is corrupted
3. Use `docker image history <image>` to find unexpectedly large layers

## Docker Compose Networking

### Services can't communicate
**Steps:**
1. Ensure services are on the same Compose network (default: `<project>_default`)
2. Use service names as hostnames, not `localhost`
3. Check `docker network inspect <network>` for connected containers
4. Verify port is the container port, not the host-mapped port

### Port conflicts
**Fix:**
1. Check `docker ps` and `ss -tlnp` for port usage
2. Change host port mapping: `"8081:80"` instead of `"80:80"`

## Volume Permissions

**Symptoms:** Permission denied errors inside container.
**Steps:**
1. Check UID/GID inside container: `docker exec <c> id`
2. Match host directory ownership: `chown -R 1000:1000 ./data`
3. Use named volumes instead of bind mounts where possible
4. On SELinux hosts, add `:z` or `:Z` suffix to volume mounts
5. In Dockerfile, set `USER` after `chown`ing necessary directories

## Registry Authentication

**Symptoms:** `denied: access forbidden`, `unauthorized: authentication required`
**Steps:**
1. `docker login <registry>` -- verify credentials
2. Check `~/.docker/config.json` for credential helpers
3. For K8s: verify `imagePullSecrets` on the pod/serviceaccount
4. For ECR: `aws ecr get-login-password | docker login --username AWS --password-stdin <ecr-url>`
5. For GCR: `gcloud auth configure-docker`

## Container Resource Limits

**Symptoms:** Container OOMKilled or throttled.
**Steps:**
1. Check exit code: `docker inspect <c> | jq '.[0].State'` -- OOMKilled = exit 137
2. Increase memory limit: `--memory=512m` or in Compose `mem_limit`
3. For K8s: check `kubectl describe pod <pod>` for OOMKilled events
4. Set appropriate requests AND limits in K8s resource spec
5. Monitor actual usage: `docker stats` or `kubectl top pod`

## Kubernetes Init Containers Failing

**Symptoms:** Pod stuck in `Init:CrashLoopBackOff` or `Init:Error`.
**Steps:**
1. `kubectl describe pod <pod>` -- check init container status and events
2. `kubectl logs <pod> -c <init-container>` -- read init container logs
3. Common causes: database not ready, config not mounted, network policy blocking
4. Ensure init container has correct `command` and `args`
5. Check resource limits on init containers separately from main containers

## Sidecar Container Issues

**Symptoms:** Main container healthy but sidecar crashing or vice versa.
**Steps:**
1. Check all container statuses: `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[*].name}'`
2. `kubectl logs <pod> -c <sidecar>` -- check sidecar-specific logs
3. Verify shared volumes between containers are correctly mounted
4. Check if sidecar needs to start before main container (use init containers)
5. For Istio/Envoy sidecars: check proxy status with `istioctl proxy-status`

## Ephemeral Storage Exhaustion

**Symptoms:** Pod evicted with `Evicted` status, `ephemeral-local-storage` exceeded.
**Steps:**
1. `kubectl describe pod <pod>` -- check eviction reason
2. `kubectl exec <pod> -- df -h` -- check storage inside container
3. Common causes: application writing too many logs/temp files to emptyDir
4. Set `ephemeralStorage` limits and requests in resource spec
5. Use persistent volumes for large data instead of ephemeral storage
6. Clean up temp files in application or use log rotation
