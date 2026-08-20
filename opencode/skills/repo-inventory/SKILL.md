---
name: repo-inventory
description: Use when the user asks to inventory, map, or understand repository structure, identify entry points, languages, frameworks, or locate key files. Triggers: "inventory", "repository structure", "map the repo", "entry points", "what does this project contain". Front-load the workflow that uses read-only bash (ls, rg, find, wc) for fast targeted discovery.
---

# Repository Inventory

Run a fast, evidence-first inventory of the current repository.

## Workflow

1. Identify the workspace root (git root or cwd).
2. Read README.md when present (first 200 lines).
3. One-shot bash sweep instead of many tool calls:
   - `ls -la <root>`
   - `find <root> -maxdepth 2 -type f | head -100`
   - `rg -n "language|framework" <root>/README.md` or check manifest files
4. Detect languages/frameworks from manifests: package.json, Cargo.toml, pyproject.toml, go.mod, pom.xml, *.csproj, Gemfile, etc.
5. Identify entry points: main, src/index, CLI entry, service files, docker-compose, systemd units.
6. Report structure as a tree (depth 2), entry points, and per-directory purpose.

## Rules

- Read-only commands only. Never mutate.
- If README.md is missing, say so and infer from manifests + source layout.
- Separate VERIFIED (inspected) from HYPOTHESIS (inferred).
- Return the inventory concisely; do not dump full file contents.