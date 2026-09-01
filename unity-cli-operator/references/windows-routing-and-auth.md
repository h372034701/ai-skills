# Windows Routing And Authentication

Use this reference when Unity CLI traffic is redirected to China endpoints, the browser loops, third-party login times out, or Editor package downloads bypass the working proxy.

## Routing Priority

Use the narrowest native mechanism available:

1. Unity CLI: per-command `--proxy`; use `UNITY_PROXY` or `unity config proxy` only when persistence is useful.
2. Isolated browser: `--proxy-server` plus a dedicated `--user-data-dir` and incognito/InPrivate mode.
3. Unity Editor and Package Manager: process-scoped `HTTP_PROXY` and `HTTPS_PROXY` when launching the Editor.
4. Proxifier: optional fallback only for a process that cannot use one of the mechanisms above, or for diagnosing an application that ignores its proxy settings.

Unity CLI does not require Proxifier. Do not create or enable a `unity.exe` Proxifier rule merely because Proxifier is installed.

## Model The Full Route

Treat these as separate clients:

- `unity.exe`: release feeds, auth initiation, cloud APIs, Editor downloads
- `Unity Hub.exe`: Hub-owned requests and optional CLI deployment
- `Unity.exe`: Package Manager and Editor services
- `chrome.exe` or `msedge.exe`: Unity login and third-party identity-provider pages
- `verge-mihomo.exe`: Clash Verge proxy core
- localhost callback and Pipeline service: local traffic that must remain direct

The usual stable topology is:

```text
Unity CLI / isolated browser / Unity Editor
                  |
     native proxy or optional Proxifier rule
                  |
        Clash Verge mixed port
                  |
           selected egress node

localhost OAuth callback and 127.0.0.1:7800 Pipeline -> DIRECT
Clash Verge and its proxy-core processes -> DIRECT to prevent loops
```

## Discover Clash Verge Instead Of Hardcoding It

This machine has previously used `127.0.0.1:7897`, but always verify it:

```powershell
Get-Process clash-verge, verge-mihomo -ErrorAction SilentlyContinue |
  Select-Object ProcessName, Id, Path

Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object LocalPort -in 7890, 7891, 7897 |
  Select-Object LocalAddress, LocalPort, OwningProcess
```

Read Clash configuration only as needed. Do not print subscription URLs, controller secrets, provider tokens, or the complete YAML. Prefer the UI's displayed mixed-port or the listening socket.

Test the local socket and representative destinations through the explicit proxy before touching Proxifier:

```powershell
$proxyUrl = 'http://127.0.0.1:<detected-port>'
Test-NetConnection 127.0.0.1 -Port <detected-port>

Invoke-WebRequest 'https://id.unity.com/' -Proxy $proxyUrl `
  -UseBasicParsing -TimeoutSec 20 | Select-Object StatusCode

Invoke-WebRequest 'https://accounts.google.com/' -Proxy $proxyUrl `
  -UseBasicParsing -TimeoutSec 20 | Select-Object StatusCode
```

An HTTP redirect is acceptable if it stays on the expected global login flow. Inspect the final host; do not treat every 3xx as failure.

## Prefer Explicit CLI Proxy During Diagnosis

```powershell
$proxyUrl = 'http://127.0.0.1:<detected-port>'

unity --proxy $proxyUrl diagnose proxy
unity --proxy $proxyUrl releases --limit 3 --format json
unity --proxy $proxyUrl auth status --format json
```

Persist only when the user wants this route for future CLI invocations:

```powershell
unity config proxy $proxyUrl
unity diagnose proxy
```

Remove it with `unity config proxy --unset`. Do not overwrite a credentialed proxy configuration merely because a local unauthenticated proxy also works.

## Optional Proxifier Profile Rules

Skip this section when Unity CLI, the isolated browser, and the Editor are all working through their native proxy mechanisms.

The conventional profile location is `%APPDATA%\Proxifier4\Profiles`; this machine has used `unity.ppx`. Inspect it through an XML parser and select only safe fields such as proxy address, port, rule name, applications, targets, and action. Never dump authentication nodes.

Rule order and intent should be:

