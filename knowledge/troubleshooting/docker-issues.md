# Docker Common Issues

## Container Won't Start
**Steps:**
1. `docker logs <container>` - check startup logs
2. `docker inspect <container>` - check configuration, mounts, env
3. Common causes: wrong entrypoint, missing env vars, port conflict, volume permissions

## Image Build Fails
**Steps:**
1. Check Dockerfile syntax and context path
2. Run failing RUN command manually in base image
3. Check .dockerignore isn't excluding needed files
4. Common causes: package not found (wrong base image), COPY source missing

## "No space left on device"
**Fix:**
1. `docker system prune -a` - remove unused images, containers, volumes
2. `docker volume prune` - remove unused volumes
3. Check Docker data root: `docker info | grep "Docker Root Dir"`

## Networking Issues
**Container can't reach internet:**
1. Check DNS: `docker exec <container> nslookup google.com`
2. Check iptables/firewall rules on host
3. Restart Docker daemon

**Container can't reach another container:**
1. Ensure both on same Docker network
2. Use container names for DNS (not IPs)
3. Check if port is exposed correctly

## Permission Denied
**Volume mount permission issues:**
1. Check UID/GID inside container vs host
2. Use `--user` flag or set USER in Dockerfile
3. Consider `:z` or `:Z` SELinux flags on mounts
