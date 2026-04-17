---
name: docker
description: Docker container runtime via docker CLI for container and image management
type: cli
required_env: []
required_tools:
  - docker
  - jq
check_command: "docker info --format '{{.ServerVersion}}' 2>/dev/null"
---

# Docker

## Connection

OTTO connects to Docker through the `docker` CLI, which communicates with the
Docker daemon via the Unix socket (`/var/run/docker.sock`) or a remote host
specified by `DOCKER_HOST`.

```bash
docker info              # verify Docker connectivity
docker version           # show client and server versions
```

For Docker Compose workloads, ensure `docker compose` (v2) or `docker-compose`
(v1) is available.

## Available Data

- **Containers**: List, inspect, start, stop, restart, and remove containers
- **Images**: List, pull, push, build, and remove images
- **Volumes**: List, create, inspect, and remove volumes
- **Networks**: List, create, inspect, and remove networks
- **Logs**: View container logs with filtering
- **Stats**: Real-time resource usage statistics
- **Compose**: Manage multi-container applications
- **System**: Disk usage, system events, and pruning

## Common Queries

### List running containers
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}'
```

### Container resource usage
```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'
```

### View container logs
```bash
docker logs --tail=100 --timestamps <container>
docker logs --since=1h <container> 2>&1 | grep -i error
```

### Inspect container details
```bash
docker inspect <container> | jq '.[0] | {
  State: .State.Status,
  Health: .State.Health.Status,
  Image: .Config.Image,
  Created: .Created,
  RestartCount: .RestartCount,
  Ports: .NetworkSettings.Ports
}'
```

### List images with sizes
```bash
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'
```

### Docker Compose status
```bash
docker compose ps
docker compose logs --tail=50 <service>
```

### System disk usage
```bash
docker system df -v
```

### View recent events
```bash
docker events --since=1h --until="$(date -Iseconds)" --format '{{.Time}} {{.Type}} {{.Action}} {{.Actor.Attributes.name}}'
```
