#!/usr/bin/env bash
# install-opencode.sh — Install opencode and replicate the working agent stack
# from this repository onto any PC.
#
# What it does:
#   1. Installs opencode (official install script; npm fallback) if missing.
#   2. Backs up any existing config at the target path (timestamped) before copying.
#   3. Copies the repo's opencode/ config (agents, commands, skills, plugin deps)
#      to the target config path.
#   4. Installs the opencode plugin dependency (npm install in the config dir).
#   5. Ensures the ollama models the agents depend on exist:
#        - gpt-oss:20b            (base model for the primary orchestrator tag)
#        - gpt-oss:20b-opencode   (custom tag built from opencode/Modelfile.gpt-oss-20b-opencode)
#        - qwen3:14b              (single-shot assistant)
#   6. Verifies the install and prints a summary.
#
# Idempotent: safe to re-run. Re-runs create a fresh timestamped backup of the
# previous config instead of overwriting silently.
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="$REPO_DIR/opencode"
CONFIG_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OLLAMA_URL="http://127.0.0.1:11434"

log()  { printf '\033[1;34m[opencode]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[opencode] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Install opencode (official method, npm fallback)
# ---------------------------------------------------------------------------
if command -v opencode >/dev/null 2>&1; then
  log "opencode already installed: $(opencode --version)"
else
  log "Installing opencode via official installer..."
  if curl -fsSL https://opencode.ai/install | bash; then
    log "opencode installed via official installer."
  else
    log "Official installer failed; falling back to npm..."
    npm install -g opencode-ai || die "opencode install failed. Install it manually (https://opencode.ai/docs) and re-run."
  fi
  command -v opencode >/dev/null 2>&1 || die "opencode not found on PATH after install. Re-run or add it to PATH."
fi

# ---------------------------------------------------------------------------
# 2. Back up existing config (timestamped) — never overwrite silently
# ---------------------------------------------------------------------------
if [ -d "$CONFIG_DEST" ] && [ -n "$(ls -A "$CONFIG_DEST" 2>/dev/null)" ]; then
  BACKUP_DIR="${CONFIG_DEST}.backup-$(date +%Y%m%d-%H%M%S)"
  log "Backing up existing config to $BACKUP_DIR"
  cp -a "$CONFIG_DEST" "$BACKUP_DIR"
fi

# ---------------------------------------------------------------------------
# 3. Copy repo config into place
# ---------------------------------------------------------------------------
[ -d "$CONFIG_SRC" ] || die "Config source not found: $CONFIG_SRC (run from a checkout of this repo)"
mkdir -p "$CONFIG_DEST"
log "Copying config from $CONFIG_SRC -> $CONFIG_DEST"
cp -a "$CONFIG_SRC/." "$CONFIG_DEST/"

# ---------------------------------------------------------------------------
# 4. Install plugin dependency (@opencode-ai/plugin) from package.json
# ---------------------------------------------------------------------------
if [ -f "$CONFIG_DEST/package.json" ]; then
  log "Installing opencode plugin dependencies (npm install)..."
  npm install --prefix "$CONFIG_DEST" --no-audit --no-fund
fi

# ---------------------------------------------------------------------------
# 5. Ensure ollama models exist (agents reference these exact tags)
# ---------------------------------------------------------------------------
if ! curl -fsS --max-time 3 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
  log "Ollama is not responding on $OLLAMA_URL. Starting it..."
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files ollama.service >/dev/null 2>&1; then
    sudo systemctl start ollama || true
  fi
  for _ in $(seq 1 30); do
    curl -fsS --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 && break
    sleep 2
  done
fi
curl -fsS --max-time 3 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 \
  || die "Ollama is not reachable at $OLLAMA_URL. Start it and re-run."

log "Ensuring model: gpt-oss:20b (base for the primary orchestrator tag)..."
ollama pull gpt-oss:20b

log "Ensuring model: gpt-oss:20b-opencode (custom tag from repo Modelfile)..."
ollama create gpt-oss:20b-opencode -f "$CONFIG_SRC/Modelfile.gpt-oss-20b-opencode"

log "Ensuring model: qwen3:14b (single-shot assistant)..."
ollama pull qwen3:14b

# ---------------------------------------------------------------------------
# 6. Verify
# ---------------------------------------------------------------------------
log "Verifying installation..."
opencode --version >/dev/null 2>&1 || die "opencode binary does not run"
[ -f "$CONFIG_DEST/opencode.json" ] || die "opencode.json missing after install"

AGENTS="$(opencode agent list 2>/dev/null || true)"
for agent in build fast-worker qwen3-auditor research-gate security-review qwen3-single-shot; do
  if ! printf '%s' "$AGENTS" | grep -q "$agent"; then
    log "WARNING: agent '$agent' not listed by 'opencode agent list' (config may still load it)"
  fi
done

log "Done."
printf '\nOpEncode stack installed:\n'
printf '  opencode:      %s\n' "$(opencode --version)"
printf '  config:        %s\n' "$CONFIG_DEST"
printf '  models:        gpt-oss:20b-opencode, qwen3:14b (via ollama on %s)\n' "$OLLAMA_URL"
printf '  run:           opencode\n'
printf '  agents:        build (primary), fast-worker, research-gate, qwen3-auditor, security-review, qwen3-single-shot\n'