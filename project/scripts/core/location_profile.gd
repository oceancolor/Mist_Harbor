class_name HarborLocationProfile
extends Resource

## 单地点环境参数资源（LocationProfile）。
##
## 数值唯一源：`Dev Driven/water-lighting-params.md` v4.3。改任何一个数之前先回源该文档，
## 并遵守「认列不认数」——沿革段与「上限 / 边界」列里的数不得引用。
##
## 三条实现纪律（违反会有静默失效）：
##   1. 不写 fog_mode（写了会踩引擎陷阱把 fog_density 改成 1.0）。
##   2. 雾只有昼 / 夜两个标量 + Cape Cod 的天气轴第三常量，四态由 fog_density_for() 派生。
##   3. 不实现 reflection_strength 与 sunset_fog_color（已删除的死字段）。

enum Phase { DAWN, DAY, SUNSET, NIGHT }

const PHASE_NAMES: Array[String] = ["晨", "昼", "日落", "夜"]
const PHASE_IDS: Array[String] = ["dawn", "day", "sunset", "night"]
# 四态 → 雾档映射（§5.1.1.3）：晨 / 昼 / 日落沿用昼档，只有夜走夜档。
const FOG_IS_NIGHT: Array[bool] = [false, false, false, true]

@export var id: String = ""
@export var display_name: String = ""
@export var verb: String = ""
@export var tagline: String = ""
@export var world_seed: int = 240910
@export var min_y: int = -4
@export var max_y: int = 20
@export var max_cells: int = 12000
@export var edge: int = 25
## 天气轴开关（正交于四态昼夜）：kind = "fog" 海雾（泉州/CC 旧设）或 "cloud" 云量（圣托里尼/CC 新设）。
@export var has_weather_toggle: bool = false
@export var weather_label: String = ""
@export var weather_kind: String = "fog"
## 盛行风向（度，0 = +X，逆时针）。驱动海面的方向性风波（初代手感的回归）。
@export var wind_direction_deg: float = 0.0
## 破波带（地点海况差异的核心）：
## 圣托里尼（地中海）≈ 平静：破碎强度 ~0.07，只有零星白色尖点；
## 泉州 / Cape Cod 有拍岸白浪，CC 浪更大（强度 0.9、破碎线更远）。
@export var breaker_intensity: float = 0.5
@export var breaker_period: float = 7.0
@export var breaker_dist: float = 6.0
@export var breaker_wavespan: float = 7.0
@export var whitecap_intensity: float = 0.08
## 天空层贴图参数：云覆盖率（0-1，CC 多云 / 地中海少云）。
@export var cloud_coverage: float = 0.35
## 远景剪影群岛：[{x, z, width, height}]，位于可建造区之外的地平线带。
@export var far_islands: Array[Dictionary] = []

# ── 水体（§3 四地横向表）──
@export var water_deep_color: Color = Color("#35685C")
@export var water_shallow_color: Color = Color("#74A98D")
@export var water_lagoon_color: Color = Color("#74A98D")
@export var water_lagoon_radius: float = 0.0
## 近岸白沙透底（§5 塞舌尔泻湖透明感；reach ≤ 0 关闭）。
@export var water_sand_color: Color = Color("#E8E4CC")
@export var water_sand_reach: float = 0.0
@export var water_shallow_radius: float = 18.0
@export var water_deep_radius: float = 32.0
@export var water_transparency: float = 0.68
@export var foam_color: Color = Color("#E0DCC8")
@export var foam_width: float = 0.6
@export var wave_scale: float = 0.75
@export var wave_speed: float = 0.5
@export var wave_normal_strength: float = 0.55

# ── 雾（§5.1）──
@export var fog_light_color: Color = Color("#DCDAD0")
@export var fog_density_day: float = 0.0040
@export var fog_density_night: float = 0.0050
## 雾天档第三常量（D-CC-2）：仅 Cape Cod 填 0.0075，回退线 0.0065；其余地点保持 0 = 不启用。
@export var fog_density_weather: float = 0.0
@export var fog_floor_by_phase: PackedColorArray = PackedColorArray([
	Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color("#6A7078")
])
@export var fog_aerial_perspective: float = 0.62

