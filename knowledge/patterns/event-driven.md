# Event-Driven Architecture

## Concept

A software architecture pattern where the flow of the program is determined by
events -- significant changes in state. Components communicate by producing and
consuming events rather than direct API calls.

## Event Sourcing

Store all changes as a sequence of immutable events.

```
OrderCreated -> ItemsAdded -> PaymentProcessed -> OrderShipped
```

- Current state = replay of all events from the beginning
- Enables temporal queries ("what was the state on Tuesday?")
- Append-only log provides a complete audit trail
- Snapshots optimize replay for long event streams

**Event store options:** EventStoreDB, Apache Kafka (with compaction), PostgreSQL (append-only table)

## Message Queues

### RabbitMQ
- AMQP protocol, flexible routing via exchanges
- Patterns: direct, topic, fanout, headers
- Best for: task queues, RPC, complex routing
- Features: dead letter queues, TTL, priority queues, message acknowledgment

### Apache Kafka
- Distributed commit log, high throughput, durable
- Consumer groups for parallel processing
- Topic partitions for ordering guarantees within a partition
- Best for: event streaming, log aggregation, high-volume data pipelines
- Retention: time-based or size-based, compacted topics for latest-value semantics

## Pub/Sub Pattern

Publishers emit events without knowing who consumes them.

- **Topic-based**: Subscribers filter by topic/channel name
- **Content-based**: Subscribers filter by event content/attributes
- Decouples producers from consumers completely
- Tools: Kafka, RabbitMQ, Redis Pub/Sub, Google Pub/Sub, AWS SNS/SQS, NATS

## Webhook Patterns

HTTP callbacks for event notification between systems.

**Best practices:**
- Use HMAC signatures to verify webhook authenticity
- Return 2xx quickly, process asynchronously
- Implement retry with exponential backoff on the sender side
- Provide a webhook test/ping endpoint
- Log all incoming webhooks for debugging
- Set reasonable timeouts (5-30 seconds)

## Idempotent Consumers

Ensure processing an event multiple times produces the same result.

**Strategies:**
- Include a unique event ID; track processed IDs in a deduplication table
- Use database upserts instead of inserts
- Design operations to be naturally idempotent (set value vs. increment)
- Use optimistic concurrency (version fields)

## Dead Letter Queues (DLQ)

Capture messages that cannot be processed after repeated attempts.

**Setup:**
1. Configure max retry count on the main queue (e.g., 3 retries)
2. After max retries, route message to DLQ
3. Monitor DLQ size -- alert if messages accumulate
4. Inspect and replay DLQ messages after fixing the issue
5. Include original error reason with the dead-lettered message

## Event Schema Evolution

Handle changes to event structure over time without breaking consumers.

**Strategies:**
- **Schema registry**: Centralized schema management (Confluent Schema Registry, Apicurio)
- **Backward compatible changes**: Add optional fields, never remove/rename fields
- **Versioned events**: `OrderCreated.v1`, `OrderCreated.v2`
- **Consumer-driven contracts**: Consumers declare what fields they need
- Use Avro, Protobuf, or JSON Schema for formal schema definition

**Compatibility rules:**
- Backward compatible: new schema can read old data
- Forward compatible: old schema can read new data
- Full compatible: both directions work

## Best Practices

- Use correlation IDs to trace events across services
- Design events as facts (past tense: OrderCreated, not CreateOrder)
- Keep events small -- include IDs, not full objects
- Ensure at-least-once delivery; design consumers for idempotency
- Monitor consumer lag (Kafka) or queue depth (RabbitMQ)
- Set appropriate retention policies
- Document event schemas and publish a catalog
