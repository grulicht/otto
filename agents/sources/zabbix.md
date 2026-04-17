---
name: zabbix
description: Zabbix monitoring system via JSON-RPC API
type: api
required_env:
  - OTTO_ZABBIX_URL
  - OTTO_ZABBIX_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"apiinfo.version\",\"params\":{},\"id\":1}' '${OTTO_ZABBIX_URL}/api_jsonrpc.php' | jq -r '.result'"
---

# Zabbix

## Connection

OTTO connects to Zabbix through its JSON-RPC API. Authentication uses an API token
(Zabbix 5.4+) or session-based login with username/password.

**API token** (preferred, Zabbix 5.4+):
```bash
curl -sf -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OTTO_ZABBIX_TOKEN}" \
  -d '{"jsonrpc":"2.0","method":"<method>","params":{...},"id":1}' \
  "${OTTO_ZABBIX_URL}/api_jsonrpc.php"
```

**Session-based** (legacy):
```bash
# Login first, then use the auth token in subsequent requests
curl -sf -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"user.login","params":{"username":"...","password":"..."},"id":1}' \
  "${OTTO_ZABBIX_URL}/api_jsonrpc.php"
```

## Available Data

- **Hosts**: List, search, and manage monitored hosts and host groups
- **Problems**: List active problems (triggers in PROBLEM state)
- **Triggers**: View trigger configuration and status
- **Items**: List monitored items and retrieve latest values
- **History**: Query historical metric data for items
- **Events**: List events (problem creation, recovery, acknowledgments)
- **Templates**: List and manage monitoring templates
- **Maintenance**: List and manage maintenance windows
- **Actions**: List configured automated actions
- **Discovery**: View auto-discovered hosts and services

## Common Queries

### Get active problems
```bash
curl -sf -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OTTO_ZABBIX_TOKEN}" \
  -d '{"jsonrpc":"2.0","method":"problem.get","params":{"output":"extend","sortfield":"eventid","sortorder":"DESC","limit":50},"id":1}' \
  "${OTTO_ZABBIX_URL}/api_jsonrpc.php" | jq '.result'
```

### List hosts
```bash
curl -sf -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OTTO_ZABBIX_TOKEN}" \
  -d '{"jsonrpc":"2.0","method":"host.get","params":{"output":["hostid","host","name","status"],"selectInterfaces":["ip"]},"id":1}' \
  "${OTTO_ZABBIX_URL}/api_jsonrpc.php" | jq '.result'
```

### Get latest item values for a host
```bash
curl -sf -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OTTO_ZABBIX_TOKEN}" \
  -d '{"jsonrpc":"2.0","method":"item.get","params":{"hostids":"<hostid>","output":["name","lastvalue","lastclock"],"sortfield":"name","limit":50},"id":1}' \
  "${OTTO_ZABBIX_URL}/api_jsonrpc.php" | jq '.result'
```

### Acknowledge a problem
```bash
curl -sf -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OTTO_ZABBIX_TOKEN}" \
  -d '{"jsonrpc":"2.0","method":"event.acknowledge","params":{"eventids":"<eventid>","action":6,"message":"Acknowledged by OTTO"},"id":1}' \
  "${OTTO_ZABBIX_URL}/api_jsonrpc.php" | jq '.result'
```
