# DevOps Project Management Best Practices

## Ticket-Driven Workflow
- Every change should have a corresponding ticket (issue, story, task)
- Use ticket IDs in branch names: `feature/PROJ-123-add-monitoring`
- Include ticket ID in commit messages for traceability
- Auto-transition tickets based on PR status (opened, merged, deployed)
- Use labels/tags consistently: `bug`, `feature`, `tech-debt`, `incident`, `security`
- Keep tickets small and focused - one deliverable per ticket

## Linking Commits to Tickets
- Use conventional commit format: `feat(PROJ-123): add health check endpoint`
- Configure CI to reject commits without ticket references
- Use GitHub/GitLab integrations to auto-link commits to issues
- Smart commits in Jira: `PROJ-123 #done` to auto-transition
- Link PRs to issues using keywords: `Closes #123`, `Fixes PROJ-456`
- Generate changelogs automatically from commit messages

## Sprint Planning for Infrastructure Work
- Allocate 20-30% of sprint capacity for unplanned operational work
- Size infrastructure tasks by risk and blast radius, not just effort
- Include rollback planning in estimates for infrastructure changes
- Break large migrations into incremental, independently deployable chunks
- Use spikes (time-boxed research) for unfamiliar infrastructure areas
- Track toil separately: repetitive manual tasks are candidates for automation
- Balance feature work with tech debt reduction each sprint

## Incident-to-Ticket Automation
- Auto-create tickets from incident management tools (PagerDuty, Opsgenie)
- Include incident timeline, affected services, and severity in the ticket
- Link follow-up action items as sub-tasks of the incident ticket
- Track MTTR (Mean Time to Resolve) via ticket lifecycle timestamps
- Auto-assign to the on-call team or last deployer
- Create postmortem tickets automatically after incident resolution
- Tag incident tickets for trend analysis (recurring issues, affected services)

## SLA Tracking
- Define SLAs per service tier: P1 (1h response, 4h resolution), P2, P3, P4
- Track SLA compliance in your project management tool
- Set up automated alerts when SLA breach is approaching
- Report SLA metrics in weekly/monthly dashboards
- Distinguish between response time SLA and resolution time SLA
- Use error budgets (SRE model) to balance reliability with feature velocity
- Automate SLA reporting from incident management data

## Retrospective Templates
- Use the Start/Stop/Continue format for sprint retros
- Track action items from retros as tickets with owners and due dates
- Review previous retro action items at the start of each retro
- Include metrics: deployment frequency, lead time, MTTR, change failure rate
- Rotate facilitator role to encourage diverse perspectives
- Time-box each section to keep retros focused and productive
- Store retro notes in a searchable knowledge base (Confluence, Notion)

## Documentation-as-Code
- Store documentation alongside code in version control
- Use Markdown for all technical documentation
- Auto-generate API docs, architecture diagrams, and runbooks from code
- Review documentation changes in PRs alongside code changes
- Use static site generators (MkDocs, Docusaurus) for documentation sites
- Include README.md in every repository with setup instructions
- Keep runbooks in the same repo as the service they document

## Knowledge Sharing Patterns
- Write ADRs (Architecture Decision Records) for significant decisions
- Maintain a team wiki with onboarding guides and common procedures
- Record short video walkthroughs for complex systems
- Pair on operational tasks to spread knowledge
- Rotate on-call responsibilities to broaden team expertise
- Host regular "show and tell" sessions for new tools and techniques
- Create internal blog posts for major infrastructure changes
