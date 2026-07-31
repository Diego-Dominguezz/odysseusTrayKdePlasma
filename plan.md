I need you to build a clean, production-quality Linux/KDE Plasma integration repository for my EXISTING Odysseus installation.

IMPORTANT: This project is an integration layer around an existing Odysseus installation. Do NOT install or recreate Odysseus itself.

## EXISTING ENVIRONMENT

I am running:

* CachyOS Linux
* KDE Plasma 6
* Wayland
* Fish shell
* AMD Radeon RX 7800 XT
* Docker Engine
* Docker Compose
* Ollama
* Odysseus already installed at:

`~/Downloads/odysseus`

The existing Odysseus application is already configured and working when manually started with Docker Compose.

The existing Odysseus Compose project contains services such as:

* odysseus
* chromadb
* ntfy
* searxng

Do not replace this installation.

Do not clone another Odysseus repository.

Do not install another Odysseus instance.

Do not create a system-wide Odysseus service.

Do not move the existing Odysseus directory.

The integration must control the existing installation in:

`~/Downloads/odysseus`

---

# PRIMARY OBJECTIVE

Create a standalone Git repository whose ONLY purpose is to integrate my existing Odysseus + Ollama installation with KDE Plasma.

The final user experience should feel like a normal desktop application:

KDE Plasma starts
↓
User-level Odysseus Tray service starts automatically
↓
Tray application checks Ollama
↓
Ollama system service is started if necessary
↓
Tray application starts the EXISTING Odysseus Docker Compose project
↓
Odysseus becomes available at:

http://127.0.0.1:7000

The user should see an Odysseus icon in the KDE Plasma system tray.

The tray menu should provide:

* Status
* Start Odysseus
* Stop Odysseus
* Restart Odysseus
* Open Odysseus
* View Logs
* Check Ollama
* Restart Ollama
* Quit Tray

The tray must NOT run Odysseus as a system service.

The tray must NOT create a second Odysseus installation.

The tray must simply control:

`docker compose up -d`

and:

`docker compose down`

inside:

`~/Downloads/odysseus`

---

# OLLAMA ARCHITECTURE

Ollama is installed as a SYSTEM systemd service.

The current service is:

`ollama.service`

It runs as:

`User=ollama`

The Ollama API listens on:

`127.0.0.1:11434`

or must be configured to listen on:

`0.0.0.0:11434`

The existing models include:

* qwen3:14b
* qwen2.5-coder:14b
* qwen3:8b

These models already exist and MUST NOT be deleted.

Do not download them again unless explicitly necessary.

Do not move or erase existing Ollama model data.

The integration must detect the existing Ollama installation.

The integration must configure Ollama so Docker containers can access it.

The preferred host endpoint is:

`http://host.docker.internal:11434`

Ollama must therefore listen on:

`0.0.0.0:11434`

Use a systemd drop-in override if necessary:

`/etc/systemd/system/ollama.service.d/override.conf`

with:

`Environment="OLLAMA_HOST=0.0.0.0:11434"`

After modifying the service:

* daemon-reload
* restart Ollama
* verify `/api/tags`

Do NOT create a second `ollama serve` process.

Do NOT manually launch `ollama serve` if `ollama.service` is already running.

The tray must interact with the system service using:

`sudo systemctl start ollama`

`sudo systemctl stop ollama`

`sudo systemctl restart ollama`

`systemctl is-active ollama`

Because Ollama is a system service, do not use:

`systemctl --user`

for Ollama.

---

# DOCKER → OLLAMA NETWORKING

This is critical.

The Odysseus Docker container currently tries to reach:

`http://host.docker.internal:11434`

but receives:

`503 Cannot reach http://host.docker.internal:11434`

The final solution MUST fix this.

Add a Docker Compose override to the existing Odysseus installation:

`~/Downloads/odysseus/docker-compose.override.yml`

The override should add:

```yaml
services:
  odysseus:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Do not modify the original Odysseus `docker-compose.yml` unless absolutely necessary.

Prefer the override file so that the integration is isolated from the upstream Odysseus repository.

The installer must verify connectivity from inside the Odysseus container.

For example, test:

`http://host.docker.internal:11434/api/tags`

from inside the running Odysseus container.

The installation is NOT successful until:

1. Ollama is reachable from the host.
2. Ollama is reachable from inside the Odysseus container.
3. Odysseus can successfully use the configured local model.

---

# USER-LEVEL TRAY SERVICE

This is the most important architectural requirement.

Create a USER-LEVEL systemd service:

`~/.config/systemd/user/odysseus-tray.service`