# ── 昼（§4 / §5.1 / §5.2.2）──
@export var ambient_light_energy: float = 0.48
@export var tonemap_exposure: float = 0.95
@export var light_color: Color = Color("#F4F0E2")
@export var light_energy: float = 0.95
@export var shadow_blur: float = 1.5
@export var shadow_opacity: float = 0.50
@export var sun_rotation_x: float = -65.0
@export var sun_rotation_y: float = -30.0
@export var sky_top_color: Color = Color("#9CB4BE")
@export var sky_horizon_color: Color = Color("#E0E0D8")
@export var ground_horizon_color: Color = Color("#74A98D")
## 常驻无阴影补光（目前仅塞舌尔 0.30；其余地点保持 0，禁止增删节点）。
@export var fill_light_color: Color = Color("#B8D4E0")
@export var fill_light_energy: float = 0.0
@export var fill_light_rotation: Vector3 = Vector3(-25.0, 200.0, 0.0)

# ── 日落（§6 / §6.2）──
@export var sunset_sun_color: Color = Color("#FFCB7A")
@export var sunset_light_energy: float = 0.70
@export var sunset_sky_top: Color = Color("#2A3A6A")
@export var sunset_sky_horizon: Color = Color("#FFC98A")
@export var sunset_ambient: float = 0.40
@export var sunset_shadow_blur: float = 0.6
@export var sunset_shadow_opacity: float = 0.80
@export var sunset_duration_scale: float = 1.0
@export var sunset_narrative: String = ""

# ── 晨（§4.2）──
@export var morning_light_color: Color = Color("#E8DCC4")
@export var morning_light_energy: float = 0.70
@export var morning_ambient: float = 0.42
@export var morning_shadow_blur: float = 1.2
@export var morning_shadow_opacity: float = 0.55
@export var morning_sky_top: Color = Color("#C4C6C4")
@export var morning_sky_horizon: Color = Color("#DED8CC")
@export var morning_sun_rotation_y: float = -90.0

# ── 默认机位（地点可选；<0 = 用全局默认）──
@export var camera_yaw: float = -1.0
@export var camera_pitch: float = -1.0
@export var camera_zoom: float = -1.0

# ── 夜（§4.3）──
@export var night_light_color: Color = Color("#93A4B8")
@export var night_light_energy: float = 0.12
@export var night_ambient: float = 0.22
@export var night_sky_top: Color = Color("#1E2634")
@export var night_sky_horizon: Color = Color("#2A3444")


static func hex(value: Variant, fallback: Color = Color.WHITE) -> Color:
	## 🔴 R-ENG-16（新增）：禁止用 `is_valid_hex_number(true)` 校验裸十六进制——
	## `with_prefix=true` 要求 "0x" 前缀，"9CB4BE" 会被判非法并**静默回落成白色**，
	## 表现为"整屏过曝 + 海面隐身"（2026-09-26 事故）。统一走 `Color.from_string`。
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	return Color.from_string(text, fallback)


