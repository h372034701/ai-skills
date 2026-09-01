---
name: unity-il2cpp-recovery
description: Recover usable managed DLLs from authorized Windows Unity IL2CPP builds, including Unity 6 and nonstandard metadata layouts. Use when GameAssembly.dll and global-metadata.dat need Cpp2IL IL recovery, not ordinary .NET decompilation.
---

# Unity Il2cpp Recovery

Recover readable managed assemblies from an authorized Windows Unity IL2CPP application. Preserve the original game/program files and write only to a distinct output directory.

## Identify The Input

Confirm all of the following before running Cpp2IL:

- The directory contains `GameAssembly.dll` and `global-metadata.dat`, either in the usual `*_Data\\il2cpp_data\\Metadata` location or another extracted location.
- Read the metadata magic/version from bytes 0-7. The expected magic is `0xFAB11BAF`.
- Determine the Unity version from `UnityPlayer.dll` or the game executable file version. Use the full value such as `2022.3.62f3c1` or `6000.3.5f2`.
- Choose a new, empty output directory. Do not reuse or clear an existing output directory unless the user explicitly asks.

Treat method-body recovery as distinct from metadata dumping. `dll_il_recovery` is the required output format. `--output-format` is not a valid replacement.

## Use A Recovery-Capable Build

Prefer the `development` branch of [66hh/Cpp2IL](https://github.com/66hh/Cpp2IL). It includes functional `dll_il_recovery` and has been verified against Unity 2022 metadata v31 and Unity 6 metadata v39.

Do not rely on `Cpp2IL-2022.1.0-pre-release.21` for recovered IL: it can parse v39 metadata but its `dll_il_recovery` output may still contain only `ldnull; throw` bodies.

When a suitable local build is unavailable, clone the fork into the task's working directory and publish it for Windows x64:

```powershell
git clone --depth 1 --branch development https://github.com/66hh/Cpp2IL.git <work-dir>\\Cpp2IL-66hh
dotnet publish <work-dir>\\Cpp2IL-66hh\\Cpp2IL\\Cpp2IL.csproj `
  --configuration Release --framework net10.0 --runtime win-x64 --self-contained true `
  --output <work-dir>\\Cpp2IL-66hh\\artifacts\\Cpp2IL-net10-selfcontained
```

Use `--self-contained true`; this project enables trimming and a framework-dependent `dotnet publish` can fail at the linker stage.

## Run The Recovery

For a standard Windows Unity game layout, use the game root:

```powershell
<Cpp2IL.exe> --game-path="<game-root>" `
  --output-as=dll_il_recovery `
  --output-to="<new-output-directory>"
```

For an extracted or nonstandard layout, force all three paths/version values together. The CLI rejects partial force configuration:

```powershell
<Cpp2IL.exe> `
  --force-binary-path="<path-to-GameAssembly.dll>" `
  --force-metadata-path="<path-to-global-metadata.dat>" `
  --force-unity-version="<full-unity-version>" `
  --output-as=dll_il_recovery `
  --output-to="<new-output-directory>"
```

Use `--verbose` only when diagnosis is needed. Capture the reported metadata version, Unity version, code registration, metadata registration, completed-method count, and any skipped methods.

## Verify The Result

Cpp2IL reporting completion is not enough. Scan all output DLLs with [scripts/Test-IlRecovery.ps1](scripts/Test-IlRecovery.ps1):

```powershell
pwsh -NoProfile -File <skill-dir>\\scripts\\Test-IlRecovery.ps1 `
  -OutputDirectory "<new-output-directory>"
```

The `LdnullThrow` total must be zero for a successful IL-recovery result. `NoBody` can be nonzero because abstract, external, internal-call, or otherwise bodyless methods are expected in Unity assemblies. Report skipped methods separately; a small number of complex control-flow failures does not invalidate the rest of the output.

Open key game-specific DLLs (for example `Assembly-CSharp.dll` and publisher namespaces) in ILSpy/dnSpy to inspect representative methods. State clearly that recovered CIL is an approximation of compiled native code, not the original C# source.
