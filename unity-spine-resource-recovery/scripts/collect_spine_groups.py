from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path


GUID_PATTERN = re.compile(r"^guid:\s*([0-9a-f]{32})\s*$", re.MULTILINE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect Spine skeleton, atlas, and texture groups from an AssetRipper ExportedProject."
    )
    parser.add_argument("--project", required=True, type=Path, help="AssetRipper ExportedProject directory")
    parser.add_argument("--output", required=True, type=Path, help="New or empty output directory")
    parser.add_argument("--strict", action="store_true", help="Return a nonzero exit code if any group has warnings")
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def relative_to_project(path: Path, project_root: Path) -> str:
    return path.relative_to(project_root).as_posix()


def make_guid_index(assets_root: Path) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for meta_path in assets_root.rglob("*.meta"):
        match = GUID_PATTERN.search(read_text(meta_path))
        if match:
            result[match.group(1)] = meta_path.with_suffix("")
    return result


def get_name(yaml: str, fallback: str) -> str:
    match = re.search(r"^  m_Name:\s*(.+)$", yaml, re.MULTILINE)
    return match.group(1).strip() if match else fallback


def get_scalar_guid(yaml: str, field: str) -> str | None:
    match = re.search(
        rf"^\s*{re.escape(field)}:\s*\{{[^}}]*\bguid:\s*([0-9a-f]{{32}})",
        yaml,
        re.MULTILINE,
    )
    return match.group(1) if match else None


def get_list_guids(yaml: str, field: str) -> list[str]:
    match = re.search(
        rf"(?ms)^  {re.escape(field)}:\s*\n(.*?)(?=^  [A-Za-z_][^:\n]*:|\Z)",
        yaml,
    )
    return re.findall(r"\bguid:\s*([0-9a-f]{32})", match.group(1)) if match else []


def atlas_page_names(atlas_text: str) -> list[str]:
    lines = atlas_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    pages: list[str] = []
    for index, line in enumerate(lines[:-1]):
        if line and not line.startswith((" ", "\t")) and lines[index + 1].lstrip().startswith("size:"):
            pages.append(line)
    return pages


def normalize_skeleton_name(path: Path) -> str:
    if path.suffix.lower() == ".json":
        return path.name
    match = re.match(r"^(.*)\.skel(?:_(\d+))?\.bytes$", path.name, re.IGNORECASE)
    if match:
        index = f"_{match.group(2)}" if match.group(2) else ""
        return f"{match.group(1)}{index}.skel"
    if path.name.lower().endswith(".skel"):
        return path.name
    return f"{path.stem}.skel"


def normalize_atlas_name(path: Path) -> str:
    match = re.match(r"^(.*)\.atlas(?:_(\d+))?\.txt$", path.name, re.IGNORECASE)
    if match:
        index = f"_{match.group(2)}" if match.group(2) else ""
        return f"{match.group(1)}{index}.atlas"
    if path.name.lower().endswith(".atlas"):
        return path.name
    return f"{path.stem}.atlas"


def safe_output_relative_path(value: str) -> Path | None:
    candidate = Path(value.replace("\\", "/"))
    if candidate.is_absolute() or ".." in candidate.parts:
        return None
    return candidate


def copy_asset(source: Path, destination: Path, warnings: list[str]) -> bool:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if destination.read_bytes() != source.read_bytes():
            warnings.append(f"destination collision: {destination}")
            return False
        return True
    shutil.copy2(source, destination)
    return True


def optional_float(yaml: str, field: str) -> float | None:
    match = re.search(rf"^  {re.escape(field)}:\s*([-+]?\d+(?:\.\d+)?)\s*$", yaml, re.MULTILINE)
    return float(match.group(1)) if match else None


def get_main_texture_guid(yaml: str) -> str | None:
    match = re.search(
        r"(?ms)^\s*_MainTex:\s*\n\s*m_Texture:\s*\{[^}]*\bguid:\s*([0-9a-f]{32})",
        yaml,
    )
    return match.group(1) if match else None


def unique_folder_name(name: str, used_names: set[str]) -> str:
    cleaned = re.sub(r'[<>:"/\\|?*]', "_", name).strip(". ") or "unnamed"
    candidate = cleaned
    suffix = 2
    while candidate.lower() in used_names:
        candidate = f"{cleaned}_{suffix}"
        suffix += 1
    used_names.add(candidate.lower())
    return candidate


