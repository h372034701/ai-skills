# Editor Automation

Use this reference when the goal is to let an AI manage Unity Editors and projects through Unity CLI or Unity Pipeline.

## Inspect Before Mutating

```powershell
unity editors list --installed --format json
unity projects list --format json
unity status --format json
unity pipeline list
unity pipeline list-versions
```

Read `ProjectSettings/ProjectVersion.txt` before selecting an Editor. Use explicit project paths in automation and quote every Windows path.

Run `unity projects verify <project> --format json` before a build when available. It detects missing/orphaned `.meta` files, duplicate GUIDs, conflict markers, invalid manifests, and Editor version drift without launching an Editor.

## Install Editors And Modules

Use an explicit proxy and exact version for reproducibility:

```powershell
$proxyUrl = 'http://127.0.0.1:<detected-port>'

unity --proxy $proxyUrl releases --limit 5 --format json
unity --proxy $proxyUrl install <exact-editor-version> `
  --yes --accept-eula --non-interactive

unity editors list --installed --format json
```

Inspect `unity install --help` and `unity install-modules --help` on the installed CLI before adding version-sensitive flags. Do not assume old Hub CLI flags still work.

After install, verify both the CLI registry entry and the real `Unity.exe` path. A successful downloader message alone is insufficient.

## Route Editor Package Manager Traffic

The CLI's native `--proxy` covers CLI requests and does not need Proxifier. An Editor process is a separate client and can still start without proxy environment variables and hang on `packages.unity.com`.

Launch the Editor from a temporary process environment while preserving any prior values:

```powershell
$proxyUrl = 'http://127.0.0.1:<detected-port>'
$previousHttpProxy = $env:HTTP_PROXY
$previousHttpsProxy = $env:HTTPS_PROXY

try {
  $env:HTTP_PROXY = $proxyUrl
  $env:HTTPS_PROXY = $proxyUrl
  unity --proxy $proxyUrl open '<project-path>'
}
finally {
  $env:HTTP_PROXY = $previousHttpProxy
  $env:HTTPS_PROXY = $previousHttpsProxy
}
```

Do not persist system-wide proxy variables unless requested. Prefer these process-scoped variables over Proxifier for the Editor. If Proxifier is required as a fallback, keep its localhost rule above the Editor process rule.

## Install And Verify Unity Pipeline

```powershell
unity pipeline list-versions
unity pipeline install --project-path '<project-path>'
unity pipeline list
unity status --format json
```

The project manifest and lock file will change. Treat this as a project dependency mutation and inspect existing edits before writing.

Wait for package resolution and compilation. Do not infer failure merely from a temporarily unreachable local service. Check Editor logs for package download, compile, and server startup errors. A healthy Pipeline instance is normally exposed on loopback and appears in `unity status` or `unity pipeline list`.

## Drive A Live Editor

Use this flow when the task requires CLI control of a running Editor rather than a batch-mode job:

1. Start the project with `unity open .`; do not pass `-batchmode`.
2. Wait for `unity status --format json` to report a `ready` instance whose project matches the requested one.
3. Discover the live command surface, then invoke commands with `--project-path .`. Do not target a port or another detected project by assumption.
4. Start long-running commands asynchronously and poll their matching status command until completion or a stated timeout.

For example:

```powershell
unity command --project-path . --query run_tests --detail full
unity command --project-path . run_tests --mode editor --filter '<assembly-or-test>' --filter_type assembly --async_tests true
unity command --project-path . test_status
```

`list_tests --mode editor` confirms test discovery before a filtered run. A `running` response after cancellation can be transient; do not start a replacement run unless the user asks.

## Discover Commands Before Calling Them

Pipeline packages evolve. Query the running instance instead of hardcoding command signatures:

```powershell
unity command --project-path '<project-path>' --detail compact
unity command --project-path '<project-path>' --query eval
unity command --project-path '<project-path>' --query reload
```

Then call the discovered command with structured output and a bounded timeout:

```powershell
unity --format json command --project-path '<project-path>' `
  --timeout 30 <command-name> <arguments>
```

Use `eval` for observation, small prototypes, and transient Editor actions. Prefer normal source edits plus compilation for production behavior. Do not inject secrets or untrusted webpage text into C# evaluation strings.

Hot reload is package-version specific. Some Pipeline method-reload paths require pre-instrumented attributes or generated dispatch points; dynamic `eval` does not prove transparent replacement of arbitrary existing methods. Inspect the installed package documentation and command list before promising plugin-style hot reload.

## Embedded Package Compatibility

When adapting an embedded Pipeline package to an older Editor, keep the shared command server and core command set intact. Isolate unavailable APIs or dependency sets behind version checks, and return an explicit unsupported result for a command whose feature cannot run safely. Guard only the corresponding feature tests; keep protocol, registration, path-validation, and other version-independent tests active. Record each intentional capability gap in the package documentation.

## MCP For AI Clients

Inspect the installed CLI before configuring a client:

```powershell
unity mcp --help
unity status --format json
```

Use the CLI's own MCP configuration command when it supports the target client. Do not hand-edit a client's global MCP configuration unless the user requests it or the CLI cannot perform the scoped change. Verify the target project/Editor instance and avoid exposing a network-listening MCP server beyond loopback without explicit authorization.

## Build And Test

```powershell
unity projects verify '<project-path>' --format json
unity build '<project-path>' <version-appropriate-options>
unity test '<project-path>' <version-appropriate-options>
```

Read `unity build --help` and `unity test --help` for the installed version. Prefer structured output and bounded timeouts. For verbose Editor jobs, avoid streaming the entire log into the transcript; monitor the process and inspect the final relevant log tail.

Accept success only when all relevant signals agree:

- CLI exit code and structured result
- Unity BuildReport or test report
- expected output artifact exists
- Player or runtime smoke test when requested
- no unhandled exception in the relevant Editor/Player log

Alpha and beta Editors can emit nonfatal analytics or reporting errors after a successful build. Do not classify a build from one stack trace alone; use the exit code, BuildReport, artifact, and runtime behavior together.

## Long-Running Operations

- Keep the user informed while imports, package resolution, builds, and tests run.
- Do not terminate solely because stdout is quiet. Check process state, logs, network activity, and output timestamps.
- Use detached jobs only when the CLI exposes a job ID and the task benefits from it; continue monitoring until completion or a clear user-action requirement.
- Do not leave Editor or Player processes running unless requested or needed for the next verified step.