This service must run as the normal logged-in user.

It must NOT be installed in:

`/etc/systemd/system/`

It must NOT run as root.

It must NOT be a system-wide service.

It should look conceptually like:

```ini
[Unit]
Description=Odysseus KDE Plasma Tray
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/odysseus-tray
Restart=on-failure
RestartSec=5
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0

[Install]
WantedBy=default.target
```

Adapt this appropriately for KDE Plasma Wayland.

The tray service must be enabled with:

`systemctl --user enable --now odysseus-tray.service`

The user should be able to check it with:

`systemctl --user status odysseus-tray.service`

The tray must automatically launch after login.

Do NOT rely exclusively on a `.desktop` autostart entry.

The primary mechanism must be the user-level systemd service.

If KDE Plasma environment variables are required, handle them correctly for a graphical user session.

---

# TRAY APPLICATION

Create:

`~/.local/bin/odysseus-tray`

It can be implemented in Python with PyQt6.

The tray application must:

1. Show a KDE Plasma system tray icon.
2. Start automatically with the user systemd service.
3. Detect whether Odysseus is running.
4. Detect whether Ollama is running.
5. Show clear status.

The tray should display statuses such as:

* Ollama: Running
* Ollama: Stopped
* Odysseus: Running
* Odysseus: Starting
* Odysseus: Stopped
* Error

The tray must not automatically stop Odysseus just because the tray process exits.

The tray's "Quit" action should ONLY quit the tray application.

It should NOT stop Odysseus or Ollama unless explicitly requested.

---

# STARTUP ORDER

Startup must be reliable.

When the tray starts:

1. Check whether Ollama is active.
2. If Ollama is inactive, start it using:

`sudo systemctl start ollama`

3. Wait until:

`http://127.0.0.1:11434/api/tags`

responds successfully.

4. Verify that at least one configured model exists.
5. Start the existing Odysseus Compose stack:

`docker compose up -d`

from:

`~/Downloads/odysseus`

6. Wait for:

`http://127.0.0.1:7000/login`

to respond.

7. Mark Odysseus as Running.

Do not start Odysseus before Ollama is reachable.

This prevents the 503 problem caused by Odysseus starting while Ollama is unavailable.

---

# STOPPING

When the user selects "Stop Odysseus":

Run:

`docker compose down`

inside:

`~/Downloads/odysseus`

This should stop the Odysseus Docker stack.

Do NOT stop Ollama automatically.

Ollama should remain available for other local applications.

The user can explicitly choose:

"Stop Ollama"

if that option is provided.

---

# RESTART

"Restart Odysseus" should:

1. `docker compose down`
2. Wait briefly
3. Verify Ollama is reachable
4. `docker compose up -d`
5. Wait for Odysseus HTTP readiness
6. Update tray status

"Restart All" may optionally:

1. Restart Ollama system service.
2. Wait for Ollama API.
3. Restart Docker Compose.
4. Verify Odysseus.

---

# ICON

Create a proper Odysseus SVG icon.

Install it to:

`~/.local/share/icons/hicolor/scalable/apps/odysseus.svg`

The tray MUST verify that the icon exists before starting.

Avoid the previous issue where the tray launched with:

`QSystemTrayIcon::setVisible: No Icon set`

The installer must correctly create the SVG file.

Because the user uses Fish, do NOT provide Bash heredoc commands that the user is expected to paste directly into Fish.

The installer itself may be Bash, but the user-facing installation command should simply be:

```bash
./install.sh
```

The installer should use proper Bash heredocs internally.

---

# INSTALLER

Create one main command:

```bash
./install.sh
```

This must perform the complete integration.

It must:

1. Detect the existing Odysseus directory.
2. Detect Docker.
3. Detect Docker Compose.
4. Detect Ollama.
5. Verify the user is in the Docker group.
6. Configure Ollama systemd networking.
7. Enable Ollama at boot.
8. Restart Ollama.
9. Verify Ollama API.
10. Create the Odysseus Docker Compose override.
11. Create the tray application.
12. Create the tray icon.
13. Create the user systemd service.
14. Reload user systemd.
15. Enable the tray service.
16. Start the tray service.
17. Verify the tray process is running.
18. Start Odysseus.
19. Verify Odysseus HTTP endpoint.
20. Verify Docker → Ollama connectivity.
21. Print a final status summary.

The installer must be idempotent.

Running:

```bash
./install.sh
```

multiple times must be safe.

It must NOT duplicate services.

It must NOT duplicate Docker containers.

It must NOT delete models.

It must NOT delete Odysseus data.

