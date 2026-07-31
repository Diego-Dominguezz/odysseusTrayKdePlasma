#!/usr/bin/env bash
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ODYSSEUS_DIR="${ODYSSEUS_DIR:-$HOME/Downloads/odysseus}"

log(){ printf '\n[odysseus-stack] %s\n' "$*"; }
die(){ printf '\n[odysseus-stack] ERROR: %s\n' "$*" >&2; exit 1; }

[[ -d "$ODYSSEUS_DIR" ]] || die "Odysseus directory not found: $ODYSSEUS_DIR"
[[ -f "$ODYSSEUS_DIR/docker-compose.yml" ]] || die "docker-compose.yml not found in $ODYSSEUS_DIR"
command -v docker >/dev/null || die "Docker is not installed"
command -v ollama >/dev/null || die "Ollama is not installed"
command -v python3 >/dev/null || die "Python 3 is not installed"

log "Configuring Docker group"
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  sudo usermod -aG docker "$USER"
  log "Docker group added. Log out and back in once if this is the first time."
fi

log "Configuring Ollama for container access"
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<'EOT'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOT
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl restart ollama

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
