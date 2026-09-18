"""Local developer commands for Mist Harbor; Python 3.11+ and Godot 4.4."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'project'
# Exports live outside the Godot project: inside it the editor would import the
# exported .png/.wasm sidecars as project resources on every scan.
BUILD = ROOT / 'build'

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

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['import', 'test', 'editor', 'run', 'export-web', 'preview', 'package'])
    parser.add_argument('--godot', help='Godot executable path; overrides local configuration')
    parser.add_argument('--port', type=int, default=8188)
    args = parser.parse_args()
    if args.action == 'preview':
        web = BUILD
        if not (web / 'index.html').is_file():
            parser.error('No Web export yet. Run export-web first.')
        return subprocess.call([sys.executable, '-m', 'http.server', str(args.port), '--bind', '127.0.0.1', '--directory', str(web)])
    if args.action == 'package':
        command = [sys.executable, str(ROOT / 'package_sample.py'), '--output', str(ROOT / '.codebuddy/releases')]
        if (BUILD / 'index.wasm').is_file():
            command += ['--web-dir', str(BUILD)]
        return subprocess.call(command, cwd=ROOT)
    binary = engine(args.godot)
    if args.action in {'editor', 'run'}:
        command = [binary, '--path', str(PROJECT)]
        if args.action == 'editor': command.append('--editor')
        return subprocess.call(command, cwd=ROOT)
    invoke(binary, ['--editor', '--import', '--quit'], 'import', isolated=args.action == 'test')
    if args.action == 'test':
        model = invoke(binary, ['--script', 'res://tests/test_world.gd'], 'model-tests', isolated=True)
        scene = invoke(binary, ['--script', 'res://tests/smoke_scene.gd'], 'scene-tests', isolated=True)
        if 'WORLD_TEST_RESULT passed=42 failed=0' not in model or 'SCENE_SMOKE_RESULT failed=0' not in scene:
            raise RuntimeError('Expected baseline test summaries missing; check logs before changing assertions.')
    elif args.action == 'export-web':
        web = BUILD
        web.mkdir(exist_ok=True)
        invoke(binary, ['--export-release', 'Web', str(web / 'index.html')], 'web-export')
        if not all((web / name).is_file() for name in ['index.html', 'index.js', 'index.pck', 'index.wasm']):
            raise RuntimeError('Export completed without required Web artifacts')
    return 0

if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
