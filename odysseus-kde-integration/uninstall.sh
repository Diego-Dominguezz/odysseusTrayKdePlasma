#!/bin/bash
# Odysseus KDE Integration — Uninstaller
#
# Removes ONLY the integration layer. Does NOT touch:
#   - Ollama
#   - Ollama models
#   - Odysseus source
#   - Odysseus data
#   - Docker
#   - Docker containers (unless --remove-containers is passed)
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
WARN="${YELLOW}WARN${NC}"; OK="${GREEN}OK${NC}"

echo ""
echo "============================================"
echo "  Odysseus KDE Integration — Uninstall"
echo "============================================"
echo ""

# Confirm
read -r -p "Remove Odysseus KDE integration? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# Stop and disable tray service
if systemctl --user is-active --quiet odysseus-tray.service 2>/dev/null; then
    echo "Stopping tray service..."
    systemctl --user stop odysseus-tray.service
fi
if systemctl --user is-enabled --quiet odysseus-tray.service 2>/dev/null; then
    echo "Disabling tray service..."
    systemctl --user disable odysseus-tray.service
fi
echo -e "  ${OK} Tray service stopped and disabled"

# Remove user systemd service
SERVICE_FILE="$HOME/.config/systemd/user/odysseus-tray.service"
if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
    echo -e "  ${OK} Removed: ${SERVICE_FILE}"
fi

# Remove binaries
for bin in odysseus-tray odysseus-launcher odysseus-healthcheck; do
    BIN_PATH="$HOME/.local/bin/$bin"
    if [ -f "$BIN_PATH" ]; then
        rm -f "$BIN_PATH"
        echo -e "  ${OK} Removed: ${BIN_PATH}"
    fi
done

# Remove icon
ICON_PATH="$HOME/.local/share/icons/hicolor/scalable/apps/odysseus.svg"
if [ -f "$ICON_PATH" ]; then
    rm -f "$ICON_PATH"
    echo -e "  ${OK} Removed: ${ICON_PATH}"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f >/dev/null 2>&1 || true
    fi
fi

# Remove Docker Compose override (integration-created)
ODYSSEUS_OVERRIDE="${HOME}/Downloads/odysseus/docker-compose.override.yml"
if [ -f "$ODYSSEUS_OVERRIDE" ]; then
    echo ""
    echo -e "  ${WARN} Docker Compose override found: ${ODYSSEUS_OVERRIDE}"
    read -r -p "  Remove it? (y/N): " remove_override
    if [ "$remove_override" = "y" ] || [ "$remove_override" = "Y" ]; then
        rm -f "$ODYSSEUS_OVERRIDE"
        echo -e "  ${OK} Removed docker-compose.override.yml"
    fi
fi

# Ollama systemd override
OLLAMA_OVERRIDE="/etc/systemd/system/ollama.service.d/override.conf"
if [ -f "$OLLAMA_OVERRIDE" ]; then
    echo ""
    echo -e "  ${WARN} Ollama systemd override exists: ${OLLAMA_OVERRIDE}"
    echo "  This file contains resource safety configuration (MemoryHigh, OOMScoreAdjust, etc.)."
    echo "  To revert to default Ollama configuration, this file must be removed."
    echo "  WARNING: Removing it will remove OLLAMA_HOST=0.0.0.0:11434, which may"
    echo "  break Docker-to-Ollama connectivity."
    read -r -p "  Remove Ollama override? (y/N): " remove_ollama
    if [ "$remove_ollama" = "y" ] || [ "$remove_ollama" = "Y" ]; then
        sudo rm -f "$OLLAMA_OVERRIDE"
        sudo systemctl daemon-reload
        sudo systemctl restart ollama || true
        echo -e "  ${OK} Removed Ollama override and restarted Ollama"
    else
        echo "  Keeping Ollama override."
    fi
fi

# Remove Docker containers (optional)
echo ""
if [ "${1:-}" = "--remove-containers" ]; then
    echo "Removing Odysseus Docker containers..."
    cd "$HOME/Downloads/odysseus" 2>/dev/null && docker compose down -v 2>/dev/null || true
    echo -e "  ${OK} Odysseus containers removed"
fi

echo ""
echo "============================================"
echo "  Uninstall Complete"
echo "============================================"
echo ""
echo "  The following are preserved:"
echo "    - Ollama (and models)"
echo "    - Odysseus source (in ~/Downloads/odysseus)"
echo "    - Docker"
echo "    - All user data"
echo ""
echo "  To also remove Odysseus Docker containers:"
echo "    ./uninstall.sh --remove-containers"
echo ""
echo "  To manually restore the Ollama override if you kept it:"
echo "    sudo nano /etc/systemd/system/ollama.service.d/override.conf"
echo "    sudo systemctl daemon-reload"
echo "    sudo systemctl restart ollama"
echo ""
