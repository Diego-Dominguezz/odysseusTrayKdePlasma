---
name: security-audit
description: Use when the user asks for a security audit, security review, vulnerability assessment, or architecture review of a repository. Triggers: "security audit", "security review", "vulnerability", "audit this repo", "is this safe". Routes through the deterministic research-gate -> qwen3-auditor pipeline. Do NOT perform ad-hoc audits; use the mandatory pipeline.
---

# Security Audit

Route repository security and architecture reviews through the deterministic pipeline.

## Mandatory pipeline

1. Invoke `research-gate` FIRST with the review scope (exact question, bounded paths).
2. Wait for the complete RESEARCH PACKAGE.
3. Invoke `qwen3-auditor` SECOND, passing the research package and the specific decision to audit.
4. Wait for the complete AUDIT.
5. Synthesize the final answer from both stages.

## Fail-closed rules

- If research-gate returns empty or unusable output: STOP. Do not substitute your own research.
- If qwen3-auditor returns empty or unusable output: STOP. Do not substitute your own audit.
- Never claim a stage completed unless an actual task result was returned.
- Classify every consequential claim as VERIFIED / HYPOTHESIS / UNKNOWN.

## Scope control

- Give research-gate an exact question and bounded scope (paths to inspect, files of interest).
- Never audit unrelated directories.
- Re-invoke a stage ONCE if it returns empty before concluding failure.