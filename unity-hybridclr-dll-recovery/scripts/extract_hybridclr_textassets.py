#!/usr/bin/env python3
"""Extract binary TextAssets from YooAsset caches/Unity bundles without text re-encoding."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys


BUNDLE_SUFFIXES = {".bundle", ".unity3d", ".ab"}
RESERVED_NAMES = {"CON", "PRN", "AUX", "NUL"} | {
    f"{prefix}{number}" for prefix in ("COM", "LPT") for number in range(1, 10)
}


def parse_textasset(raw: bytes, endian: str = "<") -> tuple[str, bytes]:
    """Read aligned name + byte-array fields from a standard serialized TextAsset.

    Decode only the object name. Script bytes are returned verbatim, including
    invalid UTF-8 and NUL bytes. Custom serialized layouts must be handled separately.
    """
    if endian not in ("<", ">"):
        raise ValueError(f"Unsupported serialized-file endianness: {endian!r}")
    if len(raw) < 4:
        raise ValueError("Truncated TextAsset name length")
    name_length = struct.unpack_from(endian + "I", raw, 0)[0]
    name_end = 4 + name_length
    if name_end > len(raw):
        raise ValueError(f"Name length {name_length} exceeds object size {len(raw)}")
    script_length_offset = (name_end + 3) & ~3
    if script_length_offset + 4 > len(raw):
        raise ValueError("Truncated name alignment padding or script length")
    script_length = struct.unpack_from(endian + "I", raw, script_length_offset)[0]
    script_start = script_length_offset + 4
    script_end = script_start + script_length
    if script_end > len(raw):
        raise ValueError(
            f"Script length {script_length} exceeds remaining object bytes "
            f"{len(raw) - script_start}"
        )
    name = raw[4:name_end].decode("utf-8", errors="replace")
    return name, raw[script_start:script_end]


def find_sources(source: Path) -> tuple[list[Path], int]:
    if source.is_file():
        return [source], 0
    if not source.is_dir():
        raise ValueError(f"Source does not exist: {source}")
    candidates = []
    ignored = 0
    for path in sorted(source.rglob("*")):
        if not path.is_file():
            continue
        if path.name == "__data" or path.suffix.lower() in BUNDLE_SUFFIXES:
            candidates.append(path)
        else:
            ignored += 1
    return candidates, ignored


def output_filename(name: str, source: Path, container: str, path_id: object) -> str:
    # Keep DLL asset suffixes intact for downstream assembly discovery.
    safe = re.sub(r"[^\w.\-]", "_", name, flags=re.UNICODE).strip(". ")
    if not safe:
        safe = "TextAsset"
    if safe.split(".", 1)[0].upper() in RESERVED_NAMES:
        safe = "asset_" + safe
    safe = safe[:120].rstrip(". ")
    suffix = safe[-10:] if safe.lower().endswith(".dll.bytes") else Path(safe).suffix
    stem = safe[:-len(suffix)] if suffix else safe
    identity = json.dumps([str(source), container, str(path_id)], ensure_ascii=False)
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:16]
    return f"{stem}--{digest}{suffix}"


def extract(source: Path, output: Path, load) -> dict:
    source, output = source.resolve(), output.resolve()
    if output == source or (source.is_dir() and output.is_relative_to(source)):
        raise ValueError(f"Output must be outside the source directory: {output}")
    candidates, ignored = find_sources(source)
    if not candidates:
        raise ValueError("No __data, .bundle, .unity3d, or .ab files found")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError(f"Output must be a new or empty directory: {output}")
    output.mkdir(parents=True, exist_ok=True)

    report = {
        "schema_version": 1,
        "source": str(source),
        "output": str(output),
        "assets": [],
        "errors": [],
        "skips": [],
        "summary": {
            "candidate_files": len(candidates),
            "ignored_files": ignored,
            "files_loaded": 0,
            "textassets_extracted": 0,
            "non_textasset_objects": 0,
            "errors": 0,
        },
    }
    for path in candidates:
        try:
            environment = load(str(path))
            objects = list(environment.objects)
            report["summary"]["files_loaded"] += 1
        except Exception as exc:
            report["errors"].append({"source": str(path), "error": str(exc)})
            continue
        if not objects:
            report["skips"].append({"source": str(path), "reason": "no_objects"})
        non_textassets = 0
        for obj in objects:
            if obj.type.name != "TextAsset":
                non_textassets += 1
                continue
            row = {
                "source": str(path),
                "container": str(getattr(obj.assets_file, "name", "")),
                "object_path_id": str(obj.path_id),
            }
            try:
                raw = bytes(obj.get_raw_data())
                endian = obj.reader.endian
                name, script = parse_textasset(raw, endian)
                target = output / output_filename(
                    name, path, row["container"], row["object_path_id"]
                )
                # Exclusive creation also catches duplicate identities/hash collisions.
                with target.open("xb") as stream:
                    stream.write(script)
                row.update({
                    "name": name,
                    "output": target.name,
                    "raw_size": len(raw),
                    "script_size": len(script),
                    "head": script[:16].hex(" "),
                    "sha256": hashlib.sha256(script).hexdigest(),
                    "endian": endian,
                })
                report["assets"].append(row)
                report["summary"]["textassets_extracted"] += 1
            except Exception as exc:
                row["error"] = str(exc)
                report["errors"].append(row)
        if non_textassets:
            report["summary"]["non_textasset_objects"] += non_textassets
            report["skips"].append({
                "source": str(path),
                "reason": "non_textasset_objects",
                "count": non_textassets,
            })
    report["summary"]["errors"] = len(report["errors"])
    with (output / "index.json").open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path,
                        help="YooAsset cache/bundle directory or one serialized file/bundle")
    parser.add_argument("--output", required=True, type=Path,
                        help="New or empty directory for binary TextAssets and index.json")
    args = parser.parse_args(argv)
    try:
        import UnityPy
    except ImportError:
        print("UnityPy is required. Install it with: python -m pip install UnityPy", file=sys.stderr)
        return 2
    try:
        report = extract(args.source, args.output, UnityPy.load)
    except (OSError, ValueError) as exc:
        print(f"Extraction refused: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(report["summary"], ensure_ascii=False))
    print(f"Manifest: {args.output.resolve() / 'index.json'}")
    for error in report["errors"]:
        print(json.dumps(error, ensure_ascii=False), file=sys.stderr)
    if report["errors"]:
        return 1
    return 0 if report["assets"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
