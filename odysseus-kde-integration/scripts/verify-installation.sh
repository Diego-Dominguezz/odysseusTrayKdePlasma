#!/bin/bash
# Odysseus KDE Integration — Installation Verification
# Verifies that the integration was correctly installed.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS="${GREEN}PASS${NC}"; FAIL="${RED}FAIL${NC}"; WARN="${YELLOW}WARN${NC}"

echo ""
echo "============================================"
echo "  Odysseus KDE Integration — Verify"
echo "============================================"
echo ""

errors=0

verify() {
    local name="$1" desc="$2"
    if [ "$3" = "true" ] || [ "$3" = "0" ]; then
        echo -e "  ${PASS}  ${name}: ${desc}"
    elif [ "$3" = "warn" ]; then
        echo -e "  ${WARN}  ${name}: ${desc} (not found, but may be optional)"
    else
        echo -e "  ${FAIL}  ${name}: ${desc}"
        errors=$((errors + 1))
    fi
}

# Check tray binary
verify "odysseus-tray" "~/.local/bin/odysseus-tray" "$(test -f ~/.local/bin/odysseus-tray && echo true || echo false)"

# Check launcher
verify "odysseus-launcher" "~/.local/bin/odysseus-launcher" "$(test -f ~/.local/bin/odysseus-launcher && echo true || echo false)"

# Check healthcheck
verify "odysseus-healthcheck" "~/.local/bin/odysseus-healthcheck" "$(test -f ~/.local/bin/odysseus-healthcheck && echo true || echo false)"

# Check user systemd service
verify "Tray systemd" "~/.config/systemd/user/odysseus-tray.service" "$(test -f ~/.config/systemd/user/odysseus-tray.service && echo true || echo false)"

# Check tray service is enabled
verify "Tray enabled" "systemctl --user is-enabled" "$(systemctl --user is-enabled odysseus-tray.service 2>/dev/null || echo false)"

# Check tray service is active
verify "Tray active" "systemctl --user is-active" "$(systemctl --user is-active odysseus-tray.service 2>/dev/null || echo false)"

# Check icon
verify "Icon" "~/.local/share/icons/hicolor/scalable/apps/odysseus.svg" "$(test -f ~/.local/share/icons/hicolor/scalable/apps/odysseus.svg && echo true || echo false)"

# Check Docker override
verify "Docker override" "~/Downloads/odysseus/docker-compose.override.yml" "$(test -f ~/Downloads/odysseus/docker-compose.override.yml && echo true || echo false)"

# Check Ollama override
verify "Ollama override" "/etc/systemd/system/ollama.service.d/override.conf" "$(test -f /etc/systemd/system/ollama.service.d/override.conf && echo true || echo false)"

# Check Ollama service
verify "Ollama service" "systemctl is-active" "$(systemctl is-active ollama 2>/dev/null || echo false)"

# Check Ollama API
verify "Ollama API" "http://127.0.0.1:11434/api/tags" "$(curl -s --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && echo true || echo false)"

# Check Docker
verify "Docker daemon" "docker info" "$(docker info >/dev/null 2>&1 && echo true || echo false)"

# Check Docker group membership
verify "Docker group" "id -nG | grep docker" "$(id -nG | grep -q docker && echo true || echo false)"

echo ""
if [ "$errors" -gt 0 ]; then
    echo -e "  ${RED}${errors} checks failed${NC}"
    exit 1
else
    echo -e "  ${GREEN}All checks passed${NC}"
    exit 0
fi