class_name HarborSunsetTuning
extends RefCounted

## 日落调参（玩家可选覆盖）
##
## 玩家能调的只有日落这一态，且只调「色值 / 太阳高度 / 经度」三类：
##   - 色值：太阳光色、天空水平线色、天顶色、环境光色（环境光色默认跟水平线色）
##   - 高度：太阳俯仰（度，越小越贴地平线）
##   - 经度：太阳方位（度，决定光从哪个方向来）
##
## 🔴 两条纪律：
##   1. 这里的默认值**必须**来自 `HarborLocationProfile`，不得另存一套配色（单值源 §6.2）。
##   2. 本文件不认识任何渲染实现。它只产出/校验一份数据字典，
##      渲染层（`core/daylight.gd`）自己决定怎么用——将来换成别的水光栈不用改这里。
##
## 存档语义：这是作品的一部分，跟作品走（存进存档槽、随导出 JSON 带走）。

const KEYS: Array[String] = ["light_color", "light_energy", "ambient", "ambient_color",
	"sky_horizon", "sky_top", "sun_x", "sun_y"]

## 可调范围（超出即视为坏档，不是静默截断）。
const RANGES := {
	"light_energy": Vector2(0.0, 3.0),
	"ambient": Vector2(0.0, 1.5),
	"sun_x": Vector2(-82.0, 5.0),
	"sun_y": Vector2(-180.0, 180.0),
}
const COLOR_KEYS: Array[String] = ["light_color", "ambient_color", "sky_horizon", "sky_top"]

## 面板上给玩家拖的滑块范围（比合法范围更窄，避免玩家一拖就到过曝/全黑）。
const SLIDER_RANGES := {
	"light_energy": Vector2(0.10, 2.00),
	"ambient": Vector2(0.05, 1.00),
	"sun_x": Vector2(-40.0, -1.0),
	"sun_y": Vector2(-180.0, 180.0),
}


static func defaults_for(profile: HarborLocationProfile) -> Dictionary:
	## 面板打开时的初始值：地点默认 + 当前已有的覆盖。
	if profile == null:
		return {}
	return {
		"light_color": _hex(profile.sunset_sun_color),
		"light_energy": profile.sunset_light_energy,
		"ambient": profile.sunset_ambient,
		"ambient_color": _hex(profile.sunset_sky_horizon),
		"sky_horizon": _hex(profile.sunset_sky_horizon),
		"sky_top": _hex(profile.sunset_sky_top),
		"sun_x": -2.0,
		"sun_y": profile.sun_rotation_y,
	}


static func merged(profile: HarborLocationProfile, overrides: Dictionary) -> Dictionary:
	var result := defaults_for(profile)
	for key in KEYS:
		if overrides.has(key):
			result[key] = overrides[key]
	return result


static func error_for(data: Variant) -> String:
	## 坏档校验：只在键存在时校验，允许存档只覆盖其中一两项。
	if data == null:
		return ""
	if not data is Dictionary:
		return "日落参数格式错误。"
	for key in (data as Dictionary).keys():
		if not KEYS.has(str(key)):
			return "未知日落参数：" + str(key)
	for key in COLOR_KEYS:
		if not (data as Dictionary).has(key):
			continue
		var value: Variant = (data as Dictionary)[key]
		if not value is String or not _is_hex(value):
			return "日落色值无效：" + key
	for key in RANGES:
		if not (data as Dictionary).has(key):
			continue
		var number: Variant = (data as Dictionary)[key]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
			return "日落数值无效：" + key
		var bounds: Vector2 = RANGES[key]
		if float(number) < bounds.x or float(number) > bounds.y:
			return "日落数值超出范围：" + key
	return ""


static func color_of(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, "")
	return HarborLocationProfile.hex(value, fallback)


static func number_of(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


static func _hex(color: Color) -> String:
	return color.to_html(false)


static func _is_hex(value: Variant) -> bool:
	if not value is String:
		return false
	var text := str(value).strip_edges()
	if text.length() != 6 and text.length() != 8:
		return false
	return text.is_valid_hex_number(false)


## 把玩家调好的值渲染成光照层能直接吃的状态字段。
static func state_fields(profile: HarborLocationProfile, overrides: Dictionary) -> Dictionary:
	if overrides.is_empty():
		return {}
	var data := merged(profile, overrides)
	return {
		"light_color": color_of(data, "light_color", profile.sunset_sun_color),
		"light_energy": number_of(data, "light_energy", profile.sunset_light_energy),
		"ambient": number_of(data, "ambient", profile.sunset_ambient),
		"ambient_color": color_of(data, "ambient_color", profile.sunset_sky_horizon),
		"sky_horizon": color_of(data, "sky_horizon", profile.sunset_sky_horizon),
		"sky_top": color_of(data, "sky_top", profile.sunset_sky_top),
		"sun_x": number_of(data, "sun_x", -2.0),
		"sun_rotation_y": number_of(data, "sun_y", profile.sun_rotation_y),
	}
