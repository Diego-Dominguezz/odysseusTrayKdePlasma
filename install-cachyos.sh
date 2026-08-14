#!/bin/bash

# One-command installer for Odysseus Local Stack on CachyOS
# This script installs all dependencies and sets up the complete stack

set -euo pipefail

echo "============================================"
echo "  Odysseus Local Stack Installer for CachyOS"
echo "============================================"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "This script should not be run as root. Please run as a normal user."
  exit 1
fi

# Update system packages
echo "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install required dependencies
echo "Installing required dependencies..."
sudo pacman -S --noconfirm \
    ollama \
    docker \
    docker-compose \
    python \
    python-pip \
    PyQt6 \
    wl-clipboard \
    xclip

# Enable and start Docker service
echo "Starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group
echo "Adding user to docker group..."
sudo usermod -aG docker "$USER"

# Install dependencies for Python PyQt6 if needed
echo "Installing Python dependencies..."
pip3 install --user PyQt6

# Check if repo is already cloned
if [ ! -d "$HOME/odysseus-local-stack" ]; then
    echo "Cloning repository..."
    git clone https://github.com/YOUR_USERNAME/odysseus-local-stack.git "$HOME/odysseus-local-stack"
    cd "$HOME/odysseus-local-stack"
else
    echo "Repository already exists, pulling latest changes..."
    cd "$HOME/odysseus-local-stack"
    git pull origin main
fi

# Run the main installer
echo "Running main installer..."
if [ -n "${ODYSSEUS_DIR:-}" ]; then
    ODYSSEUS_DIR="$ODYSSEUS_DIR" ./install.sh
else
    ./install.sh
fi

echo ""
echo "============================================"
echo "  Installation Complete!"
echo "============================================"
echo ""
echo "To start using the stack:"
echo "1. Restart your session (or run: systemctl --user daemon-reload)"
echo "2. The Odysseus tray icon should now appear in your system tray"
echo "3. Ollama and Odysseus are running in the background"
echo ""
echo "For full details about the installation:"
echo "  systemctl --user status odysseus-tray.service"
echo "  sudo systemctl status ollama"
echo "  http://127.0.0.1:7000 (Odysseus web interface)"
echo ""