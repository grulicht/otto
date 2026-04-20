# Microservices Pattern

## Concept

An architectural style that structures an application as a collection of loosely
coupled, independently deployable services. Each service owns its data and
business logic, communicating via well-defined APIs or events.

## Service Decomposition

Strategies for breaking a monolith into services:
- **By business capability**: Order Service, Payment Service, Inventory Service
- **By subdomain** (DDD): Bounded contexts map to services
- **By team**: Each team owns and operates their services
- **Strangler fig**: Gradually replace monolith pieces with services

Rules of thumb:
- One service = one deployable unit = one team
- A service should be replaceable in 2 weeks
- If two services always deploy together, merge them

## API Gateway

Single entry point for all clients that routes requests to services.

**Responsibilities:**
- Request routing and composition
- Authentication and rate limiting
- SSL termination and protocol translation
- Response caching
- API versioning

**Tools:** Kong, Traefik, NGINX, AWS API Gateway, Envoy

## Service Discovery

How services find each other at runtime.

- **Client-side discovery**: Client queries registry (Consul, Eureka) and load-balances
- **Server-side discovery**: Load balancer queries registry (K8s Services, AWS ALB)
- **DNS-based**: Services register DNS records (Consul DNS, CoreDNS)

In Kubernetes, service discovery is built in via DNS (`<service>.<namespace>.svc.cluster.local`).

## Circuit Breaker

Prevent cascade failures when a downstream service is unhealthy.

**States:**
1. **Closed**: Requests flow normally, failures are counted
2. **Open**: Requests fail immediately without calling downstream (after failure threshold)
3. **Half-open**: Allow a limited number of test requests to check recovery

**Tools:** Hystrix (legacy), Resilience4j, Istio, Linkerd, Polly (.NET)

## Saga Pattern

Manage distributed transactions across multiple services without 2PC.

**Choreography:** Each service listens for events and acts accordingly.
- Service A publishes event -> Service B reacts -> Service B publishes event -> ...
- Compensating transactions on failure (reverse operations)

**Orchestration:** A central saga orchestrator coordinates the steps.
- Orchestrator tells each service what to do
- Easier to understand, single point of coordination

## Event Sourcing

Store state as a sequence of events rather than current state.
- Every state change is an immutable event in an append-only log
- Current state is derived by replaying events
- Full audit trail and ability to reconstruct past states
- Works well with CQRS

## CQRS (Command Query Responsibility Segregation)

Separate read and write models.
- **Command side**: Handles writes, validates business rules, stores events
- **Query side**: Optimized read models, possibly denormalized, eventually consistent
- Enables independent scaling of reads and writes

## Sidecar Pattern

Deploy helper functionality as a separate process alongside the main service.

**Common sidecars:**
- Service mesh proxy (Envoy/Istio)
- Log collector (Fluentd/Filebeat)
- Config sync agent
- Certificate manager

Benefits: language-agnostic, independent lifecycle, separation of concerns.

## Strangler Fig Migration

Incrementally migrate from monolith to microservices.

**Steps:**
1. Place a facade/proxy in front of the monolith
2. Implement new features as microservices behind the facade
3. Gradually move existing functionality to new services
4. Route traffic from facade to new services as they become ready
5. Eventually decommission the monolith

**Key:** Never do a big-bang rewrite. Migrate incrementally with both systems running.

## Best Practices

- Design for failure: every remote call can fail
- Implement health checks and readiness probes
- Use distributed tracing (Jaeger, Zipkin, OpenTelemetry)
- Centralize logging and monitoring
- Automate everything: CI/CD, infrastructure, testing
- Use contracts (OpenAPI, Protobuf) between services
- Prefer asynchronous communication where possible
- Each service owns its database -- no shared databases
