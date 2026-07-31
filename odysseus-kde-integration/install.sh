#!/bin/bash
# Odysseus KDE Integration — Installer
#
# Installs the KDE Plasma integration layer for an existing Odysseus installation.
# This is idempotent — safe to run multiple times.
#
# Architecture:
#   - Ollama: system-level systemd service (existing) + resource safety overlay
#   - Odysseus: existing Docker Compose project (not modified)
#   - Tray: user-level systemd service (~/.config/systemd/user/)
#
# Resource Safety Layer (Phase 0.6):
#   - OLLAMA_GPU_OVERHEAD=2048 — Reserve 2 GiB VRAM for display compositor
#   - OLLAMA_KEEP_ALIVE=30m   — Reduce model reload frequency
#   - MemoryHigh=24G / MemoryMax=27G — Protect desktop from OOM
#   - OOMScoreAdjust=500 — Ollama sacrificed first under pressure
#   - Healthcheck monitors MemAvailable, VRAM, PSI, DCN32 timeouts
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
INFO="${CYAN}INFO${NC}"; OK="${GREEN}OK${NC}"; WARN="${YELLOW}WARN${NC}"; FAIL="${RED}FAIL${NC}"

ODYSSEUS_DIR="${ODYSSEUS_DIR:-$HOME/Downloads/odysseus}"
INTEGRATION_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="${OLLAMA_MODELS:-$HOME/.ollama/models}"

echo ""
echo "============================================"
echo "  Odysseus KDE Integration — Installer"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# Step 0: Pre-flight checks
# ---------------------------------------------------------------------------
echo " --- Pre-flight Checks ---"

# Check we're in the right directory
if [ ! -f "$INTEGRATION_DIR/bin/odysseus-tray" ]; then
    echo -e "  ${FAIL} Integration source not found at ${INTEGRATION_DIR}"
    exit 1
fi
echo -e "  ${OK} Integration source: ${INTEGRATION_DIR}"

# Check existing Odysseus
if [ -d "$ODYSSEUS_DIR" ]; then
    echo -e "  ${OK} Existing Odysseus: ${ODYSSEUS_DIR}"
else
    echo -e "  ${WARN} Odysseus directory not found at ${ODYSSEUS_DIR}"
    echo "    You can set ODYSSEUS_DIR to the correct path."
fi

# Check Docker
if docker info >/dev/null 2>&1; then
    echo -e "  ${OK} Docker daemon: running"
else
    echo -e "  ${FAIL} Docker daemon: not running or not accessible"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
    echo -e "  ${OK} Docker Compose: available"
else
    echo -e "  ${FAIL} Docker Compose: not found"
    exit 1
fi

# Check Docker group membership
if id -nG | grep -q docker; then
    echo -e "  ${OK} Docker group: member"
else
    echo -e "  ${WARN} User not in docker group. Adding..."
    sudo usermod -aG docker "$USER"
    echo "  ** You must log out and back in for Docker group to take effect. **"
    echo "  ** Until then, some features may require 'sudo docker'. **"
fi

# Detect Ollama
if systemctl is-active --quiet ollama 2>/dev/null; then
    echo -e "  ${OK} Ollama systemd service: active"
elif pgrep -x ollama >/dev/null 2>&1; then
    echo -e "  ${WARN} Ollama process running but systemd service is inactive"
    echo "    This indicates a dual-instance problem. Installer will fix it."
else
    echo -e "  ${WARN} Ollama: not running"
fi

# Check Python + PyQt6
if python3 -c "from PyQt6.QtWidgets import QApplication; import sys" 2>/dev/null; then
    echo -e "  ${OK} PyQt6: available"
else
    echo -e "  ${INFO} Installing PyQt6..."
    pip3 install --user PyQt6 2>/dev/null || {
        echo -e "  ${FAIL} Could not install PyQt6. Try: pip install PyQt6"
        exit 1
    }
fi

# Check clipboard tool (wl-clipboard for Wayland)
if command -v wl-copy >/dev/null 2>&1; then
    echo -e "  ${OK} wl-clipboard: available"
elif command -v xclip >/dev/null 2>&1; then
    echo -e "  ${OK} xclip: available"
