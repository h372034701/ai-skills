---
name: unity-spine-resource-recovery
description: Recover Spine skeleton, atlas, texture, and Unity wrapper assets from Unity game builds or AssetRipper exports, then import and validate them in a Unity project with a compatible Spine Runtime. Use for AssetRipper/AssetStudio Spine extraction, .skel/.atlas recovery, Spine version matching, or missing SkeletonDataAsset and SpineAtlasAsset problems.
---

# Unity Spine Resource Recovery

Recover reusable Spine Runtime inputs and recreate Unity-native wrapper assets. Treat the game installation and the complete AssetRipper export as read-only source evidence.

## Select The Mode

- For a game installation, export it with AssetRipper first, then collect Spine groups.
- For an existing AssetRipper `ExportedProject`, start at group collection.
- For existing `.skel + .atlas + images` groups, start at Unity import.
- For diagnosis or explanation, inspect and report without changing packages, files, or Unity assets.

Read [references/asset-ripper-and-grouping.md](references/asset-ripper-and-grouping.md) before exporting or collecting groups. Read [references/spine-runtime-and-unity-import.md](references/spine-runtime-and-unity-import.md) before changing a Unity project or selecting a Spine Runtime revision.

## Required Outcomes

1. Preserve the complete AssetRipper export separately from the curated groups.
2. Build one group directory per recovered `SkeletonDataAsset` YAML reference chain. Include the skeleton source when present, every atlas text, all referenced page images, and `manifest.json`.
3. Report skeleton format versions and counts before selecting the Runtime.
4. Pin `spine-csharp` and `spine-unity` to the same verified repository commit. Never assume a Spine package version is also a Git tag.
5. Recreate `SpineAtlasAsset` and `SkeletonDataAsset` inside the target Unity project. Do not copy AssetRipper's original wrapper YAML into another project because its script, material, and texture GUIDs belong to the source export.
6. Validate actual Unity object types and deserialization, not inferred filenames.

## Collection

Use the deterministic collector when the AssetRipper layout contains `Assets/MonoBehaviour`, `TextAsset`, `Material`, and `Texture2D`:

```powershell
python <skill-dir>/scripts/collect_spine_groups.py --project <ExportedProject> --output <new-output-directory>
```

The collector refuses a non-empty output directory. Review `index.json` and every group's `warnings` before moving groups into a Unity project. Do not claim completeness while warnings remain unexplained.

## Unity Import

Place the curated directory at `Assets/SpineGroups/groups` unless the user chose another location. If the destination already exists, inspect it and obtain clear scope before overwriting or merging.

Copy [assets/SpineGroupImportPreparation.cs](assets/SpineGroupImportPreparation.cs) into the target project's `Assets/Editor`. Change `GroupRootAssetPath` if the group root differs. After Unity compiles and the matching Spine packages load, run:

1. `Tools > Spine > Prepare Exported Spine Groups`
2. `Tools > Spine > Build Missing SkeletonData Assets`
3. `Tools > Spine > Validate Exported Spine Groups`

The build step handles AssetRipper names such as `name.skel_0.bytes` and skeleton/atlas basenames that do not match. It also repairs wrapper references and uses `scale` and `default_mix` from each manifest when available.

## Completion Report

Report these separately:

- recovered group count;
- usable `SpineAtlasAsset` count and groups containing one or more atlases;
- skeleton source count and usable `SkeletonDataAsset` count;
- atlas-only groups with no skeleton source;
- unresolved warnings or failed deserializations;
- target paths and pinned Runtime commit.

An atlas-only group is not a failed `SkeletonDataAsset` import. Do not invent or synthesize missing skeleton data.
