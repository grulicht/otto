# MCP Server Guide

OTTO can run as a Model Context Protocol (MCP) server, exposing its DevOps tools to Claude Code, Claude Desktop, and other MCP-compatible AI assistants.

> **Maturity: Experimental** - The MCP server works but may see changes as the MCP protocol evolves.

## What is MCP?

The Model Context Protocol is a standard for AI assistants to discover and invoke tools provided by external servers. OTTO's MCP server lets any MCP client run health checks, deploy applications, create incidents, and more through a JSON-RPC interface over stdin/stdout.

## Starting the MCP Server

```bash
# Run directly
bash /path/to/otto/mcp/otto-server.sh

# Or via the OTTO directory
cd /path/to/otto
bash mcp/otto-server.sh
```

The server reads JSON-RPC requests from stdin and writes responses to stdout. Diagnostic logs go to stderr.

## Available MCP Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `otto_check` | Run a health check on a target | `target` (string, optional) |
| `otto_status` | Get system status overview | None |
| `otto_deploy` | Deploy an application | `target` (string), `environment` (string), `version` (string) |
| `otto_rollback` | Rollback a deployment | `target` (string), `environment` (string) |
| `otto_incident` | Create an incident | `title` (string), `severity` (string) |
| `otto_knowledge` | Search the knowledge base | `query` (string) |
| `otto_compliance` | Run a compliance audit | None |
| `otto_morning` | Generate morning briefing | None |

## Configuring in Claude Code

Add OTTO as an MCP server in your Claude Code configuration (`.claude/settings.json` or project settings):

```json
{
  "mcpServers": {
    "otto": {
      "command": "bash",
      "args": ["/path/to/otto/mcp/otto-server.sh"],
      "env": {
        "OTTO_DIR": "/path/to/otto"
      }
    }
  }
}
```

After configuration, Claude Code will discover OTTO's tools automatically and can use them during conversations.

## Configuring in Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or the equivalent on your platform:

```json
{
  "mcpServers": {
    "otto": {
      "command": "bash",
      "args": ["/absolute/path/to/otto/mcp/otto-server.sh"]
    }
  }
}
```

Restart Claude Desktop after adding the configuration.

## JSON-RPC Protocol Details

OTTO's MCP server implements the MCP protocol version `2024-11-05` over stdin/stdout using JSON-RPC 2.0.

### Supported Methods

| Method | Description |
|--------|-------------|
| `initialize` | Handshake, returns server capabilities |
| `initialized` | Client notification (no response) |
| `tools/list` | List available tools with schemas |
| `tools/call` | Execute a tool |
| `notifications/*` | Client notifications (no response) |

### Example: Initialize

Request:
```json
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "clientInfo": {"name": "my-client"}}}
```

Response:
```json
{"jsonrpc": "2.0", "id": 1, "result": {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "otto-devops", "version": "1.0.0"}}}
```

### Example: List Tools

Request:
```json
{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
```

Response:
```json
{"jsonrpc": "2.0", "id": 2, "result": {"tools": [{"name": "otto_check", "description": "Run a health check", "inputSchema": {"type": "object", "properties": {"target": {"type": "string"}}}}, ...]}}
```

### Example: Call a Tool

Request:
```json
{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "otto_check", "arguments": {"target": "kubernetes"}}}
```

Response:
```json
{"jsonrpc": "2.0", "id": 3, "result": {"content": [{"type": "text", "text": "{\"status\": \"success\", \"output\": \"...\"}"}]}}
```

### Example: Deploy

Request:
```json
{"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "otto_deploy", "arguments": {"target": "myapp", "environment": "staging", "version": "1.2.3"}}}
```

### Error Responses

Unknown tools return a JSON-RPC error:
```json
{"jsonrpc": "2.0", "id": 5, "error": {"code": -32601, "message": "Unknown tool: invalid_tool"}}
```

## Tool Configuration

Tool definitions are stored in `mcp/mcp-config.json`. You can edit this file to change descriptions or add custom tool metadata. The server reads this file to respond to `tools/list` requests.

## Limitations and Known Issues

- **No authentication.** The MCP server trusts all incoming requests. Run it only in trusted environments.
- **No HTTPS/TCP.** Communication is stdin/stdout only. Use it as a subprocess of an MCP client, not as a network service.
- **Sequential processing.** Requests are processed one at a time in the main loop.
- **OTTO CLI dependency.** Each tool call invokes the `otto` CLI. The OTTO environment (config, secrets, tools) must be properly set up.
- **No streaming.** Long-running operations (like deployments) block until complete. The client receives the full result at once.
- **Parameter types.** All parameters are passed as strings. Complex types are not supported.
