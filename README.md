# Odysseus Local AI Stack

One-command KDE/CachyOS integration for Ollama + Odysseus + Docker + a Plasma tray controller.

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
