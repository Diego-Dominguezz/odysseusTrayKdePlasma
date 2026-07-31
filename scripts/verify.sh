#!/usr/bin/env bash
set -Eeuo pipefail
ODYSSEUS_DIR="${ODYSSEUS_DIR:-$HOME/Downloads/odysseus}"
echo '== Ollama service =='; systemctl is-enabled ollama; systemctl is-active ollama
echo '== Host API =='; curl -fsS http://127.0.0.1:11434/api/tags >/dev/null && echo OK
echo '== Container -> Ollama =='; docker compose -f "$ODYSSEUS_DIR/docker-compose.yml" -f "$ODYSSEUS_DIR/docker-compose.override.yml" exec -T odysseus python -c 'import urllib.request; print(urllib.request.urlopen("http://host.docker.internal:11434/api/tags",timeout=5).status)'
echo '== Odysseus =='; curl -fsS http://127.0.0.1:7000/login >/dev/null && echo OK
echo 'All checks passed.'
