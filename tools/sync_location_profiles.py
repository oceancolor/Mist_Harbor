"""Synchronize runtime water/light values from the current strategy source tables.

Without --write this checks drift and exits nonzero. Experimental camera, surf,
geometry and geo-meta settings remain untouched. Historical tables are excluded.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "strategy" / "water-lighting-params.md"
LOCATIONS = ["quanzhou", "santorini", "cape-cod", "seychelles"]


def table(text: str, anchor: str) -> list[list[str]]:
    part = text[text.index(anchor) + len(anchor):]
    rows = []
    for line in part.splitlines():
        if line.startswith("|"):
            rows.append([column.strip() for column in line.strip("|").split("|")])
        elif rows:
            break
    if len(rows) < 3:
        raise ValueError(f"missing source table: {anchor}")
    return rows[2:]


def value(rows: list[list[str]], label: str, column: int):
    matches = [row for row in rows if re.search(label, row[0]) and "~~" not in row[0]]
    if len(matches) != 1:
        raise ValueError(f"source field must be unique: {label}, matches={len(matches)}")
    raw = matches[0][column + 1]
    color = re.search(r"#[0-9a-fA-F]{6}", raw)
    if color:
        return color.group()[1:]
    number = re.search(r"[−-]?\d+(?:\.\d+)?", raw.replace("~~", ""))
    if number:
        return float(number.group().replace("−", "-"))
    raise ValueError(f"missing scalar: {raw}")


def expected(text: str, column: int) -> dict:
    water = table(text, "## 3. 水体参数")
    day = table(text, "## 4. DirectionalLight3D")
    dawn = table(text, "**晨态光照表")
    night = table(text, "**夜态光照表")
    fog = table(text, "## 5.")
    sunset = table(text, "游戏已有 N 键昼夜切换。")
    result = {"water": {}, "day": {}, "morning": {}, "night": {}, "sunset": {}, "fog": {}}
    for field in ["deep_color", "shallow_color", "shallow_radius", "deep_radius", "transparency", "foam_color", "foam_width", "wave_scale", "wave_speed", "wave_normal_strength"]:
        result["water"][field] = value(water, rf"`{field}`", column)
    result["water"]["lagoon_color"] = "4FD8C0" if column == 3 else result["water"]["shallow_color"]
    result["water"]["lagoon_radius"] = 10.0 if column == 3 else 0.0
    for group, rows in [("day", day), ("morning", dawn), ("night", night)]:
        for field in ["light_color", "light_energy"]:
            result[group][field] = value(rows, rf"`{field}`", column)
        if group != "night":
            for field in ["shadow_blur", "shadow_opacity"]:
                result[group][field] = value(rows, rf"^`{field}`", column)
        if group != "day":
            result[group]["ambient"] = value(rows, "`ambient_light_energy`", column)
            for field in ["sky_top", "sky_horizon"]:
                result[group][field] = value(rows, rf"`{field}`", column)
    result["day"]["sun_rotation_x"] = value(day, "`rotation_degrees.x`", column)
    for field in ["sun_color", "light_energy"]:
        result["sunset"][field] = value(sunset, rf"`{field}`", column)
    result["sunset"]["sky_top"] = value(sunset, r"^天空顶", column)
    result["sunset"]["sky_horizon"] = value(sunset, r"^天空地平线", column)
    result["sunset"]["ambient"] = value(sunset, "`sunset_ambient`", column)
    for target, pattern in [("density_day", "fog_density.*昼档"), ("density_night", "fog_density.*夜档"), ("light_color", "fog_light_color.*昼 / 日落"), ("night_floor", "fog_light_color.*夜，不派生"), ("aerial_perspective", "`fog_aerial_perspective`")]:
        result["fog"][target] = value(fog, pattern, column)
    result["day"]["ambient"] = value(fog, "`ambient_light_energy`", column)
    result["day"]["tonemap_exposure"] = value(fog, "`tonemap_exposure`", column)
    result["fog"]["density_weather"] = 0.0075 if column == 2 else 0.0
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    text = SOURCE.read_text(encoding="utf-8")
    changes = []
    for index, location in enumerate(LOCATIONS):
        path = ROOT / "project" / "data" / "locations" / f"{location}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        for group, fields in expected(text, index).items():
            for field, target in fields.items():
                actual = data.setdefault(group, {}).get(field)
                if isinstance(actual, str):
                    actual = actual.lstrip("#")
                if actual != target:
                    changes.append(f"{location}.{group}.{field}: {actual} -> {target}")
                    data[group][field] = target
        if location == "cape-cod":
            for field, target in {"weather_kind": "fog", "weather_label": "海雾"}.items():
                if data.get(field) != target:
                    changes.append(f"{location}.{field}: {data.get(field)} -> {target}")
                    data[field] = target
        if args.write:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("\n".join(changes) if changes else "Water/light profile tables match strategy source")
    if changes and not args.write:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
