# Odysseus Local AI Stack

One-command KDE/CachyOS integration for Ollama + Odysseus + Docker + a Plasma tray controller. This stack supports the Qwen3-Coder 30B agent for validating FastAPI application structure and multi-functional AI workspace architecture.

## Setup

Assumes your existing Odysseus checkout is `~/Downloads/odysseus`.

```bash
./install.sh
```

Or:

```bash
ODYSSEUS_DIR="$HOME/path/to/odysseus" ./install.sh
```

The installer:

- configures Ollama to listen on `0.0.0.0:11434`
- enables Ollama at boot
- installs a Docker Compose `host.docker.internal:host-gateway` override
- installs `odysseus-launcher`
- installs `odysseus-tray`
- installs the tray icon
- installs KDE autostart
- starts Ollama before Odysseus
- leaves Ollama model data untouched

## Critical architecture fix

Your 503 was caused by this path:

`Odysseus container -> host.docker.internal:11434`

while Ollama was bound only to `127.0.0.1` or was stopped.

This stack fixes both sides:

1. Ollama systemd service listens on `0.0.0.0:11434`.
2. Docker Compose explicitly maps `host.docker.internal` to the host gateway.
3. The launcher starts and verifies Ollama before starting Odysseus.
4. The tray starts the launcher instead of trying to manage Ollama incorrectly.

Do not run `ollama serve` manually while the system service is active; that causes `address already in use`.

## Models

Your existing models are expected to remain available to the Ollama service. Verify with:

```bash
ollama list
```

Recommended for your RX 7800 XT:

- `qwen3:14b` general/agent work
- `qwen2.5-coder:14b` coding
- `qwen3:8b` faster responses

## OpEncode

This repository ships the working opencode agent stack (agents, commands, skills, plugin deps and the exact ollama model tags they reference) under `opencode/`, so it can be replicated on any PC.

### Prerequisites

- Linux with `curl` (and `npm`/`node` as fallback for the installer and for the Playwright MCP server)
- Ollama running locally on `127.0.0.1:11434` (this stack's installer starts it if possible)
- Enough VRAM/RAM for the models: `gpt-oss:20b` (~13 GB) and `qwen3:14b` (~9 GB)

### Install

```bash
./scripts/install-opencode.sh
```

The installer:

- installs opencode via the official installer (npm fallback)
- backs up any existing config at the target path with a timestamp before copying — never overwrites silently
- copies `opencode/` from this repo to the opencode config directory
- runs `npm install` in the config directory for the `@opencode-ai/plugin` dependency
- ensures the ollama models exist: pulls `gpt-oss:20b` and `qwen3:14b`, and creates the `gpt-oss:20b-opencode` tag from `opencode/Modelfile.gpt-oss-20b-opencode` (tuned template, `num_ctx 40960`)
- verifies the install and prints a summary

Idempotent: safe to re-run; each run creates a fresh timestamped backup of the previous config.

### Where configs get installed

- Config dir: `~/.config/opencode/` (or `$XDG_CONFIG_HOME/opencode`)
- Main config: `~/.config/opencode/opencode.json` — defines the agents `build` (primary), `fast-worker`, `research-gate`, `qwen3-auditor`, `security-review`, `qwen3-single-shot`, the ollama provider, compaction and the Playwright MCP server
- Commands: `~/.config/opencode/commands/` — `research`, `security-review`
- Skills: `~/.config/opencode/skills/` — `browser-debug`, `repo-inventory`, `security-audit`
- Models: `gpt-oss:20b-opencode` and `qwen3:14b` served by the local ollama

### Verify the agent loads correctly

```bash
opencode --version
opencode agent list          # should list build, fast-worker, qwen3-auditor, research-gate, security-review, qwen3-single-shot
ollama list                  # should show gpt-oss:20b-opencode and qwen3:14b
```

Then start the TUI and switch agents with `opencode` (default agent: `build`).

## Verify everything

```bash
./scripts/verify.sh
```

## GitHub

This repository is already initialized with Git and has an initial commit. Add your remote:

```bash
git remote add origin git@github.com:YOUR_USERNAME/odysseus-local-stack.git
git push -u origin main
```
