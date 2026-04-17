# Docker Best Practices

## Dockerfile
- Use specific base image tags, never `latest`
- Use multi-stage builds to minimize image size
- Order layers from least to most frequently changed
- Combine RUN commands to reduce layers
- Use .dockerignore to exclude unnecessary files
- Run as non-root user (USER directive)
- Use COPY instead of ADD (unless tar extraction needed)
- Set HEALTHCHECK for container health monitoring

## Security
- Scan images for vulnerabilities (Trivy, Snyk)
- Don't store secrets in images (use build args or runtime injection)
- Use read-only root filesystem where possible
- Drop all capabilities and add only what's needed
- Use trusted base images (official or verified publisher)

## Image Management
- Use semantic versioning for image tags
- Tag with git SHA for traceability
- Clean up unused images regularly
- Use registry mirroring for frequently pulled images

## Compose
- Use named volumes for persistent data
- Define resource limits (deploy.resources)
- Use depends_on with health conditions
- Use .env files for environment variables (don't commit secrets)
- Use profiles for optional services

## Networking
- Use user-defined bridge networks (not default bridge)
- Expose only necessary ports
- Use container names for inter-service communication
