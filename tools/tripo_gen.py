"""Tripo text-to-model 打样：提交任务 -> 轮询 -> 下载 GLB/预览图 -> 写 meta。

产物默认落在 .codebuddy/local/tripo/samples/<name>/（不入库）。

用法：
    # 1) 提交（先只等 15 秒拿 task_id，避免命令超时）
    py tools/tripo_gen.py --name buoy --wait 15 --prompt "..."
    # 2) 续轮询 + 下载
    py tools/tripo_gen.py --name buoy --task-id task_xxx --wait 600

常用参数：--model(v3.1-20260211 / P1-20260311 / P2-20260801)
          --face-limit --texture/--no-texture --pbr --auto-size --seed
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8")  # Windows 控制台默认 GBK，避免中文乱码
    except (AttributeError, ValueError):
        pass

from tripo_check import base_url, load_key, probe  # noqa: E402  (脚本同目录)

ROOT = Path(__file__).resolve().parents[1]
OUT_ROOT = ROOT / ".codebuddy" / "local" / "tripo" / "samples"

DEFAULT_PROMPT = (
    "A weathered harbor mooring buoy: cylindrical red-painted float with rusty iron bands "
    "and a small iron ring on top, low-poly stylized game asset, clean simple silhouette."
)


def request_json(method: str, url: str, key: str, payload: dict | None = None) -> dict:
    return probe(method, url, key, payload)


def download(url: str, dest: Path) -> tuple[int, str]:
    req = urllib.request.Request(url, headers={"User-Agent": "MistHarbor-tripo/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp, open(dest, "wb") as fh:
        data = resp.read()
        fh.write(data)
    return len(data), hashlib.sha256(data).hexdigest()


def glb_stats(path: Path) -> dict:
    """从 GLB 的 JSON chunk 统计三角面/顶点/材质（不依赖第三方库）。"""
    try:
        raw = path.read_bytes()
        if raw[:4] != b"glTF":
            return {}
        version = struct.unpack_from("<I", raw, 4)[0]
        length = struct.unpack_from("<I", raw, 8)[0]
        off = 12
        gltf = None
        while off < min(length, len(raw)):
            c_len, c_type = struct.unpack_from("<II", raw, off)
            body = raw[off + 8 : off + 8 + c_len]
            if c_type == 0x4E4F534A:  # JSON
                gltf = json.loads(body.decode("utf-8"))
                break
            off += 8 + c_len
        if gltf is None:
            return {}
        tris = 0
        verts = 0
        for mesh in gltf.get("meshes", []):
            for prim in mesh.get("primitives", []):
                acc = gltf["accessors"][prim.get("indices", -1)] if "indices" in prim else None
                if acc:
                    tris += acc["count"] // 3
                pos = gltf["accessors"][prim["attributes"]["POSITION"]]
                verts += pos["count"]
        return {
            "gltf_version": version,
            "triangles": tris,
            "vertices": verts,
            "meshes": len(gltf.get("meshes", [])),
            "materials": len(gltf.get("materials", [])),
            "images": len(gltf.get("images", [])),
        }
    except Exception as e:  # 统计失败不影响主流程
        return {"stats_error": f"{type(e).__name__}: {e}"}


def poll(task_id: str, key: str, wait_seconds: int, interval: int = 6) -> dict:
    url = f"{base_url()}/tasks/{task_id}"
    deadline = time.time() + wait_seconds
    last = {}
    while True:
        r = request_json("GET", url, key)
        last = r.get("data") or {}
        if not r["ok"]:
            print(f"查询失败: HTTP {r['status']} code={r.get('code')} {r.get('message')}")
            return {}
        status = last.get("status")
        print(f"  status={status} progress={last.get('progress')}", flush=True)
        if status in ("success", "failed", "cancelled"):
            return last
        if time.time() >= deadline:
            print(f"等待超时，任务仍在进行。用 --task-id {task_id} 继续。")
            return {}
        time.sleep(interval)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", default="sample", help="产物目录名")
    ap.add_argument("--prompt", default=DEFAULT_PROMPT)
    ap.add_argument("--negative-prompt", default="blurry, low quality, broken mesh, text, watermark")
    ap.add_argument("--model", default="P1-20260311")
    ap.add_argument("--face-limit", type=int, default=3000)
    ap.add_argument("--no-texture", action="store_true")
    ap.add_argument("--no-pbr", action="store_true")
    ap.add_argument("--auto-size", action="store_true", default=True)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--wait", type=int, default=240, help="轮询最长等待秒数")
    ap.add_argument("--wait-credits", type=int, default=0, help="余额为 0 时先等待额度到账的秒数（0=不等待直接报错）")
    ap.add_argument("--task-id", default=None, help="续轮询已提交的任务")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    key, _ = load_key()
    out_dir = Path(args.out) if args.out else OUT_ROOT / args.name
    out_dir.mkdir(parents=True, exist_ok=True)
    meta_path = out_dir / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}

    task_id = args.task_id or meta.get("task_id")
    if not task_id:
        deadline = time.time() + args.wait_credits
        while True:
            bal = probe("GET", f"{base_url()}/account/balance", key)
            left = float((bal.get("data") or {}).get("balance") or 0)
            if left > 0:
                print(f"余额 {left}，开始提交。")
                break
            if args.wait_credits <= 0:
                print("余额为 0。若已充值：确认 key 与充值在同一 workspace，或用 --wait-credits 等待到账。")
                return 4
            if time.time() >= deadline:
                print("等待额度超时，仍未到账。")
                return 4
            print(f"余额 {left}，等待到账（剩余 {int(deadline - time.time())}s）...", flush=True)
            time.sleep(15)

        payload: dict = {
            "prompt": args.prompt,
            "model": args.model,
            "face_limit": args.face_limit,
            "texture": not args.no_texture,
            "pbr": not args.no_pbr,
            "auto_size": args.auto_size,
        }
        if args.seed is not None:
            payload["image_seed"] = args.seed
            payload["model_seed"] = args.seed
            payload["texture_seed"] = args.seed
        if args.negative_prompt:
            payload["negative_prompt"] = args.negative_prompt

        r = request_json("POST", f"{base_url()}/generation/text-to-model", key, payload)
        if not r["ok"]:
            print(f"提交失败: HTTP {r['status']} code={r.get('code')} {r.get('message')}")
            return 1
        task_id = r["data"]["task_id"]
        print(f"已提交 task_id={task_id}  model={args.model} face_limit={args.face_limit}")
        meta.update({"task_id": task_id, "request": payload, "prompt": args.prompt})
        meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"轮询 {task_id}（最多 {args.wait}s）...")
    data = poll(task_id, key, args.wait)
    meta.update({"task_id": task_id, "last_poll": data})
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    if not data:
        return 2

    if data.get("status") != "success":
        print(f"任务未成功: status={data.get('status')} error={data.get('error_message') or data.get('error_code')}")
        return 3

    out = data.get("output") or {}
    print(f"成功，credits_consumed={data.get('credits_consumed')}")
    files = {}
    # role -> (output 字段名, 默认扩展名)
    wanted = (
        ("model", "model_url", ".glb"),
        ("preview", "rendered_image_url", ".png"),
        ("reference", "generated_image_url", ".jpg"),
    )
    for role, key_name, default_ext in wanted:
        url = out.get(key_name)
        if not url:
            continue
        suffix = Path(urlparse(url).path).suffix.lower()
        if suffix not in (".glb", ".png", ".jpg", ".jpeg", ".webp", ".gltf"):
            suffix = default_ext
        dest = out_dir / f"{args.name}_{role}{suffix}"
        size, sha = download(url, dest)
        files[role] = {"path": str(dest), "bytes": size, "sha256": sha, "url": url}
        print(f"下载 {role}: {dest} ({size} B) sha256={sha[:16]}...")

    stats = glb_stats(Path(files["model"]["path"])) if "model" in files else {}
    meta.update({"status": "success", "files": files, "glb_stats": stats, "credits_consumed": data.get("credits_consumed")})
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print("统计: " + json.dumps(stats, ensure_ascii=False))
    print(f"meta: {meta_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
