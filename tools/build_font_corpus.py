"""Rebuild the subsetted UI font after any Chinese copy change.

1. Collect every character the game may render (data JSON + all GDScript).
2. Subset the source font (Noto Sans SC, OFL) down to those characters.

Run with the venv that has fonttools installed:
  E:/Mist_Harbor/.venv-mcp/Scripts/python.exe tools/build_font_corpus.py

Source font search order:
  .codebuddy/local/NotoSansSC.ttf  ->  F:/web-cb/.codebuddy/tools/NotoSansSC.ttf
Download: https://fonts.google.com/noto/specimen/Noto+Sans+SC (OFL 1.1)
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project"
LOCAL = ROOT / ".codebuddy" / "local"
OUT = LOCAL / "font-corpus.txt"
FONT_OUT = PROJECT / "assets" / "fonts" / "harbor-sc.ttf"
FONT_SOURCES = [LOCAL / "NotoSansSC.ttf", Path("F:/web-cb/.codebuddy/tools/NotoSansSC.ttf")]

SOURCES = list((PROJECT / "data").glob("*.json")) + list((PROJECT / "scripts").glob("*.gd"))


def build_corpus() -> set[str]:
    chars: set[str] = set()
    for source in SOURCES:
        chars.update(source.read_text(encoding="utf-8"))
    for code in range(0x20, 0x7F):
        chars.add(chr(code))
    chars.update("·、。，：；！？（）—…「」『』～％＋－×÷°℃〇一二三四五六七八九十百千万亿零")
    chars.update("衣食住行读写存取开始结束现在过去未来上下左右前后内外大小多少新旧快慢章节智")
    return chars


def subset_font(chars: set[str]) -> None:
    source = next((path for path in FONT_SOURCES if path.is_file()), None)
    if source is None:
        raise SystemExit("source font not found; see the header of this script")
    from fontTools import subset  # noqa: PLC0415 - optional dependency

    LOCAL.mkdir(parents=True, exist_ok=True)
    OUT.write_text("".join(sorted(chars)), encoding="utf-8")
    arguments = [
        str(source),
        f"--text-file={OUT}",
        f"--output-file={FONT_OUT}",
        "--layout-features=*",
        "--glyph-names",
        "--notdef-outline",
    ]
    subset.main(arguments)


def main() -> None:
    chars = build_corpus()
    if "--corpus-only" not in sys.argv:
        subset_font(chars)
    OUT.write_text("".join(sorted(chars)), encoding="utf-8")
    print(f"{len(chars)} unique chars; font -> {FONT_OUT} ({FONT_OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
