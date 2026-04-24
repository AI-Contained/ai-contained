# AI-Contained

Run Claude as a coding assistant with real guardrails — isolated in Docker, with explicit control over what it can see and do.

---

## The Problem

AI coding assistants are powerful, but most of them run with broad access to your machine: your files, your shell, your credentials. You're trusting not just the AI's judgment, but the judgment of every tool it touches — and your own judgment, every single time it asks for permission.

That last part matters more than it sounds. After approving fifty reasonable requests in a row, it's easy to approve a fifty-first without reading it carefully. This is called **prompt fatigue**, and it's one of the most realistic ways an AI assistant causes unintended damage.

AI-Contained takes a different approach.

---

## The Solution: Two Independent Layers of Protection

### Layer 1 — You approve every action

The AI cannot read a file, write code, or run a shell command without explicitly asking you first. Every request shows you exactly what it wants to do and why. You say yes or no.

This is your primary line of defense for normal operation.

### Layer 2 — Docker enforces the limits, regardless

Here's the part that makes AI-Contained different from other tools that also ask for approval:

Each tool the AI can use runs in its **own Docker container**, with permissions set at the infrastructure level — not in software. This means that even if you accidentally approve something you shouldn't have (prompt fatigue), even if a tool is misconfigured, even if the AI finds a creative way to phrase a request — the container simply **cannot** exceed what it was given at launch.

A concrete example: the **shell tool** is given a **read-only** mount of your workspace. So even if the AI convinces a tired you to approve `rm -rf /`, the container physically cannot write to anything. There is no code path that overrides this — it's enforced by the kernel.

Meanwhile, all legitimate file writes go through the **filesystem tool**, which runs in a separate container with read-write access and its own approval flow. This means every write operation is funneled through a tool that was specifically designed with guardrails for that purpose.

The result: **you get the convenience of a capable AI assistant, with the blast radius of a carefully sandboxed process.**

---

## Why Open Source Matters Here

Every tool the AI can use is open-source Python. Before you grant the AI access to your codebase, you can read exactly what each tool does — not a summary, the actual code.

This is a deliberate design choice. Trust shouldn't be blind. If you're handing an AI access to sensitive code or infrastructure, you should be able to verify what it can actually do with that access.

---

## What's Included

AI-Contained ships with two tools, pre-configured with appropriate isolation:

| Tool | What it does | Docker permissions |
|------|-------------|-------------------|
| **Filesystem** | Read files, write files, glob/search directories | Read + write to your workspace |
| **Shell** | Run bash commands | Read-only access to your workspace |

The separation is intentional. The shell tool can inspect, search, and run commands against your code — but it cannot modify anything. If the AI wants to write a file, it must use the filesystem tool, which has its own approval step and its own container.

This architecture means that even a compromised or poorly configured shell tool has a hard ceiling on the damage it can cause.

---

## How It Works Under the Hood

When you run `ai-contained.sh`, Docker Compose starts several containers on a private, isolated network:

- **The AI agent** — a minimal Claude Code container with no built-in tools enabled. It has no direct access to your host machine. The only way it can interact with the outside world is by calling tools through the network.
- **The tool server** — a Python server that receives the AI's tool requests and executes them within their respective containers, subject to their configured permissions.

Your workspace directory is mounted into the containers that need it, with the permissions each one is allowed. The AI agent itself never touches your filesystem directly — it goes through the tool server, which goes through the appropriate container.

```
Your machine
└── docker network (isolated)
    ├── agent (Claude Code — no host access)
    ├── tool server (routes requests to tools)
    ├── filesystem container (read+write to /workspace)
    └── shell container (read-only to /workspace)
```

The AI agent is also stripped of all of Claude Code's built-in tools (file reading, web search, etc.). It can **only** act through the tools you've explicitly provided. There is no fallback, no bypass.

---

## Prerequisites

- **Docker** with the Compose plugin — verify with `docker compose version`
- **A Claude account** — either:
  - A [Claude Pro or Max subscription](https://claude.ai) — running Claude Code locally is safe and does not violate Anthropic's Terms of Service
  - Or an [Anthropic API key](https://console.anthropic.com)

---

## Setup (First Time Only)

**1. Clone this repo and the agent side by side:**

```bash
git clone https://github.com/AI-Contained/ai-contained.git
git clone https://github.com/AI-Contained/ai-contained-agent-claude.git
```

Both directories should be in the same parent folder.

**2. Bootstrap your Claude config:**

```bash
cp -r ai-contained-agent-claude/template-config ~/.config/ai-contained/ai-contained-agent-claude
```

This creates a config directory where Claude stores your login session and settings. You only do this once — after that, your session persists across runs.

**3. Add `ai-contained` to your PATH:**

```bash
export PATH="$PATH:/path/to/ai-contained/bin"
```

Add this line to your `~/.bashrc` or `~/.zshrc` to make it permanent.

---

## Running

From any directory you want the AI to work in:

```bash
ai-contained.sh .
```

Or point it at a specific path:

```bash
ai-contained.sh ~/projects/my-app
```

The first run builds the Docker images — this takes a minute or two. Every subsequent run starts in a few seconds.

**Resume a previous session:**

```bash
ai-contained.sh . --resume <session-id>
```

When you're done, press `Ctrl+C`. Docker Compose shuts everything down cleanly.

---

## First Launch

On first launch, Claude will walk you through login. Sign in with your Claude.ai account (Pro or Max) or enter your API key when prompted. Your credentials are stored in `~/.config/ai-contained/ai-contained-agent-claude/` and reused automatically in future sessions.

---

## What the AI Can and Can't Do

**The AI can:**
- Read any file inside the directory you shared
- Write and edit files inside that directory — with your approval, through the filesystem tool
- Run bash commands against your code — with your approval, in a read-only shell
- Ask you questions, explain its reasoning, make suggestions

**The AI cannot:**
- Access anything outside the directory you shared
- Read your environment variables, SSH keys, or credentials
- Make outbound network requests on its own
- Install software or modify system configuration
- Do anything — at all — without explicitly asking you first

---

## Want to Customize or Build Your Own?

AI-Contained is built on a modular provider architecture. If you're a developer who wants to add new tools, adjust permissions, build your own tool server, or understand how the pieces fit together, see the [AI-Contained GitHub organization](https://github.com/AI-Contained) for the template repos and developer documentation.