def collect(project_root: Path, output_root: Path) -> tuple[int, int]:
    assets_root = project_root / "Assets"
    mono_behaviour_root = assets_root / "MonoBehaviour"
    if not assets_root.is_dir() or not mono_behaviour_root.is_dir():
        raise ValueError(f"AssetRipper export layout was not found under: {project_root}")
    if output_root.exists() and any(output_root.iterdir()):
        raise ValueError(f"Refusing to overwrite non-empty output directory: {output_root}")

    guid_index = make_guid_index(assets_root)
    texture_by_name: dict[str, list[Path]] = defaultdict(list)
    texture_root = assets_root / "Texture2D"
    if texture_root.is_dir():
        for texture_path in texture_root.rglob("*"):
            if texture_path.is_file() and texture_path.suffix.lower() in {".png", ".jpg", ".jpeg"}:
                texture_by_name[texture_path.name].append(texture_path)

    output_root.mkdir(parents=True, exist_ok=True)
    groups_root = output_root / "groups"
    groups_root.mkdir()
    index: list[dict[str, object]] = []
    used_names: set[str] = set()

    skeleton_assets = sorted(mono_behaviour_root.rglob("*SkeletonData*.asset"))
    for skeleton_asset in skeleton_assets:
        skeleton_yaml = read_text(skeleton_asset)
        skeleton_guid = get_scalar_guid(skeleton_yaml, "skeletonJSON")
        atlas_object_guids = get_list_guids(skeleton_yaml, "atlasAssets")
        if skeleton_guid is None and not atlas_object_guids:
            continue

        display_name = get_name(skeleton_yaml, skeleton_asset.stem)
        group_name = unique_folder_name(display_name, used_names)
        group_root = groups_root / group_name
        group_root.mkdir()
        warnings: list[str] = []
        manifest: dict[str, object] = {
            "group": group_name,
            "skeleton_data_asset": relative_to_project(skeleton_asset, project_root),
            "scale": optional_float(skeleton_yaml, "scale"),
            "default_mix": optional_float(skeleton_yaml, "defaultMix"),
            "skeleton": None,
            "atlases": [],
            "warnings": warnings,
        }

        skeleton_source = guid_index.get(skeleton_guid) if skeleton_guid else None
        if skeleton_source is None or not skeleton_source.is_file():
            warnings.append(f"missing skeleton TextAsset for GUID {skeleton_guid or '<none>'}")
        else:
            skeleton_destination = group_root / normalize_skeleton_name(skeleton_source)
            copy_asset(skeleton_source, skeleton_destination, warnings)
            manifest["skeleton"] = {
                "source": relative_to_project(skeleton_source, project_root),
                "file": skeleton_destination.relative_to(group_root).as_posix(),
            }

        atlas_entries: list[dict[str, object]] = []
        for atlas_number, atlas_object_guid in enumerate(atlas_object_guids):
            atlas_object = guid_index.get(atlas_object_guid)
            atlas_entry: dict[str, object] = {
                "atlas_asset": relative_to_project(atlas_object, project_root) if atlas_object else None,
                "atlas": None,
                "pages": [],
            }
            atlas_entries.append(atlas_entry)
            if atlas_object is None or not atlas_object.is_file():
                warnings.append(f"missing Atlas asset for GUID {atlas_object_guid}")
                continue

            atlas_yaml = read_text(atlas_object)
            atlas_text_guid = get_scalar_guid(atlas_yaml, "atlasFile")
            material_guids = get_list_guids(atlas_yaml, "materials")
            if atlas_text_guid is None:
                warnings.append(f"{atlas_object.name}: atlasFile GUID is missing")
                continue

            atlas_text = guid_index.get(atlas_text_guid)
            if atlas_text is None or not atlas_text.is_file():
                warnings.append(f"{atlas_object.name}: missing atlas TextAsset for GUID {atlas_text_guid}")
                continue

            atlas_destination = group_root / normalize_atlas_name(atlas_text)
            copy_asset(atlas_text, atlas_destination, warnings)
            atlas_entry["atlas"] = {
                "source": relative_to_project(atlas_text, project_root),
                "file": atlas_destination.relative_to(group_root).as_posix(),
                "atlas_object_index": atlas_number,
            }

            pages = atlas_page_names(read_text(atlas_text))
            if len(pages) != len(material_guids):
                warnings.append(
                    f"{atlas_object.name}: {len(pages)} atlas page(s) but {len(material_guids)} material(s)"
                )

            for page_index, page_name in enumerate(pages):
                page_entry: dict[str, object] = {"name": page_name, "texture": None}
                atlas_entry["pages"].append(page_entry)
                page_relative_path = safe_output_relative_path(page_name)
                if page_relative_path is None:
                    warnings.append(f"{atlas_object.name}: unsafe atlas page path '{page_name}'")
                    continue

                texture_source: Path | None = None
                material_source: Path | None = None
                if page_index < len(material_guids):
                    material_source = guid_index.get(material_guids[page_index])
                    if material_source and material_source.is_file():
                        texture_guid = get_main_texture_guid(read_text(material_source))
                        if texture_guid:
                            texture_source = guid_index.get(texture_guid)
                    else:
                        warnings.append(f"{atlas_object.name}: missing material for atlas page '{page_name}'")

                if texture_source is None:
                    candidates = texture_by_name.get(page_relative_path.name, [])
                    if len(candidates) == 1:
                        texture_source = candidates[0]
                    elif len(candidates) > 1:
                        warnings.append(f"{atlas_object.name}: ambiguous texture fallback for '{page_name}'")
                    else:
                        warnings.append(f"{atlas_object.name}: texture not found for atlas page '{page_name}'")

                if texture_source and texture_source.is_file():
                    texture_destination = group_root / page_relative_path
                    if copy_asset(texture_source, texture_destination, warnings):
                        page_entry["texture"] = {
                            "source": relative_to_project(texture_source, project_root),
                            "file": texture_destination.relative_to(group_root).as_posix(),
                            "material": relative_to_project(material_source, project_root)
                            if material_source and material_source.is_file()
                            else None,
                        }

        manifest["atlases"] = atlas_entries
        manifest_path = group_root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        index.append(
            {
                "group": group_name,
                "path": group_root.relative_to(output_root).as_posix(),
                "skeleton_data_asset": relative_to_project(skeleton_asset, project_root),
                "warnings": warnings,
            }
        )

    index_path = output_root / "index.json"
    index_path.write_text(json.dumps({"groups": index}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    warning_groups = sum(1 for group in index if group["warnings"])
    return len(index), warning_groups


def main() -> int:
    args = parse_args()
    project_root = args.project.resolve()
    output_root = args.output.resolve()
    try:
        group_count, warning_group_count = collect(project_root, output_root)
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1

    print(
        f"Created {group_count} Spine groups "
        f"({group_count - warning_group_count} without warnings) at {output_root}"
    )
    if group_count == 0:
        return 2
    if args.strict and warning_group_count:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
