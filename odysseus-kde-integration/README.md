# Odysseus KDE Integration

A standalone KDE Plasma integration layer for an existing [Odysseus](https://github.com/kingwrcy/odysseus) + Ollama local LLM installation.

This repository contains **only** the integration layer — it does not contain Odysseus source code, Ollama models, or Docker images.

## Architecture

```
KDE Plasma / Wayland
    |
    | User systemd service (~/.config/systemd/user/odysseus-tray.service)
    |
    +--- odysseus-tray (PyQt6 system tray)
    |       |
    |       +--- Manages: Odysseus Docker Compose stack (start/stop/restart)
    |       +--- Monitors: Ollama system service
    |       +--- Reports:  System resources (RAM, VRAM, memory pressure)
    |
    +--- odysseus-launcher  →  docker compose in ~/Downloads/odysseus
    |
    +--- odysseus-healthcheck → Full system + resource verification

System services (not modified):
    |
    +--- ollama.service (systemd system-level)
    |       +--- Resource safety overlay (/etc/systemd/system/ollama.service.d/override.conf)
    |       +--- OLLAMA_GPU_OVERHEAD=2048 → 2 GiB VRAM reserved for display
    |       +--- MemoryHigh=24G / MemoryMax=27G → Desktop protected from OOM
    |       +--- OOMScoreAdjust=500 → Ollama sacrificed first
    |
    +--- Odysseus Docker Compose (existing, ~/Downloads/odysseus)
            +--- docker-compose.override.yml → host.docker.internal
```

## Requirements

- **KDE Plasma 6** (Wayland)
- **Docker Engine** + **Docker Compose**
- **Ollama** (systemd service, with models already downloaded)
- **Existing Odysseus** installation at `~/Downloads/odysseus`
- **Python 3** + **PyQt6** (installed automatically)
- **AMD Radeon RX 7800 XT** (or any GPU with ROCm support — VRAM safety thresholds adjustable)

## Installation

```bash
git clone <your-repo-url> odysseus-kde-integration
cd odysseus-kde-integration
./install.sh
```

The installer is **idempotent** — running it multiple times is safe.

### What the installer does:

| Step | Action |
|------|--------|
| 1 | Pre-flight checks (Docker, Docker Compose, Ollama, PyQt6) |
| 2 | Creates Ollama systemd override with resource safety limits |
| 3 | Fixes dual-Ollama problem if present |
| 4 | Creates Docker Compose override for `host.docker.internal` |
| 5 | Installs tray, launcher, healthcheck to `~/.local/bin/` |
| 6 | Installs tray icon to `~/.local/share/icons/` |
| 7 | Creates user systemd service, enables and starts it |
| 8 | Starts Odysseus Docker Compose |
| 9 | Verifies Docker → Ollama connectivity |

## Uninstallation

```bash
./uninstall.sh
```

Removes only the integration layer. Preserves:
- Ollama and all models
- Odysseus source and data
- Docker containers (unless `--remove-containers` is passed)

## Usage

### System Tray

After installation, the Odysseus tray icon should appear in your KDE Plasma system tray. Right-click for the menu:

| Menu Item | Action |
|-----------|--------|
| Status | Current Ollama + Odysseus state |
| Open Odysseus | Opens http://127.0.0.1:7000 in browser |
| Start Odysseus | `docker compose up -d` |
| Stop Odysseus | `docker compose down` |
| Restart Odysseus | Down, wait, up, verify |
| View Logs | Opens `docker compose logs -f` in Konsole |
| Health Check | Runs full diagnostic |
| Ollama status | Shows running/stopped, model count |
| Start Ollama | `sudo systemctl start ollama` |
| Restart Ollama | `sudo systemctl restart ollama` |
| Quit Tray | Quits only the tray (does not stop anything) |

### Command Line

```bash
# Health check with resource monitoring
odysseus-healthcheck

# Control Odysseus
odysseus-launcher start
odysseus-launcher stop
odysseus-launcher restart
odysseus-launcher status
odysseus-launcher logs

# Service status
systemctl --user status odysseus-tray.service
sudo systemctl status ollama
```

## Resource Safety (Phase 0.6)

The integration includes a resource safety layer to prevent Ollama from causing KDE Plasma hangs or input freezes.

### Diagnostic Finding

The **gemma4:26b (Q4_K_M)** model uses ~8.4 GB VRAM + ~9.2 GB system RAM peak.
The model gets **full GPU access** — no VRAM is reserved away from it.
Only system RAM is bounded to protect the desktop from memory pressure.

### Safety Mechanisms

| Mechanism | Setting | Purpose |
|-----------|---------|---------|
| GPU access | **Unlimited** | Model uses all available VRAM |
| Keep-alive | `OLLAMA_KEEP_ALIVE=30m` | Reduce model reload frequency |
| Concurrency | `OLLAMA_NUM_PARALLEL=1` | Limit peak memory |
| Models | `OLLAMA_MAX_LOADED_MODELS=1` | Only one model at a time |
| Flash attention | `OLLAMA_FLASH_ATTENTION=1` | Slightly lower VRAM usage |
| Soft RAM limit | `MemoryHigh=24G` | Protect desktop from memory starvation |
| Hard RAM limit | `MemoryMax=27G` | Prevent system OOM |
| OOM priority | `OOMScoreAdjust=500` | Ollama killed before desktop processes |
| Health check | `odysseus-healthcheck` | Monitors MemAvailable, PSI, swap, Ollama RSS |

### Resource Zones

| Zone | MemAvailable | Action |
|------|-------------|--------|
| Normal | > 8 GiB | Normal operation |
| Warning | 5-8 GiB | Warn user, monitor memory growth |
| Critical | 3-5 GiB | Recommend unloading / reducing model workload |
| Emergency | < 3 GiB | Model may be unloaded under OOM pressure |

## Files

```
odysseus-kde-integration/
├── README.md
├── LICENSE
├── .gitignore
├── install.sh                    # Idempotent installer
├── uninstall.sh                  # Safe uninstaller
├── bin/
│   ├── odysseus-launcher         # Docker Compose wrapper
│   ├── odysseus-tray             # PyQt6 KDE system tray
│   └── odysseus-healthcheck      # Full system health verification
├── systemd/
│   └── odysseus-tray.service     # User-level systemd unit
├── desktop/
│   └── odysseus-tray.desktop     # KDE autostart entry
├── icons/
│   └── odysseus.svg              # Tray icon
├── compose/
│   └── docker-compose.override.yml  # Docker networking override
├── ollama/
│   └── override.conf             # Resource safety template
└── scripts/
    └── verify-installation.sh    # Post-install verification
```

## License

MIT