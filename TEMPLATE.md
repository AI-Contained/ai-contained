# ai-contained-template

An example [AI-Contained](https://github.com/AI-Contained) MCP server demonstrating the plugin architecture with the `ai-contained-provider-template` adventure game plugin.

## Plugins

- **[ai-contained-provider-template](https://github.com/AI-Contained/ai-contained-provider-template)** - A choose-your-own-adventure game using MCP elicitation

---

## Using with AI-Contained (End Users)

The easiest way to run this MCP server alongside an AI agent.

### Prerequisites

- Docker with Compose

The agent image (`ghcr.io/ai-contained/ai-contained-agent-claude:latest`) is pulled automatically — no separate checkout or manual bootstrap is needed. On first run, the agent's built-in `shim_claude` entrypoint populates `~/.config/ai-contained/agent-claude` from its bundled template.

### Setup

Add `ai-contained-template/bin` to your PATH:

```bash
export PATH="$PATH:/path/to/ai-contained-template/bin"
```

### Running

From any directory you want the agent to work in:

```bash
ai-contained.sh .
```

Resume a previous session:

```bash
ai-contained.sh . --resume <session-id>
```

This starts `ai-contained-template` and the AI agent in an isolated Docker network, with your current directory mounted as `/workspace` inside the MCP server.

---

## Developing Your Own MCP (Developers)

Use this repo as a template for building your own MCP server with custom plugins.

### Local Development Setup

```bash
pip install -r requirements-dev.txt -e . --no-deps
```

> Assumes the following layout:
> ```
> ../core-mcp/
> ../ai-contained-provider-template/
> ../ai-contained-template/   ← you are here
> ```

### Running the Server Directly

```bash
python3 server.py
```

Or via FastMCP CLI:

```bash
fastmcp run server.py --transport http --host 0.0.0.0 --port 8080 --no-banner
```

### Customizing

- Add/remove plugins in `pyproject.toml`
- Update MCP server URL in `docker-compose.yaml` if you rename the service