1. `clash-verge.exe` and `verge-mihomo.exe`: direct, to prevent proxy recursion.
2. `localhost`, `127.0.0.1`, and the computer name: direct, before proxy rules.
3. Unity domains for processes without native proxy support: route through the Clash mixed port. Cover the actual flow, normally `*.unity.com`, `*.unity3d.com`, and any observed Unity China redirect host so that a redirect cannot leak to direct routing.
4. The actual identity-provider domains used by the user. For Google this commonly includes `accounts.google.com`, relevant `*.google.com`, `*.gstatic.com`, and `*.googleusercontent.com` requests.
5. The actual browser executable (`chrome.exe` or `msedge.exe`) when process routing is intentionally desired.
6. Unity Hub or Editor process rules only when those processes need the route and process-scoped proxy variables are insufficient.

Do not trust a rule name. Verify the rule's `Applications`, `Targets`, `Action`, and position. A rule named `msedge.exe` can still contain only `chrome.exe` or use the wrong action.

Prefer a narrow domain rule or an isolated browser with `--proxy-server` over proxying every normal browser window. Broad process rules can affect unrelated signed-in sessions. Avoid double-routing `unity.exe` through both `--proxy` and a Proxifier application rule.

## Prevent Global-To-China Redirects

Repeated redirects to `unity.cn` or a China identity endpoint can come from inconsistent egress IPs, direct DNS, cookies/local storage, an old OAuth state, or different routing between CLI and browser.

Use this sequence:

1. Confirm the CLI and browser reach the global Unity endpoints through the same Clash node.
2. Keep all login redirects and the chosen identity provider on that same route.
3. Keep `localhost` direct.
4. Cancel the old CLI login attempt and generate one fresh OAuth URL.
5. Complete the flow only in a new InPrivate/incognito window with a unique user-data directory and explicit proxy.
6. If the CLI automatically opens the normal browser, close or ignore that tab before interacting; use the current printed URL in the isolated window. Do not reuse a URL from an earlier CLI attempt.
7. If the isolated profile still redirects, verify the proxy egress region and DNS behavior. Do not keep clearing the user's normal browser data.
8. Stop if Unity explicitly reports a legal, account, organization, or service-availability restriction; networking tools must not be used to evade such controls.

## Isolated Browser Login

Keep `unity --proxy <proxy-url> auth login` running while the browser completes the flow. The URL contains short-lived OAuth state and PKCE data. Do not echo it into chat, save it to a script, or put it in documentation.

Edge example:

```powershell
$edgePath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$profilePath = Join-Path $env:TEMP ('unity-auth-edge-' + [guid]::NewGuid().ToString('N'))
$proxyUrl = 'http://127.0.0.1:<detected-port>'

New-Item -ItemType Directory -Path $profilePath | Out-Null

Start-Process -FilePath $edgePath -ArgumentList @(
  "--user-data-dir=$profilePath"
  "--proxy-server=$proxyUrl"
  '--no-first-run'
  '--inprivate'
  '<fresh URL printed by the live unity auth login process>'
)
```

Chrome uses `--incognito` instead of `--inprivate`. A unique `--user-data-dir` prevents the new command from being handed to an already-running browser process that ignores the new proxy flag and prevents cookies from an earlier attempt from carrying over. Do not delete an existing browser profile. Use a newly created task-specific temporary directory.

If the automation environment cannot attach to an incognito window, leave the isolated window visible and hand control to the user. Do not silently fall back to the normal browser profile when stale cookies or region state are part of the failure.

The user must handle passwords, account selection involving private identity data, CAPTCHA, 2FA, recovery codes, and final security prompts. The AI may resume after the callback completes.

## OAuth Failure Meanings

- `ERR_TOO_MANY_REDIRECTS`: stale cookies, mismatched OAuth state, reused link, or inconsistent route. Start a fresh CLI attempt and isolated profile.
- Google or another identity provider times out: the provider or browser process is still direct. Expand only the required route.
- CLI waits forever after browser success: localhost was proxied or blocked, the CLI attempt expired, or the browser used an old URL.
- CLI exits before browser completion: rerun login and use the new URL; never reuse the previous one.
- `unity auth status` exits `3`: unauthenticated or expired session, not a CLI installation failure.

After success, verify without printing identity details:

```powershell
$authJson = unity --proxy $proxyUrl --format json auth status | ConvertFrom-Json
[pscustomobject]@{
  Success = $authJson.success
  LoggedIn = $authJson.data.loggedIn
  SessionState = $authJson.data.sessionState
}
```
