"""Extend the UI font without changing how existing text renders.

The shipped subset (tools/fonts/harbor-sc-base.ttf) has its own outlines: glyphs
there are marginally wider than a fresh subset of Noto Sans SC, and re-subsetting
everything visibly changes weight and spacing. So this script

  1. collects every character the game may render,
  2. keeps the base font untouched,
  3. subsets ONLY the characters the base font lacks from the source font,
  4. merges them in.

Run with the venv that has fonttools:
  E:/Mist_Harbor/.venv-mcp/Scripts/python.exe tools/build_font_corpus.py

Source font (OFL 1.1): .codebuddy/local/NotoSansSC.ttf,
also at F:/web-cb/.codebuddy/tools/NotoSansSC.ttf,
download https://fonts.google.com/noto/specimen/Noto+Sans+SC
"""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project"
LOCAL = ROOT / ".codebuddy" / "local"
BASE = ROOT / "tools" / "fonts" / "harbor-sc-base.ttf"
FONT_OUT = PROJECT / "assets" / "fonts" / "harbor-sc.ttf"
FONT_SOURCES = [LOCAL / "NotoSansSC.ttf", Path("F:/web-cb/.codebuddy/tools/NotoSansSC.ttf")]

TEXT_SOURCES = (
    list((PROJECT / "data").glob("*.json"))
    + list((PROJECT / "scripts").glob("*.gd"))
    + [ROOT / "README.md", ROOT / "START_HERE.txt", ROOT / "tutorial.yaml",
       ROOT / "learning_tasks.json", PROJECT / "docs" / "learning-guide.md",
       PROJECT / "docs" / "requirements.md"]
)


def build_corpus() -> set[str]:
    chars: set[str] = set()
    for source in TEXT_SOURCES:
        if source.is_file():
            chars.update(source.read_text(encoding="utf-8"))
    for code in range(0x20, 0x7F):
        chars.add(chr(code))
    chars.update("·、。，：；！？（）—…「」『』～％＋－×÷°℃〇一二三四五六七八九十百千万亿零")
    chars.update("衣食住行读写存取开始结束现在过去未来上下左右前后内外大小多少新旧快慢章节智")
    return chars


LAYOUT_TABLES = ("GDEF", "GSUB", "GPOS", "HVAR", "VVAR", "MVAR", "STAT", "MATH", "BASE", "avar", "fvar", "gvar")
INSTANCE_WEIGHT = 400.0


def _strip_layout_tables(*paths: Path) -> list[str]:
    """Save copies without OpenType layout tables so Merger() accepts them."""
    from fontTools.ttLib import TTFont

    results: list[str] = []
    for index, path in enumerate(paths):
        font = TTFont(path)
        for tag in LAYOUT_TABLES:
            if tag in font:
                del font[tag]
        target = LOCAL / f"font-merge-{index}.ttf"
        font.save(target)
        results.append(str(target))
    return results


def main() -> None:
    from fontTools.ttLib import TTFont

    if not BASE.is_file():
        raise SystemExit(f"base font missing: {BASE}")
    chars = build_corpus()
    base_font = TTFont(BASE)
    base_cmap = base_font.getBestCmap()
    # Control characters (tab/newline) are not renderable glyphs.
    missing = sorted(ch for ch in chars if ord(ch) >= 0x20 and ord(ch) not in base_cmap)

    LOCAL.mkdir(parents=True, exist_ok=True)
    (LOCAL / "font-corpus.txt").write_text("".join(sorted(chars)), encoding="utf-8")

    if not missing:
        shutil.copyfile(BASE, FONT_OUT)
        print(f"base font already covers all {len(chars)} chars; copied to {FONT_OUT}")
        return

    source = next((path for path in FONT_SOURCES if path.is_file()), None)
    if source is None:
        raise SystemExit("source font not found; see the header of this script")

    from fontTools import subset
    from fontTools.merge import Merger

    # NotoSansSC.ttf is a variable font; instance it at the same weight as the
    # base subset, otherwise Merger() trips over gvar/VarStore.
    static = LOCAL / "font-static.ttf"
    source_font = TTFont(source)
    if "fvar" in source_font:
        from fontTools.varLib import instancer

        source_font = instancer.instantiateVariableFont(source_font, {"wght": INSTANCE_WEIGHT})
    source_font.save(static)

    extra = LOCAL / "font-extra.ttf"
    subset.main([
        str(static),
        f"--text={''.join(missing)}",
        f"--output-file={extra}",
        "--no-hinting", "--glyph-names", "--notdef-outline",
    ])
    # fontTools 4.65 fails to merge GDEF/GSUB/GPOS here; a CJK UI font needs none
    # of them, so both sides are stripped before merging.
    merged = Merger().merge(_strip_layout_tables(BASE, extra))
    merged.save(FONT_OUT)

    check = TTFont(FONT_OUT)
    still_missing = [ch for ch in missing if ord(ch) not in check.getBestCmap()]
    print(f"base {BASE.name}: added {len(missing)} glyph(s); still missing: {still_missing or 'none'}")
    print(f"font -> {FONT_OUT} ({FONT_OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