It must NOT overwrite the existing Odysseus application source.

---

# DOCKER GROUP

The user currently has Docker group membership.

Still, the installer should verify:

```bash
id -nG
```

contains:

`docker`

If not, add the user:

```bash
sudo usermod -aG docker "$USER"
```

Then clearly explain that the user must log out and back in.

Do not use `sudo docker` as the permanent solution.

The tray must run Docker as the normal user.

---

# REPOSITORY STRUCTURE

Create a standalone Git repository with:

```text
odysseus-kde-integration/
├── README.md
├── LICENSE
├── .gitignore
├── install.sh
├── uninstall.sh
├── bin/
│   ├── odysseus-launcher
│   ├── odysseus-tray
│   └── odysseus-healthcheck
├── systemd/
│   └── odysseus-tray.service
├── desktop/
│   └── odysseus-tray.desktop
├── icons/
│   └── odysseus.svg
├── compose/
│   └── docker-compose.override.yml
└── scripts/
    └── verify-installation.sh
```

The repository must NOT contain the actual Odysseus source code.

The repository must NOT contain Ollama models.

The repository only contains the integration layer.

---

# HEALTH CHECK

Create:

`odysseus-healthcheck`

It must verify:

1. Ollama systemd service status.
2. Ollama API.
3. Installed models.
4. Docker daemon.
5. Docker Compose.
6. Odysseus containers.
7. Docker → Ollama connectivity.
8. Odysseus HTTP endpoint.
9. User tray systemd service.

Output a clear table:

```text
Component              Status
--------------------------------
Ollama service         OK
Ollama API             OK
Models                 OK
Docker                 OK
Odysseus container     OK
Docker -> Ollama       OK
Odysseus HTTP          OK
KDE Tray               OK
```

---

# UNINSTALLER

Create:

`./uninstall.sh`

It must ONLY remove the integration layer.

It may remove:

* `~/.local/bin/odysseus-tray`
* `~/.local/bin/odysseus-launcher`
* `~/.local/bin/odysseus-healthcheck`
* `~/.config/systemd/user/odysseus-tray.service`
* KDE autostart files if created
* the integration-created Docker Compose override

It MUST NOT remove:

* Ollama
* Ollama models
* Odysseus source
* Odysseus database
* Odysseus data
* Docker
* Docker containers unless explicitly requested
* user files

If the installer modified the Ollama systemd drop-in, document how to safely revert that change.

---

# GIT INITIALIZATION

At the end, initialize Git:

```bash
git init
git branch -M main
git add .
git commit -m "Initial KDE Plasma Odysseus integration"
```

Do not configure a fake GitHub remote.

Print instructions for the user to add their own GitHub remote.

---

# FINAL ACCEPTANCE CRITERIA

The implementation is considered successful ONLY if all of these are true:

1. I log into KDE Plasma.
2. The user systemd service automatically starts.
3. The Odysseus tray icon appears.
4. Ollama system service is running.
5. Ollama API responds.
6. Existing models are detected.
7. Docker Compose starts the EXISTING Odysseus installation.
8. Odysseus can reach Ollama from inside Docker.
9. Odysseus can successfully chat with qwen3:14b.
10. The tray reports correct status.
11. "Open Odysseus" opens `http://127.0.0.1:7000`.
12. "Stop Odysseus" stops the Docker stack.
13. "Start Odysseus" starts it again.
14. "Restart Odysseus" works.
15. "Quit Tray" only quits the tray.
16. Logging in again automatically restores the tray and Odysseus stack.
17. Re-running `./install.sh` is safe.
18. No duplicate Odysseus installation is created.
19. No Ollama models are deleted.
20. No system-wide Odysseus service is created.

Before finishing, test the complete lifecycle:

```text
logout
login
    ↓
user systemd starts odysseus-tray
    ↓
Ollama starts
    ↓
Ollama API ready
    ↓
Docker Compose starts
    ↓
Odysseus starts
    ↓
Docker → Ollama connectivity verified
    ↓
Odysseus chat works
```

The final output should provide:

1. Complete repository files.
2. Complete `install.sh`.
3. Complete `uninstall.sh`.
4. Complete tray application.
5. Complete user-level systemd service.
6. Complete Docker Compose override.
7. Complete health check.
8. Complete README.
9. Exact one-command installation instructions.
10. Exact commands to push the repository to GitHub.

Do not simplify the architecture by replacing the user-level tray service with a system-wide Odysseus service. The separation between the existing Odysseus Docker installation, the system-level Ollama service, and the user-level KDE tray controller is a hard requirement.
