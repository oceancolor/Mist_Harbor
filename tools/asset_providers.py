"""Text-to-3D providers used by Mist Harbor's asset pipeline.

Secrets are read from environment variables only. Generated files are downloaded
immediately because upstream retention windows are short. Provider responses are
normalized to a small submit/poll/download contract so downstream Blender QA is
identical for Tripo and Hunyuan.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import struct
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class ProviderError(RuntimeError):
    pass


MAX_JSON_BYTES = 1024 * 1024
MAX_MODEL_BYTES = 64 * 1024 * 1024


def _https_url(url: str, hosts: frozenset[str] | None = None) -> str:
    try:
        parsed = urllib.parse.urlsplit(url)
        valid = (parsed.scheme == "https" and parsed.hostname and not parsed.username
                 and not parsed.password and not parsed.fragment and parsed.port in (None, 443))
    except ValueError:
        valid = False
    if not valid or any(ord(c) < 33 or c == "\\" for c in url):
        raise ProviderError("provider URL must use HTTPS without credentials or fragments")
    if hosts is not None and parsed.hostname.lower() not in hosts:
        raise ProviderError("download host is not in TRIPO_DOWNLOAD_HOSTS")
    return url


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ProviderError("provider redirects are disabled; review the configured endpoint")


_HTTP = urllib.request.build_opener(_NoRedirect())


def _read_limited(response, limit: int, deadline: float) -> bytes:
    raw_length = response.headers.get("Content-Length")
    try:
        length = int(raw_length) if raw_length is not None else None
    except ValueError:
        raise ProviderError("invalid response size") from None
    if length is not None and not 0 <= length <= limit:
        raise ProviderError("response exceeds transfer size limit")
    output = bytearray()
    while True:
        if time.monotonic() >= deadline:
            raise ProviderError("provider transfer timed out")
        chunk = response.read(min(65536, limit + 1 - len(output)))
        if not chunk:
            break
        output.extend(chunk)
        if len(output) > limit:
            raise ProviderError("response exceeds transfer size limit")
    if length is not None and length != len(output):
        raise ProviderError("truncated provider response")
    return bytes(output)


def _fetch(url: str, *, headers: dict[str, str] | None = None, method: str = "GET",
           body: bytes | None = None, limit: int = MAX_MODEL_BYTES, timeout: float = 120) -> bytes:
    _https_url(url)
    if not math.isfinite(timeout) or timeout <= 0:
        raise ProviderError("provider deadline expired")
    request = urllib.request.Request(url, data=body, headers=headers or {}, method=method)
    deadline = time.monotonic() + timeout
    try:
        with _HTTP.open(request, timeout=min(timeout, 120)) as response:
            return _read_limited(response, limit, deadline)
    except urllib.error.HTTPError as exc:
        code = exc.code
        exc.close()
        raise ProviderError(f"provider HTTP status {code}") from None
    except (OSError, urllib.error.URLError):
        raise ProviderError("provider network request failed") from None


def _json_request(url: str, *, method: str = "GET", headers: dict[str, str] | None = None,
                  payload: dict[str, Any] | None = None, timeout: float = 120) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    request_headers = {"Accept": "application/json", **(headers or {})}
    if body is not None:
        request_headers["Content-Type"] = "application/json"
    raw = _fetch(url, method=method, headers=request_headers, body=body, limit=MAX_JSON_BYTES, timeout=timeout)
    try:
        parsed = json.loads(raw)
    except (ValueError, UnicodeError):
        raise ProviderError("invalid provider JSON response") from None
    if not isinstance(parsed, dict):
        raise ProviderError("unexpected provider response type")
    return parsed


def _write_glb(path: Path, payload: bytes) -> None:
    if not 20 <= len(payload) <= MAX_MODEL_BYTES:
        raise ProviderError("GLB size is outside transfer limits")
    magic, version, total, length, chunk = struct.unpack_from("<4sIIII", payload)
    if magic != b"glTF" or version != 2 or total != len(payload) or chunk != 0x4E4F534A or 20 + length > total:
        raise ProviderError("download is not a valid GLB 2 container")
    try:
        data = json.loads(payload[20:20+length])
    except (ValueError, UnicodeError) as exc:
        raise ProviderError("download has invalid GLB JSON") from exc
    if (not isinstance(data, dict) or not isinstance(data.get("asset"), dict)
            or data["asset"].get("version") != "2.0" or not isinstance(data.get("meshes"), list)
            or not data["meshes"]):
        raise ProviderError("download has no glTF 2 mesh data")
    if path.exists():
        raise ProviderError("draft output already exists; refusing to overwrite")
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".draft-", suffix=".tmp", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(payload)
            output.flush()
            os.fsync(output.fileno())
        os.link(temporary, path)
    except FileExistsError:
        raise ProviderError("draft output appeared during generation; refusing to overwrite") from None
    finally:
        temporary.unlink(missing_ok=True)


@dataclass(frozen=True)
class GenerationRequest:
    asset_id: str
    prompt: str
    face_limit: int | None
    output: Path


def _preflight(request: GenerationRequest, timeout: float) -> float:
    if not math.isfinite(timeout) or timeout <= 0 or not request.prompt.strip():
        raise ProviderError("a prompt and positive finite timeout are required")
    if request.face_limit is not None and (type(request.face_limit) is not int or request.face_limit <= 0):
        raise ProviderError("face_limit must be a positive integer when provided")
    if request.output.suffix.lower() != ".glb" or request.output.exists():
        raise ProviderError("draft path must be a new GLB file")
    request.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryFile(dir=request.output.parent) as probe:
        probe.write(b"draft-preflight")
        probe.flush()
    return time.monotonic() + timeout


def _task_id(value: Any) -> str:
    if not isinstance(value, str) or not value or len(value) > 128 or not all(c.isascii() and (c.isalnum() or c in "-_") for c in value):
        raise ProviderError("provider returned an invalid task identifier")
    return value


class Provider:
    name = "provider"

    def generate(self, request: GenerationRequest, timeout: int = 900) -> dict[str, Any]:
        raise NotImplementedError


class TripoProvider(Provider):
    """Tripo OpenAPI v2 text-to-model adapter."""

    name = "tripo"
    base_url = "https://api.tripo3d.ai/v2/openapi"

    def __init__(self, secret: str | None = None, download_hosts: frozenset[str] | None = None) -> None:
        self.secret = secret or os.environ.get("TRIPO_API_SECRET") or os.environ.get("TRIPO_API_KEY")
        if not self.secret:
            raise ProviderError("TRIPO_API_SECRET is not set")
        configured = download_hosts if download_hosts is not None else os.environ.get("TRIPO_DOWNLOAD_HOSTS", "").split(",")
        self.download_hosts = frozenset(host.strip().lower() for host in configured if host.strip())
        for host in self.download_hosts:
            if not all(c.isascii() and (c.isalnum() or c in ".-") for c in host) or any(not label or label.startswith("-") or label.endswith("-") for label in host.split(".")):
                raise ProviderError("TRIPO_DOWNLOAD_HOSTS requires exact hostnames without URLs or wildcards")
        self.headers = {"Authorization": f"Bearer {self.secret}"}

    def generate(self, request: GenerationRequest, timeout: int = 900) -> dict[str, Any]:
        if not self.download_hosts:
            raise ProviderError("set TRIPO_DOWNLOAD_HOSTS to reviewed exact download hostnames before generating")
        deadline = _preflight(request, timeout)
        payload = {"type": "text_to_model", "prompt": request.prompt, "texture": False, "pbr": False}
        if request.face_limit is not None:
            payload["face_limit"] = request.face_limit
        submitted = _json_request(
            f"{self.base_url}/task", method="POST", headers=self.headers, payload=payload,
            timeout=deadline - time.monotonic(),
        )
        task_id = _task_id((submitted.get("data") or {}).get("task_id"))
        result: dict[str, Any] = {}
        while time.monotonic() < deadline:
            observed = _json_request(f"{self.base_url}/task/{task_id}", headers=self.headers,
                                     timeout=deadline - time.monotonic())
            data = observed.get("data") or {}
            status = str(data.get("status") or "").lower()
            if status in {"success", "succeeded"}:
                result = data
                break
            if status in {"failed", "cancelled", "canceled"}:
                raise ProviderError(f"Tripo task {task_id} failed")
            time.sleep(min(5, max(0, deadline - time.monotonic())))
        if not result:
            raise ProviderError(f"Tripo task {task_id} timed out")
        output = result.get("output") or {}
        model_url = output.get("model") or output.get("pbr_model") or output.get("base_model")
        if not model_url:
            raise ProviderError(f"Tripo task {task_id} returned no model URL")
        _https_url(str(model_url), self.download_hosts)
        content = _fetch(str(model_url), timeout=deadline - time.monotonic())
        _write_glb(request.output, content)
        return {"provider": self.name, "task_id": task_id, "status": "succeeded",
                "sha256": hashlib.sha256(content).hexdigest(), "output": str(request.output)}


class HunyuanBridgeProvider(Provider):
    """Thin HTTP bridge for Hunyuan submit/status/download.

    The bridge URL is deliberately configurable because Tencent's product and
    regional endpoints differ. It must expose POST /submit, GET /status/<id>,
    and GET /download/<id>; the API key remains local.
    """

    name = "hunyuan"

    def __init__(self, bridge_url: str | None = None, api_key: str | None = None) -> None:
        self.bridge_url = (bridge_url or os.environ.get("HUNYUAN_3D_BRIDGE_URL") or "").rstrip("/")
        self.api_key = api_key or os.environ.get("HUNYUAN_3D_API_KEY")
        if not self.bridge_url:
            raise ProviderError("HUNYUAN_3D_BRIDGE_URL is not set")
        if not self.api_key:
            raise ProviderError("HUNYUAN_3D_API_KEY is not set")
        _https_url(self.bridge_url)
        if urllib.parse.urlsplit(self.bridge_url).query:
            raise ProviderError("bridge base URL cannot contain a query")
        self.headers = {"Authorization": f"Bearer {self.api_key}"}

    def generate(self, request: GenerationRequest, timeout: int = 1200) -> dict[str, Any]:
        deadline = _preflight(request, timeout)
        submitted = _json_request(
            f"{self.bridge_url}/submit",
            method="POST",
            headers=self.headers,
            payload={"asset_id": request.asset_id, "prompt": request.prompt, "mode": "lowpoly"},
            timeout=deadline - time.monotonic(),
        )
        task_id = _task_id(submitted.get("task_id") or submitted.get("job_id"))
        while time.monotonic() < deadline:
            observed = _json_request(
                f"{self.bridge_url}/status/{task_id}", headers=self.headers,
                timeout=deadline - time.monotonic(),
            )
            status = str(observed.get("status") or observed.get("state") or "").lower()
            if status in {"success", "succeeded", "done"}:
                break
            if status in {"failed", "cancelled", "canceled"}:
                raise ProviderError(f"Hunyuan task {task_id} failed")
            time.sleep(min(5, max(0, deadline - time.monotonic())))
        else:
            raise ProviderError(f"Hunyuan task {task_id} timed out")
        content = _fetch(f"{self.bridge_url}/download/{task_id}", headers=self.headers,
                         timeout=deadline - time.monotonic())
        _write_glb(request.output, content)
        return {"provider": self.name, "task_id": task_id, "status": "succeeded",
                "sha256": hashlib.sha256(content).hexdigest(), "output": str(request.output)}


def provider_for(name: str) -> Provider:
    if name == "tripo":
        return TripoProvider()
    if name == "hunyuan":
        return HunyuanBridgeProvider()
    raise ProviderError(f"unknown provider: {name}")
