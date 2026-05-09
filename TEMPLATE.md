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

### Adding or Removing Plugins

Edit the `Dockerfile` to add or remove provider images:

```dockerfile
FROM ghcr.io/ai-contained/ai-contained-base:latest

COPY --link --from=ghcr.io/ai-contained/ai-contained-provider-template:latest / /
# COPY --link --from=ghcr.io/ai-contained/ai-contained-provider-shell:latest / /

RUN ["/usr/local/bin/ai-contained-finalize"]

USER 65533:65533
```

### Building Locally

```bash
docker build -t my-ai-contained .
```

### Customizing

- Add/remove providers via `COPY --link --from=...` lines in `Dockerfile`
- Update the MCP server URL in `docker-compose.yaml` if you rename the service
