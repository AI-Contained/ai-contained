# AI-Contained

Run Claude as a coding assistant with real guardrails — isolated in Docker, with explicit control over what it can see and do.

---

## ⚠️ Current State: Minimum Viable Product

**Please read this before using AI-Contained.**

AI-Contained is now an MVP — usable for everyday work, but **expect bugs** _potentially code-corrupting_. **We're collecting your feedback and experiences** from early users and iterating quickly; if you hit something rough or have suggestions, please open an issue or share what you've learned.

The Docker architecture underpinning this project is rock solid. However, the MCP tools — the code that handles reading files, writing files, and executing shell commands — are a **reference implementation**: heavily AI-generated, with an AI-generated test suite. In other words, treat them as a starting point, not production-hardened software. These tools will be rewritten collaboratively by humans and AI over time. In the meantime, the code is provided as-is. Use it, learn from it, but do so with your eyes open.

**Approval granularity is per-request.** Every individual tool request currently requires explicit approval or rejection — at the moment, there is no way yet to grant standing permission for, say, "all reads under this directory" or "any `npm test`". Approval-list / ACL support is on the roadmap ([issue #7](https://github.com/AI-Contained/ai-contained/issues/7)). For now, expect to click a lot.

Additionally, there is **no authentication and no SSL** between the AI agent and the tool server. The containers communicate over a plain HTTP connection on the isolated Docker network. This is fine when everything runs on a single local machine, but **do not expose these services on an untrusted or shared network**. AI-Contained is intended to be run locally, or on a network you control and trust.

**You've been warned. Proceed accordingly.**

---

## Quick Start

```bash
git clone https://github.com/AI-Contained/ai-contained.git
export PATH="$PATH:$(pwd)/ai-contained/bin"   # add to ~/.bashrc or ~/.zshrc to persist
ai-contained.sh ~/projects/my-app
```

By default, the [claude-agent](https://github.com/AI-Contained/ai-contained-agent-claude) image is pulled automatically; on first launch Claude will walk you through login. When you're finished with your Claude session simply run `/exit`.  Parallel `ai-contained.sh` sessions are supported for driving different/multiple projects simultaneously.

---

## The Problem

AI coding assistants are powerful, but most of them run with broad access to your machine: your files, your shell, your credentials.  Best Security Practices say you should "lock your computer when it's not in use", yet AI Agents are given unchecked free rein access to our systems to do _whatever they like_.  Yes, you can construct a prompt that says "Ask me for permission before you modify any file".  This works _sometimes_, but _inevitably_ AI will "make a mistake" or "misread the room" and **will ignore** your attempts at adding guardrails.  **We need guardrails that are 100% reliable.**

AI is clever:  If you tell AI "Don't read file X" and even if AI has a _read tool_ that prompts you saying "Can I read X?" and you deny it, AI can (and will) find other ways.  This is especially trivial if you've given it _any_ "trusted" shell access, as AI can simply run `cat X`, `tail X`, `printf -v var '%s' "$(< X)"`, etc.  **We need a way to limit what kind of access AI has in an enforceable manner**.

**We (the users) NEED rigid guardrails to keep AI "in check"** and it's _this_ detail that AI Agents seem to neglect.  You shouldn't have to put your faith in your AI Agent's vendor to handle "trusting tools" with the level of control you'd like.

**AI-Contained** is an _attempt_ to introduce _rigid_ guardrails to empower you to use your favorite AI Agent to its maximum abilities, _without_ compromising your PC and your sensitive information.

This is _not_ a "one-size-fits-all" solution.  Your security requirements are different from mine.  However, **AI-Contained** tries to offer you the pieces to easily construct a security model that fits your needs, while allowing you to fully leverage your AI Agent.

---

## The Solution: Two Independent Layers of Protection

### Layer 1 — You approve every action

The AI Agent cannot read a file, write code, or run a shell command without explicitly asking you first. Every request shows you exactly what it wants to do and why. You say yes or no.

This is your primary line of defense for normal operation.

### Layer 2 — Docker enforces the limits, regardless

Here's the part that makes AI-Contained different from other tools that also ask for approval:

Each tool (read/write a file, execute a command, etc) the AI can use runs in its **own Docker container**, with permissions set at the infrastructure level — not in software. This means that even if you accidentally approve something you shouldn't have (prompt fatigue), even if a tool is misconfigured, even if the AI finds a creative way to phrase a request — the container simply **cannot** exceed what it was given at launch.

A concrete example: the [shell provider](https://github.com/AI-Contained/ai-contained-provider-shell) is given a **read-only** mount of your workspace. So even if the AI convinces a tired you to approve `rm -rf /`, the container physically cannot write to anything. There is no code path that overrides this — it's enforced by docker/podman.

Meanwhile, all legitimate file writes go through the [filesystem provider](https://github.com/AI-Contained/ai-contained-provider-filesystem), which runs in a separate container with read-write access and its own approval flow. This means every write operation is funneled through a tool that was specifically designed with guardrails for that purpose.

The result: **you get the convenience of a capable AI assistant, with the blast radius of a carefully sandboxed process.**

---

## Why Open Source Matters Here

Every tool the AI can use is open-source Python. Before you grant the AI access to your codebase, you can read exactly what each tool does — not a summary, the actual code.

This is a deliberate design choice. Trust shouldn't be blind. If you're handing an AI access to sensitive code or infrastructure, you should be able to verify what it can actually do with that access and adjust it to _your_ needs.

---

## What's Included

AI-Contained ships with two tools, pre-configured with appropriate isolation:

| Provider | What it does | Docker permissions |
|------|-------------|-------------------|
| [filesystem](https://github.com/AI-Contained/ai-contained-provider-filesystem) | Read files, write files, glob/search directories | Read + write to your workspace |
| [shell](https://github.com/AI-Contained/ai-contained-provider-shell) | Run bash commands | Read-only access to your workspace |

The separation is intentional. The shell provider can inspect, search, and run commands against your code — but it cannot modify anything. If the AI wants to write a file, it **must** use the filesystem provider, which has its own approval step and its own container.

This architecture means that even a compromised or poorly configured shell tool has a hard ceiling on the damage it can cause.

---

## How It Works Under the Hood

When you run `ai-contained.sh`, Docker Compose starts several containers on a private, isolated network:

- **The AI agent** — a minimal Claude Code container with no built-in tools enabled. It has no direct access to your host machine. The only way it can interact with the outside world is by calling MCP tool servers over the isolated network.
- **The MCP providers** — one container per provider (filesystem, shell), each running its own MCP server with the permissions Docker grants it.

Your workspace directory is mounted into the provider containers that need it, with the permissions each one is allowed. The AI agent itself never touches your filesystem directly — every action goes through a provider, and every provider is bounded by what its container was given at launch.

```
Your machine
└── docker network (isolated)
    ├── agent (Claude Code — no host access)
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

**1. Clone this repo:**

```bash
git clone https://github.com/AI-Contained/ai-contained.git
```

The agent image is pulled automatically from `ghcr.io/ai-contained/ai-contained-agent-claude:latest`.  During the first run, it bootstraps its own config directory (`~/.config/ai-contained/agent-claude`) then proceeds to start claude-code.

**2. Add `ai-contained` to your PATH:**

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

The first run builds the tool-server image and pulls the agent image — this takes a minute or two. Every subsequent run starts in a few seconds.

**Resume a previous session:**

```bash
ai-contained.sh . --resume <session-id>
```

When you're done, simply quit claude. Docker Compose shuts everything down cleanly.

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
