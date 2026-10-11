"""Offline contract tests for text-to-3D provider adapters."""
from __future__ import annotations

import hashlib
import io
import tempfile
import time
import unittest
import sys
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asset_providers

GLB = (Path(__file__).resolve().parents[1] / "project/assets/models/barrel.glb").read_bytes()


class Response(io.BytesIO):
    def __init__(self, payload: bytes) -> None:
        super().__init__(payload)
        self.headers = {"Content-Length": str(len(payload))}


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
                    patch.object(asset_providers._HTTP, "open", return_value=Response(GLB)):
                receipt = asset_providers.TripoProvider("secret", frozenset({"example.invalid"})).generate(request, timeout=1)
            self.assertEqual(receipt["task_id"], "tripo-1")
            self.assertEqual(output.read_bytes(), GLB)

    def test_hunyuan_bridge_normalizes_job_id(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "asset.glb"
            request = asset_providers.GenerationRequest("fixture", "低多边形构件", 400, output)
            responses = [{"job_id": "hy-1"}, {"status": "done"}]
            with patch.object(asset_providers, "_json_request", side_effect=responses), \
                    patch.object(asset_providers._HTTP, "open", return_value=Response(GLB)):
                receipt = asset_providers.HunyuanBridgeProvider("https://bridge.invalid", "secret").generate(
                    request, timeout=1
                )
            self.assertEqual(receipt["task_id"], "hy-1")
            self.assertEqual(output.read_bytes(), GLB)

    def test_invalid_download_does_not_write(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.glb"
            for data in [b"glTF", b"<html>download failed</html>", GLB[:-1]]:
                with self.assertRaises(asset_providers.ProviderError):
                    asset_providers._write_glb(path, data)
                self.assertFalse(path.exists())

    def test_existing_draft_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.glb"
            path.write_bytes(b"original")
            with self.assertRaises(asset_providers.ProviderError):
                asset_providers._write_glb(path, GLB)
            self.assertEqual(path.read_bytes(), b"original")

    def test_no_implicit_triangle_cap(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.glb"
            responses = [{"data": {"task_id": "task-1"}},
                         {"data": {"status": "success", "output": {"model": "https://example.invalid/a.glb"}}}]
            with patch.object(asset_providers, "_json_request", side_effect=responses) as api, \
                    patch.object(asset_providers._HTTP, "open", return_value=Response(GLB)):
                asset_providers.TripoProvider("secret", frozenset({"example.invalid"})).generate(asset_providers.GenerationRequest("a", "test", None, path))
            self.assertNotIn("face_limit", api.call_args_list[0].kwargs["payload"])

    def test_failed_task_never_downloads(self) -> None:
        responses = [{"data": {"task_id": "task-1"}}, {"data": {"status": "failed"}}]
        with patch.object(asset_providers, "_json_request", side_effect=responses), \
                patch.object(asset_providers._HTTP, "open") as download:
            with self.assertRaises(asset_providers.ProviderError):
                asset_providers.TripoProvider("secret", frozenset({"example.invalid"})).generate(asset_providers.GenerationRequest("a", "test", None, Path("unused.glb")))
            download.assert_not_called()

    def test_untrusted_download_never_opens(self) -> None:
        urls = ["file:///secret", "http://example.invalid/a", "https://evil.invalid/a",
                "https://example.invalid.evil.invalid/a", "https://user:pw@example.invalid/a"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.glb"
            for url in urls:
                with self.subTest(url=url):
                    responses = [{"data": {"task_id": "task-1"}},
                                 {"data": {"status": "success", "output": {"model": url}}}]
                    with patch.object(asset_providers, "_json_request", side_effect=responses), \
                            patch.object(asset_providers._HTTP, "open") as download:
                        with self.assertRaises(asset_providers.ProviderError):
                            asset_providers.TripoProvider("secret", frozenset({"example.invalid"})).generate(
                                asset_providers.GenerationRequest("a", "test", None, path))
                        download.assert_not_called()
                    self.assertFalse(path.exists())

    def test_missing_allowlist_never_submits(self) -> None:
        with patch.object(asset_providers, "_json_request") as api:
            with self.assertRaises(asset_providers.ProviderError):
                asset_providers.TripoProvider("secret", frozenset()).generate(
                    asset_providers.GenerationRequest("a", "test", None, Path("unused.glb")))
            api.assert_not_called()

    def test_existing_output_never_submits(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.glb"
            path.write_bytes(b"keep")
            with patch.object(asset_providers, "_json_request") as api:
                with self.assertRaises(asset_providers.ProviderError):
                    asset_providers.TripoProvider("secret", frozenset({"example.invalid"})).generate(
                        asset_providers.GenerationRequest("a", "test", None, path))
                api.assert_not_called()
            self.assertEqual(path.read_bytes(), b"keep")

    def test_bridge_rejects_insecure_url(self) -> None:
        for url in ["http://bridge.invalid", "file:///tmp/a", "https://bridge.invalid?secret=x"]:
            with self.assertRaises(asset_providers.ProviderError):
                asset_providers.HunyuanBridgeProvider(url, "secret")

    def test_redirect_never_forwards_credentials(self) -> None:
        request = urllib.request.Request("https://bridge.invalid/download", headers={"Authorization": "Bearer secret"})
        with self.assertRaises(asset_providers.ProviderError):
            asset_providers._NoRedirect().redirect_request(request, None, 302, "Found", {}, "https://evil.invalid")
        self.assertTrue(any(isinstance(h, asset_providers._NoRedirect) for h in asset_providers._HTTP.handlers))

    def test_oversized_and_truncated_responses_are_rejected(self) -> None:
        responses = [Response(b"abcdef"), Response(b"abcdef"), Response(b"abc")]
        responses[1].headers = {}
        responses[2].headers = {"Content-Length": "4"}
        for response in responses:
            with self.assertRaises(asset_providers.ProviderError):
                asset_providers._read_limited(response, 4, time.monotonic() + 2)

    def test_failed_publication_leaves_no_draft(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.glb"
            with patch.object(asset_providers.os, "link", side_effect=OSError("disk error")):
                with self.assertRaises(OSError):
                    asset_providers._write_glb(path, GLB)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_http_error_is_redacted(self) -> None:
        url = "https://bridge.invalid/download?secret=signed"
        error = urllib.error.HTTPError(url, 403, "token=private", {}, io.BytesIO(b"secret response"))
        with patch.object(asset_providers._HTTP, "open", side_effect=error):
            with self.assertRaises(asset_providers.ProviderError) as caught:
                asset_providers._fetch(url)
            self.assertEqual(str(caught.exception), "provider HTTP status 403")

    def test_download_has_no_bearer_or_signed_url_in_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.glb"
            responses = [{"data": {"task_id": "task-1"}},
                         {"data": {"status": "success", "output": {"model": "https://example.invalid/a?signature=private"}}}]
            with patch.object(asset_providers, "_json_request", side_effect=responses), \
                    patch.object(asset_providers._HTTP, "open", return_value=Response(GLB)) as http:
                receipt = asset_providers.TripoProvider("secret", frozenset({"example.invalid"})).generate(
                    asset_providers.GenerationRequest("a", "test", None, path))
            self.assertIsNone(http.call_args.args[0].get_header("Authorization"))
            self.assertNotIn("private", str(receipt))
            self.assertEqual(receipt["sha256"], hashlib.sha256(GLB).hexdigest())

    def test_unknown_provider_fails_closed(self) -> None:
        with self.assertRaises(asset_providers.ProviderError):
            asset_providers.provider_for("unknown")


if __name__ == "__main__":
    unittest.main()
