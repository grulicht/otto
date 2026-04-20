# Fetch Scripts Reference

Fetch scripts live in `scripts/fetch/` and are responsible for collecting data
from external systems. Each script corresponds to a source definition in
`agents/sources/`.

## Script Summary

| Script | Description | Required Tools | Required Env Vars |
|--------|-------------|---------------|-------------------|
| `alloy.sh` | Grafana Alloy observability pipeline | alloy | |
| `ansible.sh` | Ansible automation status | ansible, ansible-playbook | |
| `backup-status.sh` | Aggregated backup status (Restic, Borg, Velero) | restic, borg, velero | |
| `bitbucket.sh` | Bitbucket repositories and pipelines | curl, jq | OTTO_BITBUCKET_URL, OTTO_BITBUCKET_TOKEN |
| `borg.sh` | BorgBackup repository status | borg | BORG_REPO |
| `cloud-aws.sh` | AWS cloud infrastructure overview | aws, jq | |
| `cloud-azure.sh` | Azure cloud infrastructure overview | az, jq | |
| `cloud-digitalocean.sh` | DigitalOcean infrastructure overview | doctl | |
| `cloud-gcp.sh` | GCP cloud infrastructure overview | gcloud | |
| `cloud-hetzner.sh` | Hetzner Cloud infrastructure overview | hcloud | |
| `confluence.sh` | Confluence wiki spaces and pages | curl, jq | OTTO_CONFLUENCE_URL, OTTO_CONFLUENCE_TOKEN |
| `datadog.sh` | Datadog monitoring and alerts | curl, jq | OTTO_DATADOG_API_KEY, OTTO_DATADOG_APP_KEY |
| `digitalocean.sh` | DigitalOcean droplets and resources | doctl | |
| `discord.sh` | Discord notifications | curl, jq | OTTO_DISCORD_WEBHOOK_URL |
| `dns-check.sh` | DNS health checking | dig | OTTO_DNS_DOMAINS |
| `docker.sh` | Docker container and image management | docker, jq | |
| `elk.sh` | Elasticsearch/Logstash/Kibana stack | curl, jq | OTTO_ELASTICSEARCH_URL |
| `email.sh` | Email notifications | curl | OTTO_SMTP_HOST |
| `github.sh` | GitHub repositories, PRs, and actions | gh, jq | |
| `gitlab.sh` | GitLab projects and pipelines | curl, jq | OTTO_GITLAB_URL, OTTO_GITLAB_TOKEN |
| `grafana.sh` | Grafana dashboards and alerts | curl, jq | OTTO_GRAFANA_URL, OTTO_GRAFANA_TOKEN |
| `hetzner.sh` | Hetzner Cloud servers and resources | hcloud | |
| `jira.sh` | Jira issues and boards | curl, jq | OTTO_JIRA_URL, OTTO_JIRA_TOKEN |
| `kubernetes.sh` | Kubernetes cluster status | kubectl, jq | |
| `linear.sh` | Linear issues and projects | curl, jq | OTTO_LINEAR_API_KEY |
| `loki.sh` | Grafana Loki log queries | logcli, jq | OTTO_LOKI_URL |
| `mimir.sh` | Grafana Mimir metrics | curl, jq | OTTO_MIMIR_URL |
| `newrelic.sh` | New Relic monitoring | curl, jq | OTTO_NEWRELIC_API_KEY |
| `nginx.sh` | Nginx web server status | nginx, openssl | |
| `opsgenie.sh` | OpsGenie alerts and on-call | curl, jq | OTTO_OPSGENIE_API_KEY |
| `pagerduty.sh` | PagerDuty incidents and services | curl, jq | OTTO_PAGERDUTY_TOKEN |
| `prometheus.sh` | Prometheus metrics and alerts | promtool, curl, jq | OTTO_PROMETHEUS_URL |
| `proxmox.sh` | Proxmox VE cluster status | curl, jq | OTTO_PROXMOX_URL, OTTO_PROXMOX_TOKEN |
| `restic.sh` | Restic backup repository status | restic | RESTIC_REPOSITORY |
| `rocketchat.sh` | Rocket.Chat notifications | curl, jq | OTTO_ROCKETCHAT_URL, OTTO_ROCKETCHAT_TOKEN |
| `security-events.sh` | Local security events and auth logs | journalctl, lastb | |
| `server-health.sh` | Local server health (CPU, RAM, disk) | free, df, uptime | |
| `slack.sh` | Slack notifications | curl, jq | OTTO_SLACK_WEBHOOK_URL |
| `ssl-certs.sh` | SSL certificate monitoring | openssl | OTTO_SSL_DOMAINS |
| `statuspage.sh` | Statuspage.io status | curl, jq | OTTO_STATUSPAGE_API_KEY |
| `systemd-services.sh` | Systemd service monitoring | systemctl | |
| `teams.sh` | Microsoft Teams notifications | curl, jq | OTTO_TEAMS_WEBHOOK_URL |
| `telegram.sh` | Telegram notifications | curl, jq | OTTO_TELEGRAM_BOT_TOKEN, OTTO_TELEGRAM_CHAT_ID |
| `terraform.sh` | Terraform state and plan | terraform, jq | |
| `vault.sh` | HashiCorp Vault status and health | vault, jq | VAULT_ADDR |
| `velero.sh` | Velero Kubernetes backup status | velero | |
| `wazuh.sh` | Wazuh security monitoring | curl, jq | OTTO_WAZUH_URL, OTTO_WAZUH_TOKEN |
| `zabbix.sh` | Zabbix monitoring | curl, jq | OTTO_ZABBIX_URL, OTTO_ZABBIX_TOKEN |

## Usage

Fetch scripts are called automatically by OTTO agents and the Night Watcher.
They can also be invoked directly:

```bash
# Run a specific fetch script
./scripts/fetch/docker.sh

# Run with debug output
OTTO_DEBUG=1 ./scripts/fetch/server-health.sh
```

Each script outputs JSON to stdout, which is then consumed by the relevant
agent for analysis and reporting.

## Adding New Fetch Scripts

1. Create the script in `scripts/fetch/<name>.sh`
2. Create a matching source definition in `agents/sources/<name>.md`
3. Follow the existing patterns: output JSON, check for required tools, handle errors
4. Add tests in `tests/fetch/`
