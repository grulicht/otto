---
name: wazuh
description: Wazuh security platform via REST API for SIEM, threat detection, and compliance
type: api
required_env:
  - OTTO_WAZUH_URL
  - OTTO_WAZUH_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -k -H 'Authorization: Bearer ${OTTO_WAZUH_TOKEN}' '${OTTO_WAZUH_URL}/' | jq -r '.data.title'"
---

# Wazuh

## Connection

OTTO connects to Wazuh through its REST API. Authentication uses a JWT token
obtained by authenticating with user credentials, or a pre-configured API token.

**Token-based** (preferred):
```bash
curl -sf -k -H "Authorization: Bearer ${OTTO_WAZUH_TOKEN}" \
  "${OTTO_WAZUH_URL}/<endpoint>"
```

**Credential-based** (obtain token first):
```bash
OTTO_WAZUH_TOKEN=$(curl -sf -k -u "${OTTO_WAZUH_USER}:${OTTO_WAZUH_PASSWORD}" \
  -X POST "${OTTO_WAZUH_URL}/security/user/authenticate" | jq -r '.data.token')
```

Note: Wazuh API uses self-signed certificates by default; use `-k` to skip
TLS verification, or configure `OTTO_WAZUH_CA_CERT` for proper verification.

## Available Data

- **Agents**: List managed agents, their status, OS info, and last keep-alive
- **Alerts**: Security alerts with severity levels and MITRE ATT&CK mapping
- **Vulnerabilities**: Detected vulnerabilities on managed agents
- **SCA (Security Configuration Assessment)**: Compliance check results
- **FIM (File Integrity Monitoring)**: File change events
- **Rootcheck**: Rootkit detection results
- **Syscollector**: Hardware, software, network, and process inventory
- **Rules**: Active detection rules and decoders
- **Cluster**: Wazuh cluster node status
- **Logs**: Wazuh manager logs

## Common Queries

### List agents and their status
```bash
curl -sf -k -H "Authorization: Bearer ${OTTO_WAZUH_TOKEN}" \
  "${OTTO_WAZUH_URL}/agents?select=id,name,ip,status,os.name,lastKeepAlive&limit=50" | \
  jq '.data.affected_items'
```

### Get recent alerts (high severity)
```bash
curl -sf -k -H "Authorization: Bearer ${OTTO_WAZUH_TOKEN}" \
  "${OTTO_WAZUH_URL}/alerts?limit=20&sort=-timestamp&q=rule.level>10" | \
  jq '.data.affected_items[] | {id: .id, level: .rule.level, description: .rule.description, agent: .agent.name}'
```

### Get agent vulnerabilities
```bash
curl -sf -k -H "Authorization: Bearer ${OTTO_WAZUH_TOKEN}" \
  "${OTTO_WAZUH_URL}/vulnerability/<agent-id>?limit=20&sort=-cvss3_score" | \
  jq '.data.affected_items[] | {cve: .cve, severity: .severity, package: .name}'
```

### SCA compliance results
```bash
curl -sf -k -H "Authorization: Bearer ${OTTO_WAZUH_TOKEN}" \
  "${OTTO_WAZUH_URL}/sca/<agent-id>" | \
  jq '.data.affected_items[] | {policy: .name, pass: .pass, fail: .fail, score: .score}'
```

### FIM events for an agent
```bash
curl -sf -k -H "Authorization: Bearer ${OTTO_WAZUH_TOKEN}" \
  "${OTTO_WAZUH_URL}/syscheck/<agent-id>?limit=20&sort=-date" | \
  jq '.data.affected_items[] | {file: .file, event: .event, date: .date}'
```

### Cluster status
```bash
curl -sf -k -H "Authorization: Bearer ${OTTO_WAZUH_TOKEN}" \
  "${OTTO_WAZUH_URL}/cluster/status" | jq '.data'
```
