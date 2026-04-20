# Project Management Integrations

OTTO integrates with project management tools to track sprints, monitor issues, and include task context in reports and troubleshooting.

## Jira

### Setup

1. Generate an API token at https://id.atlassian.com/manage-profile/security/api-tokens
2. Add credentials to `~/.config/otto/.env`:

```bash
OTTO_JIRA_URL=https://yourcompany.atlassian.net
OTTO_JIRA_EMAIL=your-email@company.com
OTTO_JIRA_TOKEN=your-api-token
```

### What OTTO Fetches

The Jira fetch script (`scripts/fetch/jira.sh`) collects:

- **Your assigned issues** - Open issues assigned to you, sorted by last updated (up to 50)
- **Open issues** - All unresolved issues in the project
- **Active sprint** - Current sprint details if using Scrum boards

### JQL Customization

The default JQL queries are:
- My issues: `assignee=currentUser() AND resolution=Unresolved ORDER BY updated DESC`
- Open issues: `resolution=Unresolved ORDER BY updated DESC`

To customize, edit `scripts/fetch/jira.sh` or create a plugin with your own Jira fetch script.

### How OTTO Uses Jira Data

- Morning briefings include your assigned issues and sprint progress
- Incident creation can link to Jira tickets
- Troubleshooting context includes related Jira issues
- Trend analysis considers issue velocity

## Confluence

### Setup

Confluence uses the same Atlassian credentials as Jira. If your Confluence is on a different URL:

```bash
OTTO_CONFLUENCE_URL=https://yourcompany.atlassian.net
# Falls back to OTTO_JIRA_URL if not set
```

You also need `OTTO_JIRA_EMAIL` and `OTTO_JIRA_TOKEN` set (same credentials work for both).

### What OTTO Fetches

The Confluence fetch script (`scripts/fetch/confluence.sh`) collects:

- **Recently modified pages** - Last 25 modified pages with title, space, author, and modification date
- **Spaces** - Available Confluence spaces

### How OTTO Uses Confluence Data

- Knowledge engine searches include relevant Confluence pages
- Morning briefings mention recently updated documentation
- Runbook references can link to Confluence pages

## Linear

### Setup

1. Create a personal API key at https://linear.app/settings/api
2. Add to `~/.config/otto/.env`:

```bash
OTTO_LINEAR_TOKEN=lin_api_xxxxxxxxxxxx
```

### What OTTO Fetches

The Linear fetch script (`scripts/fetch/linear.sh`) uses the GraphQL API to collect:

- **Your assigned issues** - Open issues assigned to you (up to 50), excluding completed and cancelled
- **Active cycle** - Current cycle/sprint details
- **Team issues** - Issues across your team

Each issue includes: identifier, title, state, priority, priority label, updated date, URL, and labels.

### How OTTO Uses Linear Data

- Morning briefings show your Linear issues and cycle progress
- Issue counts and priorities feed into workload analysis
- Labels are used for categorization in reports

## Trello

### Setup

1. Get your API key at https://trello.com/power-ups/admin
2. Generate a token by visiting: `https://trello.com/1/authorize?key=YOUR_KEY&name=OTTO&scope=read&response_type=token&expiration=never`
3. Add to `~/.config/otto/.env`:

```bash
OTTO_TRELLO_KEY=your-api-key
OTTO_TRELLO_TOKEN=your-token
OTTO_TRELLO_BOARD_ID=your-board-id
```

To find your board ID, open the board in Trello and add `.json` to the URL.

### Integration

Create a fetch script at `~/.config/otto/scripts/fetch/trello.sh` or install a Trello plugin. The Trello REST API endpoint is `https://api.trello.com/1/`.

## Asana

### Setup

1. Create a Personal Access Token at https://app.asana.com/0/developer-console
2. Add to `~/.config/otto/.env`:

```bash
OTTO_ASANA_TOKEN=your-personal-access-token
OTTO_ASANA_PROJECT_GID=your-project-gid
```

### Integration

Create a fetch script or install an Asana plugin. The Asana API base is `https://app.asana.com/api/1.0/`. Use Bearer token authentication.

## Notion

### Setup

1. Create an integration at https://www.notion.so/my-integrations
2. Share your database with the integration
3. Add to `~/.config/otto/.env`:

```bash
OTTO_NOTION_TOKEN=secret_xxxxxxxxxxxx
OTTO_NOTION_DATABASE_ID=your-database-id
```

### Integration

Create a fetch script or install a Notion plugin. The Notion API base is `https://api.notion.com/v1/`. Use Bearer token authentication with `Notion-Version: 2022-06-28` header.

## Redmine

### Setup

1. Enable REST API in Redmine administration
2. Get your API key from My Account page
3. Add to `~/.config/otto/.env`:

```bash
OTTO_REDMINE_URL=https://redmine.yourcompany.com
OTTO_REDMINE_TOKEN=your-api-key
```

### Integration

Create a fetch script or install a Redmine plugin. The API base is `${OTTO_REDMINE_URL}/`. Use `X-Redmine-API-Key` header for authentication. Endpoints: `/issues.json`, `/projects.json`, `/time_entries.json`.

## How OTTO Uses Project Management Data

Across all integrations, OTTO leverages project management data for:

- **Morning briefings** - Shows your assigned issues, sprint/cycle progress, and upcoming deadlines
- **Incident context** - Links incidents to related issues in your project tracker
- **Workload awareness** - Considers issue counts and priorities when suggesting task priorities
- **Trend analysis** - Tracks issue velocity, completion rates, and backlog growth over time
- **Knowledge search** - Includes issue titles and descriptions in knowledge engine searches

## Adding Custom Integrations

If your project management tool isn't supported built-in, create a plugin:

1. Create a fetch script that outputs JSON to stdout (see `docs/plugins.md`)
2. Include the data you want OTTO to use (issues, sprints, boards)
3. Install as a plugin with `otto plugin install`

The fetch script output should follow this general structure:

```json
{
  "my_issues": [
    {"id": "PROJ-123", "title": "Fix login bug", "status": "In Progress", "priority": "high"}
  ],
  "active_sprint": {
    "name": "Sprint 42",
    "start": "2026-04-14",
    "end": "2026-04-28"
  }
}
```
