"""Package the playable export and course seed separately. Python 3.11+, stdlib only."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import shutil
import tempfile
import zipfile
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parent
EXCLUDED_DIRS = {
    ".git", ".godot", ".codebuddy", ".weaver", ".venv", "venv",
    "__pycache__", ".pytest_cache", "node_modules", "build", "dist",
    "workspaces", "submissions", "learning_reports",
}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".blend1", ".blend2", ".tmp", ".log", ".pem", ".key"}
EXCLUDED_NAMES = {".npmrc", ".deploy-secrets.env", "mist_harbor_world_v1.json"}
WEB_SUFFIXES = {".html", ".js", ".wasm", ".pck", ".png", ".svg", ".ico", ".json", ".webmanifest"}
REQUIRED_SOURCE = (
    "README.md", "tutorial.yaml", "learning_tasks.json", "package_sample.py", "course_requests.http",
    "project/project.godot", "project/main.tscn", "project/export_presets.cfg",
    "project/scripts/main.gd", "project/scripts/world_model.gd", "project/scripts/build_world.gd",
    "project/art/generate_harbor.py", "project/art/mist-harbor-kit.blend",
    "project/assets/models/manifest.json", "project/assets/fonts-OFL.txt",
    "project/docs/requirements.md", "project/docs/learning-guide.md",
)


def excluded(relative: Path) -> bool:
    return (
        bool(set(relative.parts) & EXCLUDED_DIRS)
        or relative.suffix.lower() in EXCLUDED_SUFFIXES
        or relative.name in EXCLUDED_NAMES
        or relative.name == ".env"
        or relative.name.startswith((".env.", ".deploy-secrets.env."))
    )


def collect_source(root: Path) -> list[tuple[Path, str]]:
    """Only ship the template, never personal submissions or runtime identities."""
    root = root.resolve()
    files = []
    for current, directories, names in os.walk(root, followlinks=False):
        current_path = Path(current)
        for directory in list(directories):
            path = current_path / directory
            if excluded(path.relative_to(root)):
                directories.remove(directory)
            elif path.is_symlink():
                raise ValueError(f"Refusing a symlink in source: {path}")
        for name in sorted(names):
            path = current_path / name
            relative = path.relative_to(root)
            if excluded(relative):
                continue
            if path.is_symlink():
                raise ValueError(f"Refusing a symlink in source: {path}")
            files.append((path, relative.as_posix()))
    return sorted(files, key=lambda item: item[1])


def collect_web(web_dir: Path) -> list[tuple[Path, str]]:
    """Fail before packaging if the supplied directory is not a Godot Web export."""
    web_dir = web_dir.resolve()
    for name in ("index.html", "index.js", "index.pck", "index.wasm"):
        path = web_dir / name
        if not path.is_file() or path.is_symlink() or path.stat().st_size == 0:
            raise ValueError(f"Missing Web export: {path}")
    for name, magic in (("index.pck", b"GDPC"), ("index.wasm", b"\x00asm")):
        with (web_dir / name).open("rb") as stream:
            if stream.read(4) != magic:
                raise ValueError(f"Invalid Godot export header: {name}")
    files = []
    for path in sorted(web_dir.rglob("*")):
        relative = path.relative_to(web_dir)
        if path.is_symlink():
            raise ValueError(f"Refusing a symlink in Web export: {path}")
        if not path.is_file() or any(part.startswith(".") for part in relative.parts):
            continue
        if path.suffix.lower() in WEB_SUFFIXES or path.name == "_headers":
            files.append((path, relative.as_posix()))
    return files


def prepare_edgeone_web(web_dir: Path, destination: Path, *, max_file_bytes: int = 25 * 1024 * 1024) -> dict:
    """Prepare a separate upload tree; original Web export remains unchanged.

    EdgeOne checks the unzipped per-file size. Precompressing a WASM response
    needs Content-Encoding, not just a ZIP around the original export.
    """
    web_dir, destination = web_dir.resolve(), destination.resolve()
    if destination.exists() or destination.is_relative_to(web_dir) or web_dir.is_relative_to(destination):
        raise ValueError("EdgeOne output must be a new directory separate from the Web export")
    files = collect_web(web_dir)
    if any(name in {"edgeone.json", "_headers"} for _, name in files):
        raise ValueError("Review existing hosting configuration before preparing EdgeOne output")
    destination.mkdir(parents=True, exist_ok=False)
    result = {"files": [], "compressed": []}
    headers = [{"source": "/*", "headers": [
        {"key": "Cache-Control", "value": "public, max-age=0, must-revalidate, no-transform"},
        {"key": "X-Content-Type-Options", "value": "nosniff"},
    ]}]
    try:
        for source, relative in files:
            data = source.read_bytes()
            original_size = len(data)
            digest = hashlib.sha256(data).hexdigest()
            if source.suffix.lower() == ".wasm":
                data = gzip.compress(data, compresslevel=9, mtime=0)
                if hashlib.sha256(gzip.decompress(data)).hexdigest() != digest:
                    raise ValueError(f"WASM compression roundtrip failed: {relative}")
                headers.append({"source": "/" + relative, "headers": [
                    {"key": "Content-Type", "value": "application/wasm"},
                    {"key": "Content-Encoding", "value": "gzip"},
                ]})
                result["compressed"].append({"path": relative, "original_bytes": original_size,
                                             "upload_bytes": len(data), "original_sha256": digest})
            if len(data) > max_file_bytes:
                raise ValueError(f"File still exceeds EdgeOne limit: {relative} ({len(data)} bytes)")
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            result["files"].append(relative)
        config = {"buildCommand": "", "installCommand": "", "outputDirectory": ".", "headers": headers}
        (destination / "edgeone.json").write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    except BaseException:
        shutil.rmtree(destination)
        raise
    return result


def write_archive(destination: Path, files: list[tuple[Path, str]]) -> dict:
    # 固定 ZIP 元信息；相同源文件能再次产出相同校验和。
    handle, raw_temp = tempfile.mkstemp(prefix=destination.name + ".", suffix=".tmp", dir=destination.parent)
    os.close(handle)
    temp = Path(raw_temp)
    try:
        with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for source, relative in files:
                info = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, source.read_bytes())
        os.replace(temp, destination)
    finally:
        temp.unlink(missing_ok=True)
    return {"file": destination.name, "bytes": destination.stat().st_size,
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(), "files": len(files)}


def copy_seed(seed_dir: Path, files: list[tuple[Path, str]]) -> None:
    """Never overwrite a learner workspace, even an existing empty one."""
    seed_dir.mkdir(parents=True, exist_ok=False)
    try:
        for source, relative in files:
            target = seed_dir / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    except BaseException:
        # 仅清理这次刚创建的目录；入口已用 exist_ok=False 拒绝既有作品。
        shutil.rmtree(seed_dir)
        raise


def build_packages(root: Path, output: Path, *, web_dir: Path | None = None,
                   seed_dir: Path | None = None) -> dict:
    root, output = root.resolve(), output.resolve()
    if output.is_relative_to(root) and ".codebuddy" not in output.relative_to(root).parts:
        raise ValueError("Put release output outside source, or under an ignored .codebuddy directory")
    files = collect_source(root)
    names = {relative for _, relative in files}
    missing = set(REQUIRED_SOURCE) - names
    if missing:
        raise ValueError(f"Incomplete source package: {sorted(missing)}")
    project_files = [(path, relative[len("project/"):]) for path, relative in files if relative.startswith("project/")]
    web_files = collect_web(web_dir) if web_dir is not None else None
    if seed_dir is not None:
        seed_dir = seed_dir.resolve()
        if seed_dir.exists() or seed_dir.is_relative_to(root) or root.is_relative_to(seed_dir):
            raise ValueError("Seed must be a new, independent directory outside this source tree")
        if output.is_relative_to(seed_dir) or seed_dir.is_relative_to(output):
            raise ValueError("Seed and release output directories must not overlap")
    output.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_version": 1,
        "sample": "mist-harbor-3d",
        "tutorial_text_sha256": hashlib.sha256((root / "tutorial.yaml").read_bytes()).hexdigest(),
        "source_files": {relative: hashlib.sha256(path.read_bytes()).hexdigest() for path, relative in files},
        "archives": {},
    }
    manifest["archives"]["source"] = write_archive(
        output / "mist-harbor-source.zip", [(path, "mist-harbor/" + rel) for path, rel in files])
    manifest["archives"]["seed"] = write_archive(output / "mist-harbor-seed.zip", project_files)
    if web_files is not None:
        manifest["archives"]["web"] = write_archive(output / "mist-harbor-web.zip", web_files)
    if seed_dir is not None:
        copy_seed(seed_dir, project_files)
        manifest["prepared_seed"] = str(seed_dir)
    (output / "release.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Directory for source/seed/Web ZIPs and release.json")
    parser.add_argument("--web-dir", type=Path, help="Existing Godot Web export directory; this script does not run the engine")
    parser.add_argument("--seed-dir", type=Path, help="Optional NEW independent learner project directory; existing paths are rejected")
    parser.add_argument("--edgeone-dir", type=Path, help="Optional NEW upload tree with precompressed WASM and EdgeOne response headers")
    args = parser.parse_args()
    if args.edgeone_dir and not args.web_dir:
        parser.error("--edgeone-dir requires --web-dir")
    try:
        result = build_packages(PACKAGE_ROOT, args.output, web_dir=args.web_dir, seed_dir=args.seed_dir)
        if args.edgeone_dir:
            prepared = prepare_edgeone_web(args.web_dir, args.edgeone_dir)
            (args.output / "edgeone-preparation.json").write_text(json.dumps(prepared, indent=2) + "\n", encoding="utf-8")
            print("EdgeOne upload directory:", args.edgeone_dir)
            for file in prepared["compressed"]:
                print(f"{file['path']}: {file['original_bytes']} -> {file['upload_bytes']} bytes (gzip; decoded bytes verified)")
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        parser.exit(1, f"Packaging failed: {exc}\n")
    for kind, entry in result["archives"].items():
        print(f"{kind}: {args.output / entry['file']} ({entry['bytes']} bytes, sha256={entry['sha256']})")
    if args.seed_dir:
        print(f"Independent course seed: {args.seed_dir}")
    print("No deployment, account changes, tutorial import or learner task completion was performed.")


if __name__ == "__main__":
    main()
