# Twelve-Factor App Pattern

## Concept

A methodology for building software-as-a-service applications that are portable,
resilient, and suitable for modern cloud platforms. Originally published by Heroku.

## The Twelve Factors

### I. Codebase
One codebase tracked in version control, many deploys. Each app has one repo.
Multiple deploys (staging, production) run different versions of the same codebase.

### II. Dependencies
Explicitly declare and isolate dependencies. Never rely on system-wide packages.
- Use `requirements.txt`, `package.json`, `go.mod`, `Gemfile`
- Use virtual environments, containers, or vendoring for isolation

### III. Config
Store config in the environment. Config varies between deploys; code does not.
- Database URLs, API keys, feature flags go in env vars
- Never commit config/secrets to the codebase
- Test: could the codebase be open-sourced without exposing credentials?

### IV. Backing Services
Treat backing services (databases, queues, caches, SMTP) as attached resources.
- Swap local MySQL for Amazon RDS without code changes
- Connection details come from config (env vars)

### V. Build, Release, Run
Strictly separate build, release, and run stages.
- **Build**: compile code + dependencies into a build artifact
- **Release**: combine build with config for a specific environment
- **Run**: launch the release in the execution environment
- Every release has a unique ID (timestamp or version)

### VI. Processes
Execute the app as one or more stateless processes.
- Processes share nothing -- any persistent data goes to a backing service
- Session data belongs in a datastore (Redis, database), not local memory/disk
- Enables horizontal scaling

### VII. Port Binding
Export services via port binding. The app is self-contained and binds to a port.
- Web apps export HTTP by binding to a port (not relying on Apache/Tomcat injection)
- One app can become another's backing service via URL

### VIII. Concurrency
Scale out via the process model.
- Different process types for different workloads (web, worker, scheduler)
- Scale by adding more processes, not by making bigger processes
- Never daemonize -- rely on the OS process manager (systemd, containers)

### IX. Disposability
Maximize robustness with fast startup and graceful shutdown.
- Processes can start and stop at a moment's notice
- Handle SIGTERM gracefully: finish current request, release locks, then exit
- Workers should use robust job queues that return jobs on disconnect

### X. Dev/Prod Parity
Keep development, staging, and production as similar as possible.
- Same backing services (use Docker Compose for local dev)
- Same OS and dependency versions
- Deploy frequently to keep the gap small

### XI. Logs
Treat logs as event streams. Apps should write to stdout, never manage log files.
- The execution environment captures, routes, and stores logs
- Use structured logging (JSON) for machine parsing
- Aggregate with ELK, Loki, CloudWatch, or similar

### XII. Admin Processes
Run admin/management tasks as one-off processes.
- Database migrations, console sessions, one-time scripts
- Run in identical environment as regular processes
- Ship admin code with application code

## Implementation Checklist

- [ ] Single repo per service
- [ ] Lock file for all dependencies
- [ ] Config exclusively via environment variables
- [ ] All services connectable via URL/credentials from config
- [ ] CI/CD pipeline with distinct build, release, run stages
- [ ] Stateless application processes
- [ ] App binds to port directly
- [ ] Horizontal scaling via process count
- [ ] Fast startup (<10s), graceful shutdown on SIGTERM
- [ ] Docker Compose mirrors production stack locally
- [ ] Logs to stdout in structured format
- [ ] Database migrations run as separate process
