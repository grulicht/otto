---
name: incident
description: "Create and track an incident with notifications and task management"
user-invocable: true
---

# OTTO Incident Management

Create an incident, gather information, set up tracking, and notify the team.

## Arguments

- `[title]` - Short description of the incident. If omitted, prompt the user.

## Steps

### 1. Gather Information
Ask for or infer:
- **Title**: Short incident description
- **Severity**: critical / high / medium / low
- **Affected services**: Which systems are impacted
- **Symptoms**: What is happening (error messages, metrics, user reports)
- **Timeline**: When it started, what changed recently

### 2. Create Incident Task
- Run `./otto task "INCIDENT: <title>"` to create a tracked task
- Set the task priority based on severity
- Record the incident start time

### 3. Log the Incident
- Write an audit log entry: `audit_log "<user>" "incident_create" "<title>" "<details>" "active"`
- Save incident details to `~/.config/otto/state/incidents/`

### 4. Notify Team
- If communication channels are configured, send notifications
- Include severity, affected services, and current status
- For critical incidents, mention on-call if configured

### 5. Start Investigation
- Run relevant health checks for affected services
- Gather recent logs and metrics
- Check recent deployments or changes
- Present findings to help with root cause analysis

### 6. Track Resolution
- Update incident status as investigation progresses
- Log actions taken
- When resolved, create a summary with:
  - Root cause
  - Resolution steps
  - Duration
  - Action items to prevent recurrence
