---
name: status
description: Run system health overview showing service status, recent alerts, and infrastructure state
user-invocable: true
---

# OTTO Status - System Health Overview

Run `./otto status` from the OTTO project root directory and present the results to the user.

## Steps

1. Execute `./otto status` in the OTTO project directory
2. If the command fails, try running the individual health check scripts:
   - `./otto heartbeat status` for heartbeat state
   - `./otto detect` for detected tools
3. Parse the output and present a clear summary including:
   - Overall system health (healthy/degraded/critical)
   - Active heartbeat mode and interval
   - Recent alerts or issues
   - Detected tools and integrations
   - Night Watcher status (active/inactive)
4. If any checks show problems, highlight them and suggest next steps

## Output Format

Present results in a structured format:
- Use clear section headers
- Color-code status where possible (pass/warn/fail)
- Include timestamps for last check times
- Suggest `otto check <name>` for any failing checks
