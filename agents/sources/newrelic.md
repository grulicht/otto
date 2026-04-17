---
name: newrelic
description: New Relic monitoring via NerdGraph API for APM, infrastructure, and alerts
type: api
required_env:
  - OTTO_NEWRELIC_API_KEY
  - OTTO_NEWRELIC_ACCOUNT_ID
required_tools:
  - curl
  - jq
check_command: "curl -sf 'https://api.newrelic.com/graphql' -H 'API-Key: ${OTTO_NEWRELIC_API_KEY}' -H 'Content-Type: application/json' -d '{\"query\":\"{actor{user{name}}}\"}' | jq -r '.data.actor.user.name'"
---

# New Relic

## Connection

OTTO connects to New Relic through the NerdGraph (GraphQL) API using a User API key.

```bash
curl -sf "https://api.newrelic.com/graphql" \
  -H "API-Key: ${OTTO_NEWRELIC_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"<nrql-or-graphql-query>"}'
```

## Available Data

- **APM**: Application performance, transactions, error rates
- **Infrastructure**: Host metrics, processes, integrations
- **Alerts**: Alert policies, conditions, and incidents
- **NRQL**: Run arbitrary NRQL queries
- **Dashboards**: List and manage dashboards
- **Synthetics**: Monitor check results
- **Logs**: Search and analyze log data

## Common Queries

### Run NRQL query
```bash
curl -sf "https://api.newrelic.com/graphql" \
  -H "API-Key: ${OTTO_NEWRELIC_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"{actor{account(id:${OTTO_NEWRELIC_ACCOUNT_ID}){nrql(query:\\\"SELECT count(*) FROM Transaction WHERE error IS true SINCE 1 hour ago TIMESERIES\\\"){results}}}}\"}" | \
  jq '.data.actor.account.nrql.results'
```

### List open incidents
```bash
curl -sf "https://api.newrelic.com/graphql" \
  -H "API-Key: ${OTTO_NEWRELIC_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"{actor{account(id:${OTTO_NEWRELIC_ACCOUNT_ID}){aiIssues{issues(filter:{states:ACTIVATED}){issues{issueId title priority state}}}}}}\"}\" | \
  jq '.data.actor.account.aiIssues.issues.issues[]'
```

### List applications
```bash
curl -sf "https://api.newrelic.com/v2/applications.json" \
  -H "Api-Key: ${OTTO_NEWRELIC_API_KEY}" | \
  jq '.applications[] | {id, name, health_status, reporting}'
```
