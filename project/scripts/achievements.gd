extends Node
class_name Achievements

## Player-level achievements: definitions come from res://data/achievements.json,
## unlocked state is stored in user://achievements.json (independent of any save
## slot, because achievements belong to the player, not to one island).

signal unlocked(entry: Dictionary)

const DATA_PATH := "res://data/achievements.json"
const STATE_PATH := "user://achievements.json"

var entries: Array = []
var unlocked_at: Dictionary = {}

# Web writes to user:// asynchronously (IndexedDB): writing this file AFTER a world
# save loses the save. So unlocks are only flushed immediately BEFORE a world save
# (main.gd calls flush()) or when the app closes, never on their own schedule.
var _pending_flush := false

func _ready() -> void:
	_load_definitions()
	_load_state()

func is_unlocked(id: String) -> bool:
	return unlocked_at.has(id)

func unlocked_count() -> int:
	return unlocked_at.size()

func progress_value(kind: String, model, photos: Dictionary) -> int:
	if kind == "total":
		return model.placed_count()
	if kind == "variety":
		var used := 0
		for amount in model.player_counts().values():
			if int(amount) > 0:
				used += 1
		return used
	if kind == "undone":
		return int(model.stats.get("undone", 0))
	if kind == "saved":
		return int(model.stats.get("saved", 0))
	if kind == "night_photo":
		return int(photos.get("night_photos", 0))
	if kind.begins_with("kind:"):
		return int(model.player_counts().get(kind.substr(5), 0))
	return 0

func evaluate(model, photos: Dictionary) -> Array:
	var fresh: Array = []
	for entry in entries:
		var id := str(entry.get("id", ""))
		if id == "" or unlocked_at.has(id):
			continue
		if progress_value(str(entry.get("kind", "")), model, photos) >= int(entry.get("target", 1)):
			unlocked_at[id] = Time.get_datetime_string_from_system(true)
			fresh.append(entry)
	if not fresh.is_empty():
		_pending_flush = true
	return fresh

func flush() -> void:
	if not _pending_flush:
		return
	_save_state()
	_pending_flush = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		flush()
	if what == NOTIFICATION_PREDELETE:
		flush()

func _load_definitions() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		return
	for entry in (parsed as Dictionary).get("achievements", []):
		entries.append(entry)

func _load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if not parsed is Dictionary:
		return
	var stored: Variant = (parsed as Dictionary).get("unlocked", {})
	if stored is Dictionary:
		for key in (stored as Dictionary):
			unlocked_at[str(key)] = str((stored as Dictionary)[key])

func _save_state() -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"schema_version": 1, "unlocked": unlocked_at}))
	file.close()
