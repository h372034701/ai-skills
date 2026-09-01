# Spine Runtime Selection And Unity Import

## Detect The Data Version

Inspect every skeleton source, not only one sample. Spine binary headers normally expose a version string such as `4.1.24`; JSON exports expose it in their skeleton metadata. Summarize versions by file count and retain the outliers.

Choose a Runtime compatible with the data's major/minor format. Validate with actual deserialization after import. A filename or Unity package version alone is not proof of compatibility.

## Git Package Pins

Do not write `#<editor-version>` unless that exact branch, tag, or commit exists in the remote repository. Verify refs first. Pin `spine-csharp` and `spine-unity` to the same full commit.

Known verified mapping for Spine Unity package `4.1.24`:

```text
97e3dd4134ff045d1bf7a2211f26be6486df289a
```

Unity Package Manager entries:

```json
"com.esotericsoftware.spine.spine-csharp": "https://github.com/EsotericSoftware/spine-runtimes.git?path=spine-csharp/src#97e3dd4134ff045d1bf7a2211f26be6486df289a",
"com.esotericsoftware.spine.spine-unity": "https://github.com/EsotericSoftware/spine-runtimes.git?path=spine-unity/Assets/Spine#97e3dd4134ff045d1bf7a2211f26be6486df289a"
```

This commit has been validated with `4.1.24` and `4.1.17` skeleton binaries. For other versions, establish the mapping from official repository/package history instead of extrapolating this commit.

## Source Naming

Spine Unity's automatic importer recognizes:

- `name.atlas.txt` for atlas text;
- `name.skel.bytes` for binary skeleton data;
- `name.json` for JSON skeleton data.

AssetRipper may produce `name.atlas_0.txt`, `name.skel_0.bytes`, or atlas and skeleton files with different basenames. Renaming alone is insufficient for every case. Use the supplied Unity Editor helper to build and validate wrapper assets from actual objects in each group directory.

## Wrapper Assets

The reusable inputs are `.skel` or `.json`, `.atlas`, and page images. `SkeletonDataAsset` and `SpineAtlasAsset` are Unity `ScriptableObject` wrappers that must reference scripts and assets imported into the target project.

Never copy AssetRipper-exported wrapper YAML into a different project as the final solution. Its GUIDs refer to the source export's scripts, materials, textures, and other assets and commonly become Missing Script or broken references.

## Editor Helper

Copy `assets/SpineGroupImportPreparation.cs` from the skill into `Assets/Editor`. Its default group root is `Assets/SpineGroups/groups`.

Run the preparation command first. It uses `AssetDatabase.MoveAsset`, preserving Unity `.meta` identity while appending standard extensions. Spine Unity will create atlas assets and materials for recognized sources.

Then run the build command. It creates or repairs `SkeletonDataAsset` wrappers from the actual skeleton `TextAsset` and every `SpineAtlasAsset` in the same group. It reads `scale` and `default_mix` from `manifest.json`, falling back to `0.01` and `0.2`.

Finally run validation. Success requires:

- at least one usable `SpineAtlasAsset` in every group;
- every group with a skeleton source to have exactly one correctly configured `SkeletonDataAsset`;
- `GetAtlas()` and `GetSkeletonData(true)` to return non-null;
- atlas-only groups to be reported separately rather than treated as missing skeleton failures.

Inspect Unity `Editor.log` when a delayed validation result is not visible in the Console. Do not declare success from file counts alone.
