class_name HarborLocationProfile
extends RefCounted

const DATA_PATH := "res://data/locations.json"

var id: String
var display_name: String
var verb: String
var seed: int
var edge: int
var min_y: int
var max_y: int
var mechanic: String
var description: String
var environment: Dictionary
var water: Dictionary
var fog_density_day: float
var fog_density_night: float
var fog_density_weather: float
var fog_color_day: Color
var fog_color_night: Color

func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", "quanzhou"))
	display_name = str(data.get("name", id))
	verb = str(data.get("verb", "连"))
	seed = int(data.get("seed", 240910))
	edge = int(data.get("edge", 25))
	min_y = int(data.get("min_y", -4))
	max_y = int(data.get("max_y", 20))
	mechanic = str(data.get("mechanic", "connectivity"))
	description = str(data.get("description", ""))
	environment = (data.get("environment", {}) as Dictionary).duplicate(true)
	water = (data.get("water", {}) as Dictionary).duplicate(true)
	fog_density_day = float(data.get("fog_density_day", 0.0035))
	fog_density_night = float(data.get("fog_density_night", fog_density_day))
	fog_density_weather = float(data.get("fog_density_weather", 0.0))
	fog_color_day = Color(str(data.get("fog_color_day", "cadfd8")))
	fog_color_night = Color(str(data.get("fog_color_night", "6a7078")))

func phase(name: String) -> Dictionary:
	var result := (environment.get(name, environment.get("day", {})) as Dictionary).duplicate(true)
	var night_phase := name == "night"
	result["fog_density"] = fog_density_night if night_phase else fog_density_day
	result["fog"] = (fog_color_night if night_phase else fog_color_day).to_html(false)
	return result

static func load_all() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var result: Dictionary = {}
	if not parsed is Dictionary:
		return result
	for entry in parsed.get("locations", []):
		if entry is Dictionary:
			var profile := HarborLocationProfile.new(entry)
			result[profile.id] = profile
	return result

static func default_id() -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return str(parsed.get("default", "quanzhou")) if parsed is Dictionary else "quanzhou"