static func from_dict(data: Dictionary) -> HarborLocationProfile:
	var profile := HarborLocationProfile.new()
	profile.id = str(data.get("id", ""))
	profile.display_name = str(data.get("display_name", ""))
	profile.verb = str(data.get("verb", ""))
	profile.tagline = str(data.get("tagline", ""))
	profile.world_seed = int(data.get("world_seed", 240910))
	profile.min_y = int(data.get("min_y", -4))
	profile.max_y = int(data.get("max_y", 20))
	profile.max_cells = int(data.get("max_cells", 12000))
	profile.edge = int(data.get("edge", 25))
	profile.has_weather_toggle = bool(data.get("has_weather_toggle", false))
	profile.weather_label = str(data.get("weather_label", ""))
	profile.weather_kind = str(data.get("weather_kind", "fog"))
	profile.wind_direction_deg = float(data.get("wind_direction_deg", 0.0))
	var surf: Dictionary = data.get("surf", {})
	profile.breaker_intensity = float(surf.get("breaker_intensity", data.get("breaker_intensity", 0.5)))
	profile.breaker_period = float(surf.get("breaker_period", 7.0))
	profile.breaker_dist = float(surf.get("breaker_dist", 6.0))
	profile.breaker_wavespan = float(surf.get("breaker_wavespan", 7.0))
	profile.whitecap_intensity = float(surf.get("whitecap_intensity", 0.08))
	profile.cloud_coverage = float(data.get("cloud_coverage", 0.35))
	var islands: Variant = data.get("far_islands", [])
	if islands is Array:
		for island in islands as Array:
			if island is Dictionary:
				profile.far_islands.append(island as Dictionary)

	var water: Dictionary = data.get("water", {})
	profile.water_deep_color = hex(water.get("deep_color", "35685C"))
	profile.water_shallow_color = hex(water.get("shallow_color", "74A98D"))
	profile.water_lagoon_color = hex(water.get("lagoon_color", water.get("shallow_color", "74A98D")))
	profile.water_lagoon_radius = float(water.get("lagoon_radius", 0.0))
	profile.water_sand_color = hex(water.get("sand_color", "E8E4CC"))
	profile.water_sand_reach = float(water.get("sand_reach", 0.0))
	profile.water_shallow_radius = float(water.get("shallow_radius", 18.0))
	profile.water_deep_radius = float(water.get("deep_radius", 32.0))
	profile.water_transparency = float(water.get("transparency", 0.68))
	profile.foam_color = hex(water.get("foam_color", "E0DCC8"))
	profile.foam_width = float(water.get("foam_width", 0.6))
	profile.wave_scale = float(water.get("wave_scale", 0.75))
	profile.wave_speed = float(water.get("wave_speed", 0.5))
	profile.wave_normal_strength = float(water.get("wave_normal_strength", 0.55))

	var fog: Dictionary = data.get("fog", {})
	profile.fog_light_color = hex(fog.get("light_color", "DCDAD0"))
	profile.fog_density_day = float(fog.get("density_day", 0.0040))
	profile.fog_density_night = float(fog.get("density_night", 0.0050))
	profile.fog_density_weather = float(fog.get("density_weather", 0.0))
	profile.fog_aerial_perspective = float(fog.get("aerial_perspective", 0.62))
	var floor_colors := PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
	var night_floor: Variant = fog.get("night_floor", "")
	if str(night_floor) != "":
		floor_colors[Phase.NIGHT] = hex(night_floor, Color(0, 0, 0, 0))
	profile.fog_floor_by_phase = floor_colors

	var day: Dictionary = data.get("day", {})
	profile.ambient_light_energy = float(day.get("ambient", 0.48))
	profile.tonemap_exposure = float(day.get("tonemap_exposure", 0.95))
	profile.light_color = hex(day.get("light_color", "F4F0E2"))
	profile.light_energy = float(day.get("light_energy", 0.95))
	profile.shadow_blur = float(day.get("shadow_blur", 1.5))
	profile.shadow_opacity = float(day.get("shadow_opacity", 0.5))
	profile.sun_rotation_x = float(day.get("sun_rotation_x", -65.0))
	profile.sun_rotation_y = float(day.get("sun_rotation_y", -30.0))
	profile.sky_top_color = hex(day.get("sky_top", "9CB4BE"))
	profile.sky_horizon_color = hex(day.get("sky_horizon", "E0E0D8"))
	profile.ground_horizon_color = hex(day.get("ground_horizon", water.get("shallow_color", "74A98D")))
	profile.fill_light_color = hex(day.get("fill_light_color", "B8D4E0"))
	profile.fill_light_energy = float(day.get("fill_light_energy", 0.0))
	var fill_rotation: Array = day.get("fill_light_rotation", [-25.0, 200.0, 0.0])
	if fill_rotation.size() == 3:
		profile.fill_light_rotation = Vector3(
			float(fill_rotation[0]), float(fill_rotation[1]), float(fill_rotation[2]))

	var sunset: Dictionary = data.get("sunset", {})
	profile.sunset_sun_color = hex(sunset.get("sun_color", "FFCB7A"))
	profile.sunset_light_energy = float(sunset.get("light_energy", 0.70))
	profile.sunset_sky_top = hex(sunset.get("sky_top", "2A3A6A"))
	profile.sunset_sky_horizon = hex(sunset.get("sky_horizon", "FFC98A"))
	profile.sunset_ambient = float(sunset.get("ambient", 0.40))
	profile.sunset_shadow_blur = float(sunset.get("shadow_blur", 0.6))
	profile.sunset_shadow_opacity = float(sunset.get("shadow_opacity", 0.80))
	profile.sunset_duration_scale = float(sunset.get("duration_scale", 1.0))
	profile.sunset_narrative = str(sunset.get("narrative", ""))

	var morning: Dictionary = data.get("morning", {})
	profile.morning_light_color = hex(morning.get("light_color", "E8DCC4"))
	profile.morning_light_energy = float(morning.get("light_energy", 0.70))
	profile.morning_ambient = float(morning.get("ambient", 0.42))
	profile.morning_shadow_blur = float(morning.get("shadow_blur", 1.2))
	profile.morning_shadow_opacity = float(morning.get("shadow_opacity", 0.55))
	profile.morning_sky_top = hex(morning.get("sky_top", "C4C6C4"))
	profile.morning_sky_horizon = hex(morning.get("sky_horizon", "DED8CC"))
	profile.morning_sun_rotation_y = float(morning.get("sun_rotation_y", -90.0))

	var camera: Dictionary = data.get("camera", {})
	profile.camera_yaw = float(camera.get("yaw", -1.0))
	profile.camera_pitch = float(camera.get("pitch", -1.0))
	profile.camera_zoom = float(camera.get("zoom", -1.0))

	var night: Dictionary = data.get("night", {})
	profile.night_light_color = hex(night.get("light_color", "93A4B8"))
	profile.night_light_energy = float(night.get("light_energy", 0.12))
	profile.night_ambient = float(night.get("ambient", 0.22))
	profile.night_sky_top = hex(night.get("sky_top", "1E2634"))
	profile.night_sky_horizon = hex(night.get("sky_horizon", "2A3444"))
	return profile


