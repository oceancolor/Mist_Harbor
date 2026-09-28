"""Offline contract tests for text-to-3D provider adapters."""
from __future__ import annotations

import tempfile
import unittest
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asset_providers


class Response:
    def __init__(self, payload: bytes) -> None:
        self.payload = payload

    def __enter__(self) -> "Response":
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def read(self) -> bytes:
        return self.payload


class ProviderTests(unittest.TestCase):
    def test_tripo_normalizes_submit_poll_download(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "asset.glb"
            request = asset_providers.GenerationRequest("fixture", "low-poly fixture", 240, output)
            responses = [
                {"data": {"task_id": "tripo-1"}},
                {"data": {"status": "success", "output": {"model": "https://example.invalid/model.glb"}}},
            ]
            with patch.object(asset_providers, "_json_request", side_effect=responses), \
                    patch("urllib.request.urlopen", return_value=Response(b"glTF")):
                receipt = asset_providers.TripoProvider("secret").generate(request, timeout=1)
            self.assertEqual(receipt["task_id"], "tripo-1")
            self.assertEqual(output.read_bytes(), b"glTF")

    def test_hunyuan_bridge_normalizes_job_id(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "asset.glb"
            request = asset_providers.GenerationRequest("fixture", "低多边形构件", 400, output)
            responses = [{"job_id": "hy-1"}, {"status": "done"}]
            with patch.object(asset_providers, "_json_request", side_effect=responses), \
                    patch("urllib.request.urlopen", return_value=Response(b"glTF")):
                receipt = asset_providers.HunyuanBridgeProvider("http://bridge.invalid", "secret").generate(
                    request, timeout=1
                )
            self.assertEqual(receipt["task_id"], "hy-1")
            self.assertEqual(output.read_bytes(), b"glTF")

    def test_unknown_provider_fails_closed(self) -> None:
        with self.assertRaises(asset_providers.ProviderError):
            asset_providers.provider_for("unknown")


if __name__ == "__main__":
    unittest.main()
