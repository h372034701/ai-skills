# AssetRipper Export And Spine Grouping

## Preserve The Source

Keep three locations distinct:

1. the installed game, treated as read-only;
2. the complete AssetRipper `ExportedProject`, retained for provenance and missing-reference investigation;
3. the curated Spine groups, which are safe to copy into another Unity project.

Do not replace the complete export with the curated groups. AssetRipper may report unresolved `CAB-*` dependencies or individual object read errors while still exporting valid Spine reference chains; assess completeness at the group level.

## Export Inspection

Before running AssetRipper, record:

- Unity version from the player metadata;
- Mono versus IL2CPP;
- locations of the main executable, `*_Data`, `GameAssembly.dll`, and `global-metadata.dat` when present;
- AssetRipper version and output location.

Use an AssetRipper version that supports the detected Unity player version. Load the whole game directory so serialized files, bundles, streaming assets, and IL2CPP metadata can be resolved together.

## Reference Chain

The collector follows AssetRipper-exported Unity GUID references:

```text
SkeletonDataAsset YAML
  -> skeletonJSON TextAsset
  -> atlasAssets[] YAML
     -> atlasFile TextAsset
     -> materials[]
        -> _MainTex Texture2D
```

Atlas page names are also checked against textures as a fallback. Each output group contains source provenance and warnings in `manifest.json`.

## Collector Usage

Run with Python 3.10 or newer:

```powershell
python <skill-dir>/scripts/collect_spine_groups.py `
  --project "D:\exports\Game\ExportedProject" `
  --output "D:\exports\Game\SpineGroups"
```

Add `--strict` when warnings must cause a nonzero exit code. The script refuses to overwrite a non-empty output directory.

Expected output:

```text
SpineGroups/
  index.json
  groups/
    example_SkeletonData/
      example.skel
      example.atlas
      example.png
      manifest.json
```

Numbered AssetRipper filenames are canonicalized where possible:

- `hero.skel_0.bytes` becomes `hero_0.skel`;
- `hero.atlas_0.txt` becomes `hero_0.atlas`.

This gives Spine Unity standard `.skel.bytes` and `.atlas.txt` names after the preparation step. The Unity helper still supports legacy collected groups that retain the unusual names.

## Validation

For each group, verify:

- every atlas page listed in atlas text exists in the group;
- skeleton and atlas files are nonempty;
- `manifest.json` source paths resolve in the retained AssetRipper export;
- page count and material count differences are explained;
- duplicate destination filenames contain identical bytes or are treated as collisions;
- no unsafe absolute or parent-relative atlas page path is copied.

Do not count `.meta`, generated `.mat`, or Unity wrapper `.asset` files as recovered source files.
