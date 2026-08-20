---
name: browser-debug
description: Use when the user reports browser problems: page load failures, blank pages, DNS/network issues, console errors, or wants page inspection, screenshots, or network diagnostics. Triggers: "browser", "page won't load", "blank page", "brave", "website", "dom", "screenshot". Uses the playwright MCP tools (mcp__playwright__*).
---

# Browser Debugging

Diagnose browser and page-loading problems with the Playwright MCP tools.

## Workflow

1. Start with the failing URL. Use `mcp__playwright__browser_navigate` to load it.
2. Capture the failure surface:
   - `mcp__playwright__browser_snapshot` for DOM state
   - console messages and network failures (the tool surfaces these on failures)
   - `mcp__playwright__browser_take_screenshot` when a visual is needed
3. Reproduce the failure in a fresh context if state may be stale:
   - `mcp__playwright__browser_new_context` then navigate.
4. Diagnose systematically: DNS resolution, proxy settings, TLS, redirects, service worker, CSP.
5. Test candidate fixes by reloading the page after each change; verify with the DOM snapshot.

## Rules

- One change at a time; verify after each.
- If the target is a local service, check the service is up first (bash: curl, ss, systemctl --user status).
- Separate VERIFIED (observed in the browser) from HYPOTHESIS (inferred from configs).
- If Playwright itself fails to launch, report the exact error; do not silently fall back to guesses.