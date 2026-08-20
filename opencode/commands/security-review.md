---
description: Mandatory research-first security and architecture review
agent: security-review
model: ollama/gpt-oss:20b-opencode
subtask: false
---
Run the security-review pipeline exactly as configured.
Do not bypass research-gate.
Do not bypass qwen3-auditor.
Do not perform a manual substitute analysis when a required task fails.

$ARGUMENTS
