"""Tripo API client for the Mist Harbor asset pipeline (user's own Pro account).

Auth: Bearer key stored at .codebuddy/local/tripo/key.txt (never commit).
Studio dashboard is studio.tripo3d.ai; the API base is api.tripo3d.ai/v2/openapi.

Usage:
  py tools/art/tripo_client.py balance
  py tools/art/tripo_client.py submit --prompt "..." [--format glb] [--face-limit N]
      [--image path] [--out task_id.txt]
  py tools/art/tripo_client.py poll --task <id>
  py tools/art/tripo_client.py download --task <id> --out path.glb   # polls until done
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import urllib.request

ROOT = Path(__file__).resolve().parents[2]
KEY_PATH = ROOT / ".codebuddy" / "local" / "tripo" / "key.txt"
BASE = "https://api.tripo3d.ai/v2/openapi"


def api_key() -> str:
    if not KEY_PATH.is_file():
        raise SystemExit(f"API key missing: {KEY_PATH}")
    return KEY_PATH.read_text(encoding="ascii").strip()


def request(method: str, path: str, body: dict | None = None, timeout: int = 30) -> dict:
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": "application/json",
            # Cloudflare 1010：默认 Python-urllib UA 会被机器人签名拦截。
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MistHarborAssetPipeline/1.0",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:500]
        raise SystemExit(f"HTTP {exc.code} {method} {path}\n{detail}") from exc
    if payload.get("code") not in (0, None):
        raise SystemExit(f"API error: {payload}")
    return payload.get("data", payload)


def cmd_balance(_args) -> None:
    for path in ("/user", f"/user/{api_key()}"):
        try:
            print(json.dumps(request("GET", path), ensure_ascii=False, indent=1))
            return
        except SystemExit:
            raise
        except Exception as exc:  # noqa: BLE001 - try alternate endpoint shape
            print(f"balance via {path}: {exc}", file=sys.stderr)


def cmd_submit(args) -> None:
    body: dict = {
        "type": "image_to_model" if args.image else "text_to_model",
        "format": args.format,
    }
    if args.image:
        import base64

        image_path = Path(args.image)
        body["image"] = f"data:{_mime(image_path)};base64," + base64.b64encode(
            image_path.read_bytes()).decode()
        if args.prompt:
            body["prompt"] = args.prompt
    else:
        body["prompt"] = args.prompt
    if args.face_limit:
        body["face_limit"] = args.face_limit
    if args.texture_quality:
        body["texture_quality"] = args.texture_quality
    if args.quality:
        body["quality"] = args.quality
    data = request("POST", "/task", body)
    print(data.get("task_id", ""))
    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(data.get("task_id", ""), encoding="ascii")


def _mime(path: Path) -> str:
    return {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
            ".webp": "image/webp"}.get(path.suffix.lower(), "image/png")


def cmd_poll(args) -> None:
    data = request("GET", f"/task/{args.task}")
    status = data.get("status")
    progress = data.get("progress", 0)
    output = data.get("output") or {}
    print(f"status={status} progress={progress}")
    for key in ("pbr_model", "model", "rendered_image", "mini_preview"):
        if output.get(key):
            print(f"{key}: {output[key]}")
    if status == "failed":
        print(f"FAILED: {data.get('output', {}).get('message') or data}", file=sys.stderr)
        sys.exit(1)


def cmd_download(args) -> None:
    deadline = time.time() + args.timeout
    url = ""
    while time.time() < deadline:
        data = request("GET", f"/task/{args.task}")
        status = data.get("status")
        print(f"[{time.strftime('%H:%M:%S')}] status={status} progress={data.get('progress', 0)}",
              file=sys.stderr)
        if status == "failed":
            raise SystemExit(f"task failed: {data}")
        if status == "success":
            output = data.get("output") or {}
            url = output.get("pbr_model") or output.get("model") or ""
            if url:
                break
        time.sleep(args.interval)
    if not url:
        raise SystemExit("timeout waiting for task")
    dest = Path(args.out)
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=120) as resp, dest.open("wb") as fh:
        fh.write(resp.read())
    print(f"downloaded {dest} ({dest.stat().st_size // 1024} KB)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(required=True)

    sub.add_parser("balance").set_defaults(func=cmd_balance)

    p_submit = sub.add_parser("submit")
    p_submit.add_argument("--prompt", default="")
    p_submit.add_argument("--image", default="")
    p_submit.add_argument("--format", default="glb")
    p_submit.add_argument("--face-limit", type=int, default=0)
    p_submit.add_argument("--texture-quality", default="")
    p_submit.add_argument("--quality", default="")
    p_submit.add_argument("--out", default="")
    p_submit.set_defaults(func=cmd_submit)

    p_poll = sub.add_parser("poll")
    p_poll.add_argument("--task", required=True)
    p_poll.set_defaults(func=cmd_poll)

    p_dl = sub.add_parser("download")
    p_dl.add_argument("--task", required=True)
    p_dl.add_argument("--out", required=True)
    p_dl.add_argument("--timeout", type=int, default=900)
    p_dl.add_argument("--interval", type=int, default=10)
    p_dl.set_defaults(func=cmd_download)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
