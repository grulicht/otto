---
name: my-custom-agent
description: Brief description of what this agent does
type: custom
domain: general
model: sonnet  # haiku | sonnet | opus
triggers:
  - keyword or phrase that should activate this agent
  - another trigger phrase
tools:
  - list of CLI tools this agent uses
  - e.g., kubectl, terraform, docker
requires:
  - tools that must be installed for this agent to work
---

# My Custom Agent

## Role

Describe the agent's role and responsibilities in 1-2 sentences.

## Capabilities

What this agent can do:
- Capability 1
- Capability 2
- Capability 3

## Instructions

Detailed instructions for the agent's behavior.

### When activated

1. First, do this...
2. Then check this...
3. Finally, report this...

### Constraints

- Never do X without confirmation
- Always check Y before Z
- Respect permission levels from user configuration

### Output Format

Describe how the agent should format its responses.