else
    echo -e "  ${INFO} Installing wl-clipboard for clipboard support..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm wl-clipboard 2>/dev/null || true
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install -y wl-clipboard 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y wl-clipboard 2>/dev/null || true
    fi
    if command -v wl-copy >/dev/null 2>&1; then
        echo -e "  ${OK} wl-clipboard: installed"
    else
        echo -e "  ${WARN} No clipboard tool found. Install wl-clipboard manually for 'Copy Admin Password' feature."
    fi
fi

echo ""

# ---------------------------------------------------------------------------
# Step 1: Configure Ollama systemd networking + resource safety
# ---------------------------------------------------------------------------
echo " --- Ollama Configuration ---"

OLLAMA_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OLLAMA_OVERRIDE_FILE="${OLLAMA_OVERRIDE_DIR}/override.conf"

# Create override directory
sudo mkdir -p "$OLLAMA_OVERRIDE_DIR"

# Write the override
sudo tee "$OLLAMA_OVERRIDE_FILE" > /dev/null << OVERRIDE
# Odysseus KDE Integration — Ollama Resource Safety Override
# Installed by install.sh — safe to re-run
#
# Resource safety configuration (Phase 0.6):
#   - OLLAMA_HOST: Listen on all interfaces for Docker connectivity
#   - OLLAMA_KEEP_ALIVE: Keep model loaded 30min to reduce reload latency
#   - OLLAMA_NUM_PARALLEL: Limit concurrency to reduce peak memory
#   - OLLAMA_MAX_LOADED_MODELS: Only one model at a time
#   - OLLAMA_FLASH_ATTENTION: Lower VRAM usage during inference
#   - MemoryHigh/MemoryMax: Soft/hard RAM limits to protect desktop
#   - OOMScoreAdjust: Ollama is first to be killed under memory pressure
#
# NOTE: No GPU VRAM limit is set — the model gets full GPU access.
#       Only system RAM is bounded for desktop fluency.

[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_KEEP_ALIVE=30m"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_FLASH_ATTENTION=1"
OVERRIDE

# Add systemd memory limits
sudo bash -c "cat >> '$OLLAMA_OVERRIDE_FILE'" << 'SYSTEMD'

# Systemd resource safety limits
MemoryHigh=24G
MemoryMax=27G
OOMScoreAdjust=500
SYSTEMD

echo -e "  ${OK} Ollama override: ${OLLAMA_OVERRIDE_FILE}"

# Reload and verify
sudo systemctl daemon-reload
echo -e "  ${OK} systemd daemon-reload"

# Sync user models to system ollama directory
# The systemd service runs as User=ollama, which cannot traverse /home/* (700 perm).
# We sync the user's models into the system ollama user's models directory.
USER_OLLAMA_MODELS="$HOME/.ollama/models"
SYS_OLLAMA_MODELS="/usr/share/ollama/.ollama/models"
if [ -d "$USER_OLLAMA_MODELS/blobs" ] && [ -d "$SYS_OLLAMA_MODELS" ]; then
    echo -e "  ${INFO} Syncing models to system ollama directory..."
    sudo rsync -a "$USER_OLLAMA_MODELS/blobs/" "$SYS_OLLAMA_MODELS/blobs/" 2>/dev/null || true
    sudo rsync -a "$USER_OLLAMA_MODELS/manifests/" "$SYS_OLLAMA_MODELS/manifests/" 2>/dev/null || true
    sudo chown -R ollama:ollama "$SYS_OLLAMA_MODELS" 2>/dev/null || true
    echo -e "  ${OK} Models synced to system ollama directory"
fi

# Handle the dual-instance problem: if a manually-started Ollama is running,
# and the systemd service is failing with "bind: address already in use",
# stop the manual instance and start the systemd service.
if pgrep -x ollama >/dev/null 2>&1 && ! systemctl is-active --quiet ollama 2>/dev/null; then
    # Check if it's the systemd service's ollama or a manual one
    SYSTEMD_OLLAMA_PID=""
    MANUAL_OLLAMA_PID=""
    while IFS= read -r line; do
        pid=$(echo "$line" | awk '{print $1}')
        args=$(echo "$line" | awk '{$1=""; print $0}')
        # The systemd ollama runs as user "ollama"
        owner=$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ "$owner" = "ollama" ]; then
            SYSTEMD_OLLAMA_PID="$pid"
        else
            MANUAL_OLLAMA_PID="$pid"
        fi
    done < <(pgrep -x ollama | head -10)

    if [ -n "$MANUAL_OLLAMA_PID" ]; then
        echo -e "  ${WARN} Manual ollama process found (PID ${MANUAL_OLLAMA_PID}). Stopping it..."
        kill "$MANUAL_OLLAMA_PID" 2>/dev/null || true
        sleep 2
        # Force kill if still running
        kill -9 "$MANUAL_OLLAMA_PID" 2>/dev/null || true
        echo -e "  ${OK} Stopped manual ollama process"
    fi
