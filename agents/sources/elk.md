---
name: elk
description: ELK Stack (Elasticsearch, Logstash, Kibana) for log aggregation and search
type: api
required_env:
  - OTTO_ELASTICSEARCH_URL
required_tools:
  - curl
  - jq
check_command: "curl -sf '${OTTO_ELASTICSEARCH_URL}/_cluster/health' | jq -r '.status'"
---

# ELK Stack

## Connection

OTTO connects to Elasticsearch directly via REST API. Authentication is optional
depending on your setup. Set `OTTO_ELASTICSEARCH_USER` and `OTTO_ELASTICSEARCH_PASSWORD`
for secured clusters.

```bash
ES_AUTH=""
if [[ -n "${OTTO_ELASTICSEARCH_USER:-}" ]]; then
    ES_AUTH="-u ${OTTO_ELASTICSEARCH_USER}:${OTTO_ELASTICSEARCH_PASSWORD}"
fi
curl -sf ${ES_AUTH} "${OTTO_ELASTICSEARCH_URL}/<endpoint>"
```

## Available Data

- **Cluster**: Health, stats, node info, shard allocation
- **Indices**: List, create, delete indices; manage templates and aliases
- **Search**: Full-text search, aggregations, filters
- **Logs**: Application and system log search
- **ILM**: Index lifecycle management policies
- **Kibana**: Saved objects, dashboards (via Kibana API)

## Common Queries

### Cluster health
```bash
curl -sf "${OTTO_ELASTICSEARCH_URL}/_cluster/health?pretty" | \
  jq '{status, number_of_nodes, active_shards, unassigned_shards}'
```

### Search recent error logs
```bash
curl -sf -X POST "${OTTO_ELASTICSEARCH_URL}/logs-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {"bool": {"must": [{"match": {"level": "error"}}, {"range": {"@timestamp": {"gte": "now-1h"}}}]}},
    "size": 20, "sort": [{"@timestamp": "desc"}]
  }' | jq '.hits.hits[]._source | {timestamp: .["@timestamp"], message, service: .service.name}'
```

### List indices
```bash
curl -sf "${OTTO_ELASTICSEARCH_URL}/_cat/indices?format=json&s=index" | \
  jq '.[] | {index, health, status, docs_count: .["docs.count"], store_size: .["store.size"]}'
```

### Index stats
```bash
curl -sf "${OTTO_ELASTICSEARCH_URL}/_stats?pretty" | \
  jq '{total_docs: ._all.total.docs.count, total_size: ._all.total.store.size_in_bytes}'
```
