"""Machine-verifiable subset of the four-location acceptance checklist.

This script intentionally leaves visual items pending; acceptance-checklist.md
requires Benja's sign-off for those and automation must not impersonate it.
"""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    locations = read_json(PROJECT / "data" / "locations.json")
    palette = read_json(PROJECT / "data" / "palette.json")
    objectives = read_json(PROJECT / "data" / "location_objectives.json")
    manifest = read_json(PROJECT / "assets" / "models" / "manifest.json")
    budgets = read_json(PROJECT / "data" / "asset_budgets.json")
    scripts = "\n".join(path.read_text(encoding="utf-8") for path in (PROJECT / "scripts").glob("*.gd"))
    profiles = {item["id"]: item for item in locations["locations"]}
    checks: list[dict] = []

    def check(name: str, condition: bool, evidence: str) -> None:
        checks.append({"name": name, "status": "pass" if condition else "fail", "evidence": evidence})

    check("four_location_profiles", set(profiles) == {"quanzhou", "santorini", "seychelles", "cape_cod"},
          ",".join(sorted(profiles)))
    check("location_verbs", [profiles[key]["verb"] for key in profiles] == ["连", "悬", "叠", "照"],
          "泉州=连, 圣托里尼=悬, 塞舌尔=叠, Cape Cod=照")
    expected_fog = {
        "quanzhou": (0.0040, 0.0050), "santorini": (0.0015, 0.0026),
        "cape_cod": (0.0036, 0.0058), "seychelles": (0.0010, 0.0018),
    }
    check("fog_density_unique_source",
          all((profiles[key]["fog_density_day"], profiles[key]["fog_density_night"]) == value
              for key, value in expected_fog.items()), str(expected_fog))
    check("cape_cod_weather_fog", profiles["cape_cod"].get("fog_density_weather") == 0.0075,
          "fog_density_weather=0.0075")
    check("seychelles_three_band_water",
          profiles["seychelles"]["water"].get("lagoon_radius") == 10
          and profiles["seychelles"]["water"].get("shallow_radius") == 18
          and profiles["seychelles"]["water"].get("deep_radius") == 24,
          "lagoon=10, shallow=18, deep=24")
    check("four_phase_channels",
          all(set(item["environment"]) == {"dawn", "day", "sunset", "night"} for item in profiles.values()),
          "all profiles contain four named phases")
    check("six_direction_rule_engine", "DIRECTIONS" in scripts and "Vector3i.UP" in scripts
          and "Vector3i.DOWN" in scripts, "expansion_rules.gd")
    expandable = [item for item in palette["items"] if item.get("expansion")]
    check("expandable_units", len(expandable) >= 12, f"{len(expandable)} palette units")
    check("no_runtime_point_lights", "OmniLight3D.new" not in scripts and "SpotLight3D.new" not in scripts,
          "no point/spot light constructors")
    check("fog_interference_disabled", "fog_height_density = 0.0" in scripts
          and "fog_sun_scatter = 0.0" in scripts, "build_world.gd")
    check("m1_m6_per_location",
          all(len(objectives["locations"].get(key, [])) == 6 for key in profiles),
          "6 objectives per location")
    check("location_save_isolation", '"user://%s_slot_%d.json"' in scripts,
          "world_model.gd location-prefixed slot path")
    assets = {entry["id"]: entry for entry in manifest["assets"]}
    files_exist = all((PROJECT / "assets" / "models" / entry["file"]).is_file() for entry in assets.values())
    check("manifest_files_exist", files_exist, f"{len(assets)} GLB files")
    budget_ok = all(entry["triangles"] <= budgets["assets"].get(asset_id, {"triangles": entry["triangles"]})["triangles"]
                    for asset_id, entry in assets.items())
    check("triangle_budgets", budget_ok, "manifest triangles <= configured budgets")
    check("web_share_fallback", "navigator.share" in scripts and "downloaded" in scripts,
          "Web Share API with download fallback")
    check("legacy_save_migration", "schema_version" in scripts and "[1, SAVE_VERSION]" in scripts,
          "schema v1 accepted, schema v2 emitted")

    manual = [
        "A-4 fog_disabled visual control comparison",
        "B-5 four-location fog and sky personality",
        "B-7 night visibility and light-to-wall contrast",
        "B-8 Quanzhou dawn/day A-B",
        "B-9 sunset white-wall warmth for four locations",
        "B-10 Santorini sea-sky warm band",
        "B-11 Santorini/Seychelles cool back-face hue",
        "B-12 Seychelles water boundary sharpness",
        "B-13 Seychelles fill-light volume and hard shadows",
        "M2 construction verb feel",
        "M4 screenshot quality",
    ]
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "Dev Driven/acceptance-checklist.md v1.3",
        "machine_checks": checks,
        "machine_summary": {
            "passed": sum(item["status"] == "pass" for item in checks),
            "failed": sum(item["status"] == "fail" for item in checks),
        },
        "manual_signoff": {"status": "pending_benja", "items": manual},
        "note": "Manual visual items are deliberately not auto-approved.",
    }
    output = PROJECT / "docs" / "acceptance-machine-report.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["machine_summary"], ensure_ascii=False))
    return 1 if report["machine_summary"]["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