fi

# Enable and start Ollama
sudo systemctl enable ollama 2>/dev/null || true
sudo systemctl restart ollama
echo -e "  ${OK} Ollama systemd: enabled and restarted"

# Wait for Ollama API
echo -n "  ${INFO} Waiting for Ollama API..."
for i in $(seq 1 30); do
    if curl -s --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        echo " ready"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Verify Ollama API
if curl -s --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo -e "  ${OK} Ollama API: responding"
    # Show models
    echo ""
    curl -s http://127.0.0.1:11434/api/tags | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = data.get('models', [])
if models:
    print('  Installed models:')
    for m in models:
        print(f'    - {m[\"name\"]} ({m[\"details\"][\"parameter_size\"]})')
else:
    print('  No models found (expected after fresh install)')
" 2>/dev/null || echo -e "  ${WARN} Could not parse model list"
else
    echo -e "  ${FAIL} Ollama API: not responding after restart"
    echo "  Check: sudo journalctl -u ollama -n 50"
fi

echo ""

# ---------------------------------------------------------------------------
# Step 2: Create Docker Compose override
# ---------------------------------------------------------------------------
echo " --- Docker Compose Override ---"

ODYSSEUS_OVERRIDE="${ODYSSEUS_DIR}/docker-compose.override.yml"
if [ ! -f "$ODYSSEUS_OVERRIDE" ]; then
    if [ -d "$ODYSSEUS_DIR" ]; then
        cat > "$ODYSSEUS_OVERRIDE" << 'OVERRIDE'
version: '3.8'

services:
  odysseus:
    extra_hosts:
      - "host.docker.internal:host-gateway"
OVERRIDE
        echo -e "  ${OK} Created: ${ODYSSEUS_OVERRIDE}"
    else
        echo -e "  ${WARN} Cannot create override — Odysseus directory not found"
    fi
else
    echo -e "  ${OK} Already exists: ${ODYSSEUS_OVERRIDE}"
fi

echo ""

# ---------------------------------------------------------------------------
# Step 3: Install binaries
# ---------------------------------------------------------------------------
echo " --- Binaries ---"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

for bin in odysseus-tray odysseus-launcher odysseus-healthcheck; do
    if [ -f "$INTEGRATION_DIR/bin/$bin" ]; then
        cp "$INTEGRATION_DIR/bin/$bin" "$BIN_DIR/$bin"
        chmod +x "$BIN_DIR/$bin"
        echo -e "  ${OK} Installed: ${BIN_DIR}/${bin}"
    else
        echo -e "  ${WARN} Not found: ${INTEGRATION_DIR}/bin/${bin}"
    fi
done

echo ""

# ---------------------------------------------------------------------------
# Step 4: Install icon
# ---------------------------------------------------------------------------
echo " --- Icon ---"

ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"

if [ -f "$INTEGRATION_DIR/icons/odysseus.svg" ]; then
    cp "$INTEGRATION_DIR/icons/odysseus.svg" "$ICON_DIR/odysseus.svg"
    echo -e "  ${OK} Installed icon: ${ICON_DIR}/odysseus.svg"
else
    echo -e "  ${WARN} Icon not found"
fi

# Update icon cache if possible
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f >/dev/null 2>&1 || true
fi

echo ""

# ---------------------------------------------------------------------------
# Step 5: Install user systemd service
# ---------------------------------------------------------------------------
echo " --- User Systemd Service ---"

USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"

