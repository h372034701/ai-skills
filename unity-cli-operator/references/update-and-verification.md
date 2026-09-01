# Update And Verification

Use this reference for standalone Unity CLI installation and update work on Windows.

## Establish Ownership And Version

```powershell
Get-Command unity -All -ErrorAction SilentlyContinue |
  Select-Object CommandType, Source, Version

unity --version
unity diagnose update
winget list --id Unity.CLI --exact --accept-source-agreements
winget show --id Unity.CLI --exact --accept-source-agreements --versions
```

Use `unity --version` as the authoritative prerelease version. Windows file metadata can report only `1.0.0.0`, and winget/MSIX encodes prereleases in a four-part version such as `1.0.0.20006` for `1.0.0-beta.6`.

`winget list` returning no package does not mean Unity CLI is absent. The official script/CDN install normally lives at `%LOCALAPPDATA%\Unity\bin\unity.exe` and is not necessarily registered with winget.

## Choose The Update Path

1. For a winget/MSIX-owned install, use:

   ```powershell
   winget upgrade --id Unity.CLI --exact `
     --accept-source-agreements --accept-package-agreements
   ```

2. For a standalone CDN install, first use:

   ```powershell
   unity upgrade --dry-run --format json
   unity upgrade --yes
   ```

3. When a specific official release is known but the channel manifest is stale:

   ```powershell
   unity upgrade --target <exact-version> --yes
   ```

4. For a clean install when winget is available:

   ```powershell
   winget install --id Unity.CLI --exact `
     --accept-source-agreements --accept-package-agreements
   ```

5. Otherwise use Unity's official installer script, after inspecting the URL and channel:

   ```powershell
   $env:UNITY_CLI_CHANNEL = 'beta'
   Invoke-RestMethod 'https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.ps1' |
     Invoke-Expression
   ```

Do not run the install script blindly when replacing a working install during a source inconsistency. Determine the exact target first.

## Handle Regional Metadata Drift

The following can disagree during a rollout:

- Unity CLI release notes
- `winget show Unity.CLI`
- `unity upgrade --check --format json`
- `https://public-cdn.cloud.unity3d.com/hub/prod/cli/latest-beta.json`
- an exact-version binary that already exists on the official CDN

Treat an older `latestVersion` than `currentVersion` as stale metadata, not as a downgrade instruction. Never downgrade automatically.

Cross-check the official Unity release notes and the exact `winget show` package metadata. If they identify a newer exact prerelease, prefer the package-manager install or exact target. Do not infer a download URL from an Editor changeset or unrelated Hub conventions.

An older self-updater may fail on an official exact-version URL with HTTP 307. A permitted fallback is:

1. Use only the exact URL shown by Unity's own updater, official release announcement, or winget manifest.
2. Download to a temporary path without replacing the installed binary.
3. Verify Authenticode status is `Valid` and signer contains `Unity Technologies`.
4. Run the candidate with `--version`; require an exact target match.
5. Compute and record SHA-256. Compare with an official hash when one is published for that exact artifact.
6. Back up the current executable to a recoverable location.
7. Replace it, then repeat path, version, hash, signature, and command smoke tests.
8. Restore the backup immediately if any verification fails.

Do not use this fallback for an unpublished or guessed version.

## Post-Update Verification

```powershell
$unityPath = (Get-Command unity -CommandType Application).Source

unity --version
unity diagnose update

Get-AuthenticodeSignature -LiteralPath $unityPath |
  Select-Object Status,
    @{Name='Signer';Expression={$_.SignerCertificate.Subject}}

Get-FileHash -LiteralPath $unityPath -Algorithm SHA256
unity --help
```

Check `Get-Command unity -All` for shadow copies after installing MSIX alongside a CDN binary. Do not claim the new package is active until the command path resolves to the intended executable.

Check authentication separately. An update can succeed while `unity auth status` exits `3` because the prior session expired or is absent. Do not conflate authentication with binary health, and do not print account identity data when a boolean status is enough.

Useful official sources:

- `https://docs.unity.com/en-us/unity-cli/release-notes`
- `https://docs.unity.com/en-us/unity-cli/use-unity-cli`
- `https://public-cdn.cloud.unity3d.com/hub/prod/cli/`
