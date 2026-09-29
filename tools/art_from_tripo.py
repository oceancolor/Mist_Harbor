"""Tripo 样品 → 游戏资产 的 ③B QA 驱动。

读取地点建材表里该建材的足迹/高度规格，调用本机 Blender headless 跑 qa_batch.py，
产物写入 project/assets/models/<name>.glb；--apply 时把建材表 mesh 改成 <name>。

用法：
    py tools/art_from_tripo.py --location cape-cod --kind buoy \
        --glb .codebuddy/local/tripo/samples/buoy_s42b_low/buoy_s42b_low_model.glb \
        --name loc_cc_prop_buoy [--flat] [--apply]

--flat  剥掉贴图改纯色（用建材表 color；多色英雄件不要用）

统一入口是 asset_pipeline.py build-tripo（本脚本 + manifest + Godot 导入一条龙）；
本脚本保留可单跑，但新资产请走 build-tripo。
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS_CFG = ROOT / ".codebuddy" / "local" / "tools.json"


def blender_path() -> str:
    if TOOLS_CFG.exists():
        cfg = json.loads(TOOLS_CFG.read_text(encoding="utf-8"))
        exe = str(cfg.get("blender", "")).strip()
        if exe and Path(exe).exists():
            return exe
    for guess in [r"E:\Blender 5.2\blender.exe", "blender"]:
        if Path(guess).exists() or guess == "blender":
            return guess
    raise SystemExit("blender 未找到：请配置 .codebuddy/local/tools.json 的 blender 键")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--location", required=True)
    ap.add_argument("--kind", required=True, help="建材表 id")
    ap.add_argument("--glb", required=True, help="Tripo 样品 GLB 路径")
    ap.add_argument("--name", required=True, help="产物名（loc_{地点}_{类别}_{名称}）")
    ap.add_argument("--flat", action="store_true", help="剥贴图改纯色（建材表 color）")
    ap.add_argument("--apply", action="store_true", help="把建材表 mesh 改成 <name>")
    ap.add_argument("--faces", type=int, default=2000)
    ap.add_argument("--footprint", default="", help="覆盖视觉足迹（如 2,2）；默认取建材表 size")
    args = ap.parse_args()

    palette_path = ROOT / "project" / "data" / "locations" / args.location / "palette.json"
    palette = json.loads(palette_path.read_text(encoding="utf-8"))
    entry = next((i for i in palette["items"] if i["id"] == args.kind), None)
    if entry is None:
        raise SystemExit(f"palette {args.location} 无 {args.kind}")

    size = entry.get("size")
    footprint = args.footprint or (
        f"{size[0]},{size[2]}" if isinstance(size, list) and len(size) == 3 else "1,1")
    height = float(entry.get("height", 2))
    color = str(entry.get("color", "ffffff")).lstrip("#")

    out_dir = ROOT / "project" / "assets" / "models"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_glb = out_dir / f"{args.name}.glb"

    cmd = [
        blender_path(), "--background", "--factory-startup",
        "--python", str(ROOT / "tools" / "qa_batch.py"), "--",
        "--input", str(Path(args.glb).resolve()),
        "--output", str(out_glb),
        "--footprint", footprint, "--height", str(height),
        "--faces", str(args.faces), "--name", args.name,
    ]
    if args.flat:
        cmd += ["--flat-color", color]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=180,
                          encoding="utf-8", errors="replace")
    qa_line = ""
    for line in (proc.stdout or "").splitlines():
        if line.startswith("MISTHARBOR_QA "):
            qa_line = line
        elif line.strip().startswith(("Error", "WARNING")) and "MIST" not in line:
            print("  blender:", line.strip()[:160])
    if not qa_line:
        print(proc.stdout[-2000:] if proc.stdout else "", file=sys.stderr)
        print(proc.stderr[-2000:] if proc.stderr else "", file=sys.stderr)
        raise SystemExit("QA 失败：无 MISTHARBOR_QA 结果行")
    result = json.loads(qa_line[len("MISTHARBOR_QA "):])
    print(f"{args.kind} -> {args.name}.glb  ok={result['ok']} tris={result.get('triangles')} "
          f"size={result.get('size_units')} {result.get('file_kb')}KB")

    if not result["ok"]:
        return 1

    if args.apply:
        entry["mesh"] = args.name
        palette_path.write_text(json.dumps(palette, ensure_ascii=False, indent=2) + "\n",
                                encoding="utf-8", newline="")
        print(f"palette 更新：{args.location}/{args.kind}.mesh = {args.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