if [ -f "$INTEGRATION_DIR/systemd/odysseus-tray.service" ]; then
    cp "$INTEGRATION_DIR/systemd/odysseus-tray.service" "$USER_SYSTEMD_DIR/odysseus-tray.service"
    echo -e "  ${OK} Installed: ${USER_SYSTEMD_DIR}/odysseus-tray.service"
else
    echo -e "  ${FAIL} Service file not found"
    exit 1
fi

# Reload user systemd
systemctl --user daemon-reload
echo -e "  ${OK} User systemd daemon-reload"

# Enable and start
systemctl --user enable --now odysseus-tray.service 2>&1 || true
echo -e "  ${OK} User tray service: enabled"

sleep 2

# Check if service is running
if systemctl --user is-active --quiet odysseus-tray.service; then
    echo -e "  ${OK} User tray service: active"
else
    echo -e "  ${WARN} User tray service may need login restart to appear"
    systemctl --user status odysseus-tray.service 2>&1 | head -10 || true
fi

echo ""

# ---------------------------------------------------------------------------
# Step 6: Start Odysseus
# ---------------------------------------------------------------------------
echo " --- Odysseus Startup ---"

if [ -d "$ODYSSEUS_DIR" ] && [ -f "${ODYSSEUS_DIR}/docker-compose.yml" ]; then
    echo "  Starting Odysseus Docker Compose stack..."
    cd "$ODYSSEUS_DIR"
    docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null || true

    # Wait for HTTP endpoint
    echo -n "  ${INFO} Waiting for Odysseus..."
    for i in $(seq 1 30); do
        HTTP_CODE=$(curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://127.0.0.1:7000/login 2>/dev/null || echo "")
        if echo "$HTTP_CODE" | grep -qE '200|302|401'; then
            echo " ready"
            echo -e "  ${OK} Odysseus: http://127.0.0.1:7000 is responding"
            break
        fi
        echo -n "."
        sleep 3
    done
    echo ""
else
    echo -e "  ${WARN} Cannot start Odysseus — directory or docker-compose.yml not found"
fi

# ---------------------------------------------------------------------------
# Step 7: Verify Docker → Ollama connectivity
# ---------------------------------------------------------------------------
echo " --- Docker to Ollama Connectivity ---"

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "odysseus"; then
    ODY_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep odysseus | head -1)
    echo "  Testing from container: ${ODY_CONTAINER}..."
    if docker exec "$ODY_CONTAINER" curl -s --max-time 5 http://host.docker.internal:11434/api/tags >/dev/null 2>&1; then
        echo -e "  ${OK} Odysseus container can reach Ollama via host.docker.internal:11434"
    else
        echo -e "  ${FAIL} Cannot reach Ollama from inside the Odysseus container"
        echo "  Check: docker exec -it ${ODY_CONTAINER} curl http://host.docker.internal:11434/api/tags"
    fi
else
    echo -e "  ${WARN} Cannot test — Odysseus container not running"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "============================================"
echo "  Installation Complete"
echo "============================================"
echo ""
echo "  Components:"
echo "    Tray service:  systemctl --user status odysseus-tray.service"
echo "    Ollama:        sudo systemctl status ollama"
echo "    Odysseus:      http://127.0.0.1:7000"
echo "    Health check:  odysseus-healthcheck"
echo "    Logs:          odysseus-launcher logs"
echo ""
echo "  Resource Safety:"
echo "    GPU VRAM:      Full access (no reservation)"
echo "    Memory limit:  24 GiB (MemoryHigh) / 27 GiB (MemoryMax)"
echo "    OOM priority:  Ollama sacrificed first (OOMScoreAdjust=500)"
echo "    Keep-alive:    30 minutes"
echo ""
echo "  Commands:"
echo "    odysseus-tray          # Run tray (already a service)"
echo "    odysseus-launcher start|stop|restart"
echo "    odysseus-healthcheck   # Full health + resource check"
echo ""
echo "  The tray should now be visible in your system tray."
echo "  If not, try: systemctl --user restart odysseus-tray.service"
echo ""

if [ -n "${SUDO_USER:-}" ] || [ "$(id -u)" = "0" ]; then
    echo -e "  ${WARN} This script was run with sudo. Binaries were installed"
    echo "  for root, not for the normal user. Run as your normal user:"
    echo "    ./install.sh"
    echo ""
fi
