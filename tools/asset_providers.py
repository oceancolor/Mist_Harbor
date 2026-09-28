"""Text-to-3D providers used by Mist Harbor's asset pipeline.

Secrets are read from environment variables only. Generated files are downloaded
immediately because upstream retention windows are short. Provider responses are
normalized to a small submit/poll/download contract so downstream Blender QA is
identical for Tripo and Hunyuan.
"""
from __future__ import annotations

import json
import os
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class ProviderError(RuntimeError):
    pass


def _json_request(url: str, *, method: str = "GET", headers: dict[str, str] | None = None,
                  payload: dict[str, Any] | None = None, timeout: int = 120) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    request_headers = {"Accept": "application/json", **(headers or {})}
    if body is not None:
        request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=body, headers=request_headers, method=method)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        parsed = json.loads(response.read().decode("utf-8"))
    if not isinstance(parsed, dict):
        raise ProviderError(f"unexpected response from {url}")
    return parsed


@dataclass(frozen=True)
class GenerationRequest:
    asset_id: str
    prompt: str
    face_limit: int
    output: Path


class Provider:
    name = "provider"

    def generate(self, request: GenerationRequest, timeout: int = 900) -> dict[str, Any]:
        raise NotImplementedError


class TripoProvider(Provider):
    """Tripo OpenAPI v2 text-to-model adapter."""

    name = "tripo"
    base_url = "https://api.tripo3d.ai/v2/openapi"

    def __init__(self, secret: str | None = None) -> None:
        self.secret = secret or os.environ.get("TRIPO_API_SECRET") or os.environ.get("TRIPO_API_KEY")
        if not self.secret:
            raise ProviderError("TRIPO_API_SECRET is not set")
        self.headers = {"Authorization": f"Bearer {self.secret}"}

    def generate(self, request: GenerationRequest, timeout: int = 900) -> dict[str, Any]:
        submitted = _json_request(
            f"{self.base_url}/task",
            method="POST",
            headers=self.headers,
            payload={
                "type": "text_to_model",
                "prompt": request.prompt,
                "face_limit": request.face_limit,
                "texture": False,
                "pbr": False,
            },
        )
        task_id = str((submitted.get("data") or {}).get("task_id") or "")
        if not task_id:
            raise ProviderError(f"Tripo submit failed: {submitted}")
        deadline = time.monotonic() + timeout
        result: dict[str, Any] = {}
        while time.monotonic() < deadline:
            observed = _json_request(f"{self.base_url}/task/{urllib.parse.quote(task_id)}", headers=self.headers)
            data = observed.get("data") or {}
            status = str(data.get("status") or "").lower()
            if status in {"success", "succeeded"}:
                result = data
                break
            if status in {"failed", "cancelled", "canceled"}:
                raise ProviderError(f"Tripo task {task_id} failed: {observed}")
            time.sleep(5)
        if not result:
            raise ProviderError(f"Tripo task {task_id} timed out")
        output = result.get("output") or {}
        model_url = output.get("model") or output.get("pbr_model") or output.get("base_model")
        if not model_url:
            raise ProviderError(f"Tripo task {task_id} returned no model URL")
        request.output.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(str(model_url), timeout=300) as response:
            request.output.write_bytes(response.read())
        return {"provider": self.name, "task_id": task_id, "status": "succeeded",
                "model_url": str(model_url), "output": str(request.output)}


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
        self.headers = {"Authorization": f"Bearer {self.api_key}"}

    def generate(self, request: GenerationRequest, timeout: int = 1200) -> dict[str, Any]:
        submitted = _json_request(
            f"{self.bridge_url}/submit",
            method="POST",
            headers=self.headers,
            payload={"asset_id": request.asset_id, "prompt": request.prompt, "mode": "lowpoly"},
        )
        task_id = str(submitted.get("task_id") or submitted.get("job_id") or "")
        if not task_id:
            raise ProviderError(f"Hunyuan bridge submit failed: {submitted}")
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            observed = _json_request(
                f"{self.bridge_url}/status/{urllib.parse.quote(task_id)}", headers=self.headers
            )
            status = str(observed.get("status") or observed.get("state") or "").lower()
            if status in {"success", "succeeded", "done"}:
                break
            if status in {"failed", "cancelled", "canceled"}:
                raise ProviderError(f"Hunyuan task {task_id} failed: {observed}")
            time.sleep(5)
        else:
            raise ProviderError(f"Hunyuan task {task_id} timed out")
        download = urllib.request.Request(
            f"{self.bridge_url}/download/{urllib.parse.quote(task_id)}", headers=self.headers
        )
        request.output.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(download, timeout=300) as response:
            request.output.write_bytes(response.read())
        return {"provider": self.name, "task_id": task_id, "status": "succeeded",
                "output": str(request.output)}


def provider_for(name: str) -> Provider:
    if name == "tripo":
        return TripoProvider()
    if name == "hunyuan":
        return HunyuanBridgeProvider()
    raise ProviderError(f"unknown provider: {name}")
