---
name: morning
description: Generate morning briefing from Night Watcher data and current system state
user-invocable: true
---

# OTTO Morning Briefing

Generate a comprehensive morning briefing by aggregating overnight data and current system state.

## Steps

1. Run `./otto morning` to get the generated morning report
2. If Night Watcher was active, check `~/.config/otto/state/night-watch/` for overnight reports
3. Run key fetch scripts to get current state:
   - Check monitoring alerts
   - Check CI/CD pipeline status
   - Check infrastructure health
4. Aggregate all results into a briefing

## Briefing Structure

Present the briefing in this order:

1. **Overnight Summary** - What happened while you were away
   - Critical alerts that fired
   - Deployments that ran
   - Any incidents or anomalies
2. **Current State** - How things look right now
   - Service health status
   - Active alerts
   - Pipeline status
3. **Action Items** - What needs attention today
   - Unresolved alerts
   - Failed deployments
   - Expiring certificates or resources
4. **Trends** - Notable patterns
   - Resource usage trends
   - Error rate changes

Keep the briefing concise but comprehensive. Prioritize actionable items.
