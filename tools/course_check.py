"""Validate the course: media references, shot plan coverage, chapter front matter.

Usage: python tools/course_check.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSE = ROOT / "course"
SHOTS = COURSE / "media" / "shots"
CHAPTERS = COURSE / "chapters"

MARKDOWN_IMAGE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")
BACKTICK_NAME = re.compile(r"`([^`\s]*\.(?:png|svg))`")


def planned_shots() -> dict[str, set[str]]:
    """chapter key -> shot file names declared in the shot plan."""
    import json

    path = COURSE / "media" / "shots.json"
    if not path.is_file():
        return {}
    plan = json.loads(path.read_text(encoding="utf-8"))
    return {chapter: {step["shot"] for step in steps if "shot" in step}
            for chapter, steps in plan.items()}


def chapter_key(path: Path) -> str:
    """vol0-01.md -> 01"""
    return path.stem.split("-")[-1]


def main() -> int:
    problems: list[str] = []
    chapters = sorted(CHAPTERS.glob("*.md"))
    if not chapters:
        problems.append("no chapters found")

    shots = planned_shots()
    for chapter in chapters:
        text = chapter.read_text(encoding="utf-8")
        for reference in MARKDOWN_IMAGE.findall(text):
            if reference.startswith("http"):
                continue
            if not (chapter.parent / reference).resolve().exists():
                problems.append(f"{chapter.name}: missing diagram {reference}")
        # Names in the 配图清单 tables must come from the shot plan; anything else
        # (e.g. log output mentioning index.png) is prose and ignored.
        declared = shots.get(chapter_key(chapter), set())
        for name in BACKTICK_NAME.findall(text):
            if name in declared:
                continue
            if name.startswith(("01-", "02-", "03-", "04-")) and name.endswith(".png"):
                problems.append(f"{chapter.name}: {name} is not declared in shots.json")

    if (COURSE / "media" / "shots.json").is_file():
        import json

        plan = json.loads((COURSE / "media" / "shots.json").read_text(encoding="utf-8"))
        for chapter, steps in plan.items():
            for step in steps:
                if "shot" not in step or step.get("manual"):
                    continue
                target = SHOTS / chapter / step["shot"]
                if not target.exists():
                    problems.append(f"shots.json[{chapter}]: not captured yet: {step['shot']}")
    else:
        problems.append("missing course/media/shots.json")

    total = sum(len(p.read_text(encoding="utf-8")) for p in chapters)
    print(f"chapters={len(chapters)}  characters={total}")
    for chapter in chapters:
        print(f"  {chapter.name}: {len(chapter.read_text(encoding='utf-8'))}")
    if problems:
        print("\nPROBLEMS:")
        for problem in problems:
            print("  -", problem)
        return 1
    print("\nall course media references resolve")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
