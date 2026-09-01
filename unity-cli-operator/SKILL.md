---
name: unity-cli-operator
description: Install, update, authenticate, diagnose, and operate the standalone Unity CLI on Windows, including Clash Verge and Proxifier routing, isolated browser OAuth, Unity Editor management, and Unity Pipeline automation. Use for the `unity` executable; do not use for ordinary Unity Hub GUI maintenance or raw Editor batch-mode work that does not involve Unity CLI.
---

# Unity CLI Operator

Operate the standalone Unity CLI reliably on Windows, especially where regional routing, stale CDN metadata, OAuth redirects, or Editor package downloads require explicit proxy handling.

## Core Invariants

- Distinguish the standalone `unity` executable and package ID `Unity.CLI` from Unity Hub (`Unity.UnityHub`) and Editor `-batchmode`.
- Discover the installed command, version, install method, proxy port, project Editor version, and current Editor/Pipeline state. Do not assume values from an earlier run.
- Prefer official Unity distribution channels. Never download a CLI or Editor from a third-party mirror.
- Treat the CLI, browser, identity provider, Unity Editor, and Package Manager as separate network clients. Route each client that participates in the current workflow.
- Unity CLI natively supports `--proxy`, `UNITY_PROXY`, and `unity config proxy`; it does not require Proxifier. Use the native per-command proxy first. Treat Proxifier only as an optional fallback for a process that cannot be routed explicitly.
- Keep `localhost` and `127.0.0.1` direct so OAuth callbacks and the local Pipeline service are not sent through Proxifier.
- Never expose or persist passwords, access tokens, client secrets, OAuth URLs, PKCE values, 2FA codes, recovery codes, proxy credentials, or unredacted credential-store output.
- Browser isolation corrects stale cookies and inconsistent routing. It does not authorize bypassing legal, account, organization, or service-eligibility restrictions.
- Verify an observable result after every mutation: version plus signature after CLI update, authenticated state after login, installed Editor path after install, reachable Pipeline instance before commands, and build/test outputs after automation.

## Route By Task

- For installation, self-update, version-source conflicts, signature verification, or migration between CDN and winget/MSIX, read [references/update-and-verification.md](references/update-and-verification.md).
- For Clash Verge, Proxifier, global-vs-China redirects, browser isolation, OAuth, Google sign-in, or callback failures, read [references/windows-routing-and-auth.md](references/windows-routing-and-auth.md).
- For Editor installation, project setup, Pipeline, `unity command`, MCP, builds, or tests, read [references/editor-automation.md](references/editor-automation.md).

Run the read-only diagnostic first when the cause is unclear:

```powershell
& "$env:USERPROFILE\.codex\skills\unity-cli-operator\scripts\Test-UnityCliEnvironment.ps1" |
  ConvertTo-Json -Depth 6
```

Pass an explicit proxy only when needed:

```powershell
& "$env:USERPROFILE\.codex\skills\unity-cli-operator\scripts\Test-UnityCliEnvironment.ps1" `
  -ProxyUrl 'http://127.0.0.1:7897' |
  ConvertTo-Json -Depth 6
```

## Execution Discipline

1. Inspect first. Prefer `Get-Command unity -All`, `unity --version`, `unity diagnose update`, `unity diagnose proxy`, `unity status`, and structured `--format json` output.
2. Explain the intended mutation before changing installations, persistent proxy settings, Proxifier profiles, browser cookies, credentials, Editors, project packages, or project files.
3. Use an explicit per-command `--proxy` while diagnosing. Persist with `unity config proxy` only when the user wants a lasting setting. Do not add a Proxifier rule for `unity.exe` when the native proxy works.
4. If OAuth is required, start one login attempt, keep its CLI process alive, and use only its fresh URL in one isolated browser context. Hand passwords, CAPTCHA, 2FA, recovery, and account-choice steps to the user.
5. Prefer project-scoped and process-scoped changes. Avoid system-wide proxy or security changes unless explicitly requested.
6. Stop retries after two fresh OAuth attempts or two identical update/download failures. Diagnose routing, stale metadata, or user interaction instead of generating more state.
7. Report the final command path, full CLI-reported version, install method, proxy mechanism used (`--proxy`, environment, browser flag, or optional Proxifier), authentication state without identity details, Editor/Pipeline state, and any unresolved regional-source inconsistency.
