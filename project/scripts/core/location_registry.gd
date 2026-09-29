class_name HarborLocationRegistry
extends RefCounted

## 地点注册表：id → LocationProfile（.tres 优先，回退 JSON）+ 建材表 + 独占机制。
##
## 环境数值的唯一源是 `Dev Driven/water-lighting-params.md` v4.3；
## `data/locations/<id>.json` 是它的机器可读副本，`.tres` 放同名目录即可覆盖（美术调参用）。

const ORDER: Array[String] = ["quanzhou", "santorini", "seychelles", "cape-cod"]
const MECHANICS := {
	"quanzhou": "res://scripts/locations/quanzhou.gd",
	"santorini": "res://scripts/locations/santorini.gd",
	"seychelles": "res://scripts/locations/seychelles.gd",
	"cape-cod": "res://scripts/locations/cape_cod.gd",
}

static func default_id() -> String:
	return ORDER[0]


static func ids() -> Array[String]:
	return ORDER.duplicate()


static func is_valid(id: String) -> bool:
	return ORDER.has(id)


static func profile_path(id: String) -> String:
	return "res://data/locations/%s.json" % [id]


static func tres_path(id: String) -> String:
	return "res://data/locations/%s/profile.tres" % [id]


static func palette_path(id: String) -> String:
	return "res://data/locations/%s/palette.json" % [id]


static func profile(id: String) -> HarborLocationProfile:
	var tres := tres_path(id)
	if ResourceLoader.exists(tres):
		var loaded: Resource = load(tres)
		if loaded is HarborLocationProfile:
			return loaded as HarborLocationProfile
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path(id)))
	if parsed is Dictionary:
		return HarborLocationProfile.from_dict(parsed as Dictionary)
	push_error("Unknown location profile: " + id)
	return HarborLocationProfile.new()


static func palette(id: String) -> Dictionary:
	var path := palette_path(id)
	if not FileAccess.file_exists(path):
		path = "res://data/palette.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


static func palette_items(id: String) -> Array:
	return (palette(id).get("items", []) as Array).duplicate(true)


static func mechanic(id: String) -> HarborLocationMechanic:
	var path := str(MECHANICS.get(id, ""))
	if path.is_empty():
		return HarborLocationMechanic.new()
	var script: Script = load(path)
	if script == null:
		return HarborLocationMechanic.new()
	var instance = script.new()
	return instance as HarborLocationMechanic


static func display_name(id: String) -> String:
	return profile(id).display_name


static func summary(id: String) -> Dictionary:
	var location_profile := profile(id)
	return {
		"id": id,
		"name": location_profile.display_name,
		"verb": location_profile.verb,
		"tagline": location_profile.tagline,
	}
