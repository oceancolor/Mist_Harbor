"""Tripo API 连通性自检（不消耗额度的只读探测）。

读取顺序（越靠前优先级越高）：
    1. 环境变量 TRIPO_API_KEY
    2. .codebuddy/local/tripo.json  -> {"api_key": "tsk_..."}
    3. "3D tools config/3Denv.txt"  -> 任意含 tsk_ 的行

探测到可用 base url 后写入 .codebuddy/local/tripo.json（该目录已被 .gitignore 忽略）。

用法：
    python tools/tripo_check.py            # 只探测并打印
    python tools/tripo_check.py --save     # 探测并把 base_url 写入本地配置
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL_DIR = ROOT / ".codebuddy" / "local"
LOCAL_CFG = LOCAL_DIR / "tripo.json"
KEY_TXT = ROOT / "3D tools config" / "3Denv.txt"

BASE_V3 = "https://openapi.tripo3d.ai/v3"
BASE_V2 = "https://api.tripo3d.ai/v2/openapi"

KEY_RE = re.compile(r"tsk_[A-Za-z0-9_\-]+")
TIMEOUT = 20


def load_key() -> tuple[str, str]:
    """返回 (key, 来源说明)。"""
    env = os.environ.get("TRIPO_API_KEY", "").strip()
    if env:
        return env, "环境变量 TRIPO_API_KEY"

    if LOCAL_CFG.exists():
        try:
            data = json.loads(LOCAL_CFG.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            data = {}
        key = str(data.get("api_key", "")).strip()
        if key:
            return key, str(LOCAL_CFG)

    if KEY_TXT.exists():
        for line in KEY_TXT.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = KEY_RE.search(line)
            if m:
                return m.group(0), str(KEY_TXT)

    raise SystemExit("未找到 Tripo API key：请设置 TRIPO_API_KEY 或填写 " + str(KEY_TXT))


def base_url() -> str:
    """v3 站点地址：TRIPO_BASE_URL > .codebuddy/local/tripo.json 的 base_url > 默认国际站。

    国内站（tripo3d.com）与国际站（tripo3d.ai）账号与 key 不通用，换站时改这里即可。
    """
    env = os.environ.get("TRIPO_BASE_URL", "").strip()
    if env:
        return env.rstrip("/")
    if LOCAL_CFG.exists():
        try:
            cfg = json.loads(LOCAL_CFG.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            cfg = {}
        cfg_base = str(cfg.get("base_url", "")).strip().rstrip("/")
        if cfg_base:
            return cfg_base
    return BASE_V3


def mask(key: str) -> str:
    return f"{key[:6]}...{key[-4:]}" if len(key) > 12 else "***"


def probe(method: str, url: str, key: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "MistHarbor-tripo-check/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            status = resp.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        status = e.code
    except (urllib.error.URLError, TimeoutError) as e:
        return {"ok": False, "status": "-", "error": f"{type(e).__name__}: {e}"}

    try:
        body = json.loads(raw)
    except json.JSONDecodeError:
        return {"ok": 200 <= status < 300, "status": status, "raw": raw[:300]}

    if isinstance(body, dict) and "code" in body:
        return {
            "ok": body.get("code") == 0 and 200 <= status < 300,
            "reachable": status not in (401, 403),
            "status": status,
            "code": body.get("code"),
            "message": body.get("message", ""),
            "data": body.get("data"),
        }
    return {"ok": 200 <= status < 300, "reachable": status not in (401, 403), "status": status, "body": body}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--save", action="store_true", help="把探测到的 base_url 写入 .codebuddy/local/tripo.json")
    args = ap.parse_args()

    key, source = load_key()
    print(f"key      : {mask(key)}  (来源: {source})")

    v3 = base_url()
    checks = [
        ("v3", "GET", f"{v3}/account/balance", None),
        ("v3", "GET", f"{v3}/account/usage", None),
        ("v3", "POST", f"{v3}/tasks/list", {"taskIds": ["task_mistharbor_probe"]}),
    ]

    alive: dict[str, list[str]] = {}
    for gen, method, url, payload in checks:
        r = probe(method, url, key, payload)
        if r["ok"]:
            tag = "OK  "
            detail = json.dumps(r.get("data", r.get("body")), ensure_ascii=False)[:200]
        elif r.get("reachable"):
            tag = "REACH"
            detail = r.get("message") or r.get("raw") or r.get("error") or ""
        else:
            tag = "FAIL"
            detail = r.get("message") or r.get("error") or r.get("raw") or ""
        print(f"[{tag}] {method} {url}  -> HTTP {r['status']} code={r.get('code', '-')} {detail}")
        if r["ok"] or r.get("reachable"):
            alive.setdefault(gen, []).append(url)

    if not alive:
        print("\n结论：没有可用端点。检查 key 是否有效 / 网络是否可达（国内站为 developers.tripo3d.com）。")
        return 1

    gen, urls = next(iter(alive.items()))
    base = v3 if gen == "v3" else BASE_V2
    print(f"\n结论：key 有效，活跃版本 = {gen}，base url = {base}")
    print("可达端点：" + ", ".join(urls))

    if gen == "v3":
        r = probe("GET", f"{v3}/account/balance", key)
        data = r.get("data") or {}
        if isinstance(data, dict) and "balance" in data:
            left = float(data.get("balance") or 0)
            print(f"余额：balance={left} frozen={data.get('frozen')}")
            if left <= 0:
                print("警告：余额为 0，生成类接口会返回 Insufficient credits，需确认充值是否到账 / 是否充在另一站点账号。")

    if args.save:
        LOCAL_DIR.mkdir(parents=True, exist_ok=True)
        cfg = {}
        if LOCAL_CFG.exists():
            try:
                cfg = json.loads(LOCAL_CFG.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                cfg = {}
        cfg.update({"api_key": key, "base_url": base, "api_version": gen})
        LOCAL_CFG.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"已写入 {LOCAL_CFG}（不入库）")

    return 0


if __name__ == "__main__":
    sys.exit(main())
