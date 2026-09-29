"""Local developer commands for Mist Harbor; Python 3.11+ and Godot 4.4."""
from __future__ import annotations
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'project'
# Exports live outside the Godot project: inside it the editor would import the
# exported .png/.wasm sidecars as project resources on every scan.
BUILD = ROOT / 'build'
BUILD_WIN = ROOT / 'build-win'

def engine(explicit):
    local = ROOT / '.codebuddy/local/tools.json'
    config = json.loads(local.read_text(encoding='utf-8')) if local.is_file() else {}
    value = explicit or os.environ.get('MIST_HARBOR_GODOT') or os.environ.get('GODOT_BIN') or config.get('godot')
    value = value or shutil.which('godot') or shutil.which('godot4')
    if not value:
        raise RuntimeError('Specify --godot PATH, MIST_HARBOR_GODOT, or .codebuddy/local/tools.json (Godot 4.4).')
    executable = Path(value).expanduser()
    if not executable.is_file():
        raise RuntimeError(f'Godot not found: {executable}')
    return str(executable.resolve())

def invoke(executable, arguments, label, isolated=False):
    env = os.environ.copy()
    if isolated:
        # Tests must not load the player's existing desktop save.
        test_user = ROOT / '.codebuddy/local/test-user'
        test_user.mkdir(parents=True, exist_ok=True)
        env['APPDATA'] = str(test_user)
        env['XDG_DATA_HOME'] = str(test_user)
    result = subprocess.run([executable, '--headless', '--path', str(PROJECT), *arguments],
                            capture_output=True, timeout=300, env=env)
    log_dir = ROOT / 'logs'
    log_dir.mkdir(exist_ok=True)
    text = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    (log_dir / (label + '.log')).write_text(text, encoding='utf-8')
    print(text)
    if result.returncode or 'SCRIPT ERROR:' in text:
        raise RuntimeError(f'{label} failed; see logs/{label}.log (exit={result.returncode})')
    return text

def newest_source_time():
    """Newest mtime across scripts/scenes/data — used to detect stale exports."""
    latest = 0.0
    for folder in ['scripts', 'data', 'tests']:
        for path in (PROJECT / folder).rglob('*'):
            if path.is_file() and path.suffix in {'.gd', '.json', '.tscn', '.gdshader'}:
                latest = max(latest, path.stat().st_mtime)
    scene = PROJECT / 'main.tscn'
    if scene.is_file():
        latest = max(latest, scene.stat().st_mtime)
    return latest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['import', 'test', 'editor', 'run', 'export-web', 'export-windows', 'preview', 'package'])
    parser.add_argument('--godot', help='Godot executable path; overrides local configuration')
    parser.add_argument('--port', type=int, default=8188)
    args = parser.parse_args()
    if args.action == 'preview':
        web = BUILD
        if not (web / 'index.html').is_file():
            parser.error('No Web export yet. Run export-web first.')

        # 带 no-cache 头的静态服务：浏览器不再缓存 index.pck/wasm——
        # 否则重新导出后普通刷新仍跑旧包（2026-09-27 幽灵错位"修了没生效"的元凶）。
        import http.server
        import functools

        class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
            def end_headers(self):
                self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
                self.send_header('Pragma', 'no-cache')
                self.send_header('Expires', '0')
                super().end_headers()

        handler = functools.partial(NoCacheHandler, directory=str(web))
        server = http.server.ThreadingHTTPServer(('127.0.0.1', args.port), handler)
        print(f'preview: http://127.0.0.1:{args.port}/index.html  (no-cache)')
        try:
            return server.serve_forever()
        except KeyboardInterrupt:
            return 0
    if args.action == 'package':
        command = [sys.executable, str(ROOT / 'package_sample.py'), '--output', str(ROOT / '.codebuddy/releases')]
        if (BUILD / 'index.wasm').is_file():
            command += ['--web-dir', str(BUILD)]
        return subprocess.call(command, cwd=ROOT)
    binary = engine(args.godot)
    # 🔴 R-ENG-18（新增）：.godot/exported/ 的脚本编译缓存**不随 .gd 修改而失效**，
    # 导出会静默打包旧脚本（2026-09-26 事故：连续多次导出都是旧代码，观感"时灵时不灵"）。
    # 导出/测试前强制清掉该缓存；imported/（资源导入缓存）保留以免全量重导。
    if args.action in {'export-web', 'export-windows'}:
        shutil.rmtree(PROJECT / '.godot' / 'exported', ignore_errors=True)
    if args.action in {'editor', 'run'}:
        command = [binary, '--path', str(PROJECT)]
        if args.action == 'editor': command.append('--editor')
        return subprocess.call(command, cwd=ROOT)
    invoke(binary, ['--editor', '--import', '--quit'], 'import', isolated=args.action == 'test')
    if args.action == 'test':
        model = invoke(binary, ['--script', 'res://tests/test_world.gd'], 'model-tests', isolated=True)
        scene = invoke(binary, ['--script', 'res://tests/smoke_scene.gd'], 'scene-tests', isolated=True)
        # Parse the summaries instead of hard-coding a count: assertions grow with the
        # game, and a frozen number turns every new test into a false failure.
        model_summary = re.search(r'WORLD_TEST_RESULT passed=(\d+) failed=(\d+)', model)
        scene_summary = re.search(r'SCENE_SMOKE_RESULT failed=(\d+)', scene)
        if model_summary is None or scene_summary is None:
            raise RuntimeError('Expected baseline test summaries missing; check logs before changing assertions.')
        model_passed = int(model_summary.group(1))
        if int(model_summary.group(2)) or int(scene_summary.group(1)):
            raise RuntimeError('Test failures reported; see logs/model-tests.log and logs/scene-tests.log')
        if model_passed <= 0:
            raise RuntimeError('Model tests reported zero assertions; the suite did not really run')
        print(f'test summary: model passed={model_passed}, scene failed=0')
    elif args.action == 'export-web':
        web = BUILD
        web.mkdir(exist_ok=True)
        invoke(binary, ['--export-release', 'Web', str(web / 'index.html')], 'web-export')
        if not all((web / name).is_file() for name in ['index.html', 'index.js', 'index.pck', 'index.wasm']):
            raise RuntimeError('Export completed without required Web artifacts')
        if (web / 'index.pck').stat().st_mtime < newest_source_time():
            raise RuntimeError('index.pck is older than the newest source file; the export was stale')
    elif args.action == 'export-windows':
        windows = BUILD_WIN
        windows.mkdir(exist_ok=True)
        invoke(binary, ['--export-release', 'Windows Desktop', str(windows / 'mist-harbor.exe')], 'windows-export')
        # The preset embeds the pck, so a single self-contained exe is the whole build.
        if not (windows / 'mist-harbor.exe').is_file():
            raise RuntimeError('Export completed without the Windows executable')
    return 0

if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
