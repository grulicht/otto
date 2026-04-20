---
name: knowledge
description: "Search the OTTO knowledge base for best practices, troubleshooting guides, and runbooks"
user-invocable: true
---

# OTTO Knowledge Base Search

Search OTTO's built-in and custom knowledge base for relevant DevOps information.

## Arguments

- `[topic]` - The topic to search for (e.g., kubernetes, terraform, ssl, backup, docker)

## Steps

1. If a topic is provided, search using `knowledge_search "<topic>"` by running:
   ```bash
   ./scripts/core/knowledge-engine.sh search "<topic>"
   ```
2. If no topic is provided, list all available topics:
   ```bash
   ./scripts/core/knowledge-engine.sh list
   ```
3. Present the results organized by category:
   - **Best Practices** - Recommended approaches and configurations
   - **Troubleshooting** - Common issues and solutions
   - **Runbooks** - Step-by-step operational procedures
   - **Patterns** - Architecture and deployment patterns

## Knowledge Locations

- Built-in: `knowledge/` directory in the OTTO project
- Custom: `~/.config/otto/knowledge/` for user-added content
- Team: `~/.config/otto/team/knowledge/` for shared team knowledge

## Adding Knowledge

To add custom knowledge:
```bash
./scripts/core/knowledge-engine.sh add <type> <filename> <content>
```
Where type is: best-practices, troubleshooting, runbooks, or patterns.