## 四态 → 雾密度。天气开关打开时用覆盖式第三常量（R-ENG-15：切换必须覆盖写入）。
func fog_density_for(phase: int, weather_on: bool = false) -> float:
	if weather_on and fog_density_weather > 0.0:
		return fog_density_weather
	return fog_density_night if FOG_IS_NIGHT[phase] else fog_density_day


## 夜态雾色：直接用「该态雾色下限」（雾的夜色）。
## 🔴 修正记录：曾按文档取 max(昼档雾色, 下限)，但昼档雾色 #DCDAD0 比下限亮，
## max 恒取到浅灰 → 夜景整屏被洗成"浓雾"（2026-09-26 二轮验收反馈）。
## 下限的本意就是"雾的夜色"，夜态直接采用；昼态仍用昼档雾色。
func fog_color_for(phase: int) -> Color:
	if FOG_IS_NIGHT[phase] and phase >= 0 and phase < fog_floor_by_phase.size():
		var floor_color: Color = fog_floor_by_phase[phase]
		if floor_color.a > 0.0:
			return floor_color
	return fog_light_color


## 唯一一条参数通道：四地共用，任何地点不得另开分支（硬等价 §4.8.1 ①）。
func light_params(phase: int) -> Dictionary:
	match phase:
		Phase.DAWN:
			return {
				"light_color": morning_light_color,
				"light_energy": morning_light_energy,
				"ambient": morning_ambient,
				"shadow_blur": morning_shadow_blur,
				"shadow_opacity": morning_shadow_opacity,
				"sky_top": morning_sky_top,
				"sky_horizon": morning_sky_horizon,
				"sun_rotation_x": -8.0,
				"sun_rotation_y": morning_sun_rotation_y,
			}
		Phase.SUNSET:
			return {
				"light_color": sunset_sun_color,
				"light_energy": sunset_light_energy,
				"ambient": sunset_ambient,
				"shadow_blur": sunset_shadow_blur,
				"shadow_opacity": sunset_shadow_opacity,
				"sky_top": sunset_sky_top,
				"sky_horizon": sunset_sky_horizon,
				"sun_rotation_x": -2.0,
			}
		Phase.NIGHT:
			return {
				"light_color": night_light_color,
				"light_energy": night_light_energy,
				"ambient": night_ambient,
				"shadow_blur": shadow_blur,
				"shadow_opacity": shadow_opacity,
				"sky_top": night_sky_top,
				"sky_horizon": night_sky_horizon,
				# 月亮与日落太阳同轨低垂海平线（R-ENG-26）：正交相机光轴最高水平，
				# 天体仰角必须 ≤2° 才能在低 zoom 海平面视角入画——落日位即升月位。
				"sun_rotation_x": -2.0,
			}
		_:
			return {
				"light_color": light_color,
				"light_energy": light_energy,
				"ambient": ambient_light_energy,
				"shadow_blur": shadow_blur,
				"shadow_opacity": shadow_opacity,
				"sky_top": sky_top_color,
				"sky_horizon": sky_horizon_color,
				"sun_rotation_x": clampf(sun_rotation_x, -82.0, -5.0),
			}


func phase_name(phase: int) -> String:
	return PHASE_NAMES[phase] if phase >= 0 and phase < PHASE_NAMES.size() else "昼"


func water_tint_for(phase: int) -> Color:
	## 水体是 unshaded，不参与光照；唯一源未发布逐态水色，这里按已发布的逐态
	## 「光色 × 光能」派生明度与色偏，四地共用同一条公式（派生量，不是新参数）。
	var params := light_params(phase)
	var energy_ratio := clampf(float(params["light_energy"]) / maxf(light_energy, 0.001), 0.0, 1.0)
	var tint: Color = params["light_color"]
	var level := clampf(0.35 + 0.65 * energy_ratio, 0.22, 1.0)
	return Color(
		lerpf(1.0, tint.r, 0.35) * level,
		lerpf(1.0, tint.g, 0.35) * level,
		lerpf(1.0, tint.b, 0.35) * level)
