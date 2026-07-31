#!/usr/bin/env bash
# Odysseus Local Stack — Installer
# Delegates to the KDE integration installer in odysseus-kde-integration/
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION_DIR="$REPO_DIR/odysseus-kde-integration"

if [ -f "$INTEGRATION_DIR/install.sh" ]; then
    exec "$INTEGRATION_DIR/install.sh"
else
    echo "ERROR: Integration installer not found at $INTEGRATION_DIR/install.sh" >&2
    exit 1
fi

log "Waiting for Ollama"
for i in {1..60}; do
  curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null && break
  sleep 1
done
curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null || die "Ollama API is unavailable"

log "Installing Docker host-gateway override"
cat > "$ODYSSEUS_DIR/docker-compose.override.yml" <<EOT
services:
  odysseus:
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOT

log "Installing launcher and tray"
install -Dm755 "$REPO_DIR/bin/odysseus-launcher" "$HOME/.local/bin/odysseus-launcher"
install -Dm755 "$REPO_DIR/bin/odysseus-tray" "$HOME/.local/bin/odysseus-tray"
install -Dm644 "$REPO_DIR/icons/odysseus.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/odysseus.svg"
install -Dm644 "$REPO_DIR/desktop/odysseus-tray.desktop" "$HOME/.config/autostart/odysseus-tray.desktop"

log "Starting Odysseus"
"$HOME/.local/bin/odysseus-launcher"

log "Done"
printf '\nOllama:   http://127.0.0.1:11434\nOdysseus: http://127.0.0.1:7000\nTray:     ~/.local/bin/odysseus-tray\n'
