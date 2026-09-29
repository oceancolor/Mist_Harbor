class_name HarborDaylight
extends Node3D

## core #3 / #4 / #5 / #11 / #12 / #13 · 环境参数化（水 / 光 / 雾 / 天 / 日落）
##
## 硬等价（§4.8.1 ①）：**四地昼夜只有这一条分支**。任何地点不得另写 set_night / 昼夜插值。
## `_apply_state()` 只写 UBO uniform 与材质参数，O(1)、零分配、绝不触发世界重建。
##
## 三条禁令：
##   1. 不写 `fog_mode`（写了会把 fog_density 静默改成 1.0）。
##   2. 不 add_child / remove_child 灯光（会引发 shader 重编译）。
##   3. `fog_height_density` 恒为 0。

const SKY_RADIUS := 150.0
const SHADOW_MAX_DISTANCE := 60.0

## 天空盒：颜色与形状分离。贴图只存「形状层」（R=云 / G=远景剪影 / B=夜星），
## 由 _build_sky_texture() 程序生成（fbm 云 + 双层远山剪影 + 星点，横向无缝）；
## 四态颜色仍走 top_color / horizon_color / haze_color——日落时云被染成金橙、
## 雾天远景自动融入雾色，不需要为每个时段各出一张图。
## sky_h 不做 clamp：下半球（地平线以下）渲染成「无限远的海面」——
## 低角度正交相机的画面下缘由它兜底，海天线由此自然分明（2026-09-26 三轮验收）。
const SKY_SHADER := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
uniform vec3 top_color : source_color = vec3(0.61, 0.71, 0.75);
uniform vec3 horizon_color : source_color = vec3(0.88, 0.88, 0.85);
uniform vec3 haze_color : source_color = vec3(0.8, 0.8, 0.8);
uniform vec3 far_sea_color : source_color = vec3(0.12, 0.22, 0.26);
uniform float sky_radius = 220.0;
uniform float night_glow = 0.0;
// 太阳 / 月亮：海平线锚定的屏幕空间公告板（R-ENG-26）。正交投影里无限远方向没有
// 唯一屏幕位置（物理穹顶需要 R≈195 → 2° 仰角的太阳偏移 17 单位 > 画面半高），
// 因此按美术映射放置：太阳纵向位置 = 地平线位置 + (仰角/6°)·(画面顶边−地平线)，
// 横向按方位角 ±40° 映射到画面边缘。任意 zoom/pitch 下太阳稳定贴在海平线上方。
uniform vec3 sun_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_disk_color : source_color = vec3(1.0, 0.97, 0.9);
uniform float cel_disk = 1.0;      // 盘半径（世界单位；zoom 20 画面高 20 单位）
uniform float cel_halo = 0.2;      // 光晕强度
uniform float moon_glow = 0.0;     // 夜态 1：太阳盘变成月牙
uniform vec3 cam_pos = vec3(0.0, 20.0, -48.0);
uniform vec3 cam_axis = vec3(0.0, 0.0, 1.0);
uniform float cam_half = 10.0;     // 画面半高（zoom/2）
uniform sampler2D sky_tex;
varying vec2 sky_uv;
varying float sky_h;
varying vec3 world_pos;
void vertex() {
	sky_uv = UV;
	sky_h = VERTEX.y / sky_radius;   // -0.11(天底) .. 1.0(天顶)
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float sea_side = step(sky_h, 0.0);           // 地平线以下 = 1
	float sky_side = 1.0 - sea_side;
	float h01 = clamp(sky_h, 0.0, 1.0);
	vec3 base = mix(horizon_color, top_color, pow(h01, 0.75));
	vec3 layers = texture(sky_tex, vec2(sky_uv.x, h01)).rgb;
	// 云：比天空亮、向地平线色靠拢（随四态被染成金/橙/暗蓝）。
	vec3 cloud_col = mix(mix(horizon_color, top_color, h01 * 0.35), vec3(1.0), 0.55);
	vec3 sky = mix(base, cloud_col, layers.r);
	// 地平线远景剪影：远山/远岛向雾色暗部收敛，雾越浓越淡。
	sky = mix(sky, haze_color * 0.55, layers.g * 0.85);
	// 夜星（只在夜态/晨态亮起）。
	sky += vec3(0.9, 0.95, 1.0) * layers.b * night_glow;
	// 太阳 / 月亮：海平线锚定公告板。
	vec3 to_sun = normalize(-sun_dir);
	vec3 axis = normalize(cam_axis);
	float azim_len = length(axis.xz);
	if (to_sun.y > -0.008 && dot(to_sun, axis) > 0.0 && azim_len > 0.01) {
		vec3 right = normalize(cross(axis, vec3(0.0, 1.0, 0.0)) + vec3(0.0001, 0.0, 0.0));
		vec3 up2 = cross(right, axis);
		vec3 rel = world_pos - cam_pos;
		vec2 uv_f = vec2(dot(rel, right), dot(rel, up2));
		// 地平线（天球赤道远点）的屏幕位置。
		vec3 azim = normalize(vec3(axis.x, 0.0, axis.z));
		vec3 relh = azim * sky_radius - cam_pos;
		float uv_h_v = dot(relh, up2);
		// 太阳仰角（度）与方位偏角：0-6° 映射 地平线→画面顶边，±40° 映射 中心→边缘。
		float sun_elev = degrees(asin(clamp(to_sun.y, 0.0, 1.0)));
		float phi = asin(clamp(dot(to_sun, right), -1.0, 1.0));
		float uv_s_u = sin(phi) / 0.64 * cam_half * 0.9;   // sin(40°)≈0.64
		float uv_s_v = uv_h_v + clamp(sun_elev / 6.0, 0.0, 0.9)
			* max(cam_half - uv_h_v, 0.0);
		vec2 uv_s = vec2(uv_s_u, uv_s_v);
		float dcel = length(uv_f - uv_s);
		float disk = 1.0 - smoothstep(cel_disk * 0.72, cel_disk, dcel);
		float halo = exp(-dcel / (cel_disk * 2.8)) * cel_halo;
		vec3 body_color = sun_disk_color;
		float body = disk;
		if (moon_glow > 0.5) {
			// 月牙：咬口圆偏移 0.6R、半径 ~0.48R——只咬掉盘的右半，月心保留。
			// 🔴 咬口半径必须小于偏移（旧值 0.66-0.80R > 0.62R 偏移把月心也吞了，
			// 整个月亮只剩光晕）。
			float dbite = length(uv_f - (uv_s + vec2(cel_disk * 0.60, 0.0)));
			float bite = 1.0 - smoothstep(cel_disk * 0.42, cel_disk * 0.54, dbite);
			body = disk * (1.0 - bite);
			body_color = vec3(0.93, 0.96, 1.0);
			halo = exp(-dcel / (cel_disk * 2.2)) * 0.30;
		}
		sky += body_color * body + body_color * halo;
	}
	// 地平线以下 = 无限远的海面：越低越深，与天空在海平线处分界。
	vec3 sea = mix(far_sea_color, far_sea_color * 0.55, clamp(-sky_h * 9.0, 0.0, 1.0));
	ALBEDO = mix(sky, sea, sea_side);
}
"""

## 🔴 R-ENG-19（新增，2026-09-26）：**自定义 shader 一旦输出 ALPHA（进入透明管线），
## 在 Web 导出（Godot 4.7.0 / WebGL2 / Compatibility）里静默不渲染**——无任何报错。
## 实测对照（同网格同节点）：StandardMaterial3D 透明 ✓ 渲染；自定义 shader 不透明 ✓ 渲染；
## 自定义 shader + blend_mix/ALPHA ✗ 消失（含文件版 .gdshader 与运行时字符串建 shader）。
## 因此水体改为**不透明**（三段色带 / 泡沫 / 顶点浪全部保留），光斑贴片与光锥改走
## StandardMaterial3D + 径向渐变贴图。`water_transparency` 字段保留但当前不生效，
## 待 4.7.2 模板就绪后在桌面端复测再恢复透明。
const WATER_SHADER := """shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.21, 0.41, 0.36);
uniform vec3 shallow_color : source_color = vec3(0.45, 0.66, 0.55);
uniform vec3 lagoon_color : source_color = vec3(0.45, 0.66, 0.55);
uniform vec3 foam_color : source_color = vec3(0.88, 0.86, 0.78);
uniform vec3 tint : source_color = vec3(1.0);
uniform float lagoon_radius = 0.0;      // 离岸距离语义（格）：多岛地形每片岛各有浅水环
uniform float shallow_radius = 18.0;
uniform float deep_radius = 32.0;
uniform float wave_scale = 0.75;
uniform float wave_strength = 0.55;
uniform vec2 wind_dir = vec2(1.0, 0.0);
// 破波带（地点海况差异的核心）：
// 圣托里尼（地中海）≈0 平静；泉州/CC 有拍岸白浪，CC 更大更远。
uniform float breaker_intensity = 0.5;
uniform float breaker_period = 7.0;      // 波列周期（秒）：一波一波地来
uniform float breaker_dist = 6.0;        // 破碎深度（离岸格数）：白浪线在这里形成
uniform float breaker_wavespan = 7.0;    // 波列向岸跨度（格）
uniform float whitecap_intensity = 0.08; // 开阔海白色尖点（初代 lines 模型）
// 岸线距离场：R = texel/127，覆盖 ±shore_half（texel=0.5 格 → 最大 63.5 格）。
uniform sampler2D shore_map;
uniform float shore_half = 48.0;
// 日/月光在海面的镜面反光带：视线在平静水面的反射方向扫过天体时出现。
// 正交相机视线方向统一（cam_dir），reflect 后与 -sun_dir 比对，波面噪声把亮带打散成鳞光。
uniform vec3 sun_dir_w = vec3(0.0, -1.0, 0.0);
uniform vec3 cam_dir_w = vec3(0.0, -1.0, 1.0);
uniform vec3 cam_pos_w = vec3(0.0, 20.0, -48.0);
uniform vec3 glitter_color : source_color = vec3(1.0);
uniform float glitter_strength = 0.5;
// 掠射视角（海平面机位）：菲涅尔——视线越平，水面反射天空越多；
// 远海带（shore_d>40）混向天空球的 far_sea，水盒外缘与海平线无缝衔接。
// 旧实现远海带直接压暗（deep*0.75），低机位看像"浑浊的水下"（2026-09-27 用户反馈）。
uniform vec3 sky_refl_color : source_color = vec3(0.85, 0.88, 0.9);
uniform vec3 far_sea_color : source_color = vec3(0.12, 0.22, 0.26);
// 近岸白沙透底（§5 塞舌尔泻湖透明感）：水体保持不透明（R-ENG-19：Web 下 ALPHA
// 静默失效），在近岸按离岸距离混入沙色——视觉等效"浅滩看得见白沙"。
// sand_reach ≤ 0 关闭（每地配置）。
uniform vec3 sand_color : source_color = vec3(0.91, 0.89, 0.8);
uniform float sand_reach = 0.0;
// 流体折射（§2/§5 方案 B 定稿，cursor_work 移植改良）：水体不透明（R-ENG-19），
// 近岸以屏幕纹理折射"透视"水底——沙底/石基带着波幅畸变透出来；离岸变深回归
// 水色；远海完全水色与天际衔接。水下幕帘共享本材质，同样折射其后方的水下世界。
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
varying vec3 world_pos;
varying float shore_d;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 suv = world_pos.xz / (shore_half * 2.0) + 0.5;
	float dtex = 1.0;
	if (suv.x > 0.0 && suv.x < 1.0 && suv.y > 0.0 && suv.y < 1.0) {
		dtex = textureLod(shore_map, suv, 0.0).r;
	}
	shore_d = dtex * 127.0 * 0.5;
	// 域扭曲：低频流场让所有波纹坐标缓缓摆动（打破"完美平行"的机械感）。
	vec2 warp_v = (vec2(vnoise(world_pos.xz * 0.06 + TIME * 0.05),
		vnoise(world_pos.xz * 0.06 + 4.7 - TIME * 0.04)) - 0.5) * 4.0;
	vec2 wp = world_pos.xz + warp_v;
	vec2 wdirn = normalize(wind_dir);
	float along = dot(wp, wdirn);
	float cross = dot(wp, vec2(-wdirn.y, wdirn.x));
	// 深海涌浪：三组不同方向/波长/速度的波叠加（含一组斜向短波）。
	float swell = sin(along * 0.30 * wave_scale + TIME * 0.30)
		+ 0.6 * sin(cross * 0.24 * wave_scale - TIME * 0.22 + along * 0.07)
		+ 0.35 * sin(dot(wp, vec2(0.7, 0.6)) * 0.55 + TIME * 0.5);
	// 浅水效应：向破碎点波高增大，进入碎波带后回落（能量已耗散）。
	float grow = smoothstep(breaker_dist + 9.0, breaker_dist + 1.0, shore_d)
		* (1.0 - smoothstep(2.5, 0.0, shore_d) * 0.55);
	VERTEX.y += swell * wave_strength * 0.10 * (0.55 + 0.45 * grow);
}
void light() {
	// 水面接收太阳平行光与阴影（建筑/船/巨石在水上投出影子）。
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * ndl * ATTENUATION * 0.95;
}
void fragment() {
	// 深浅水色沿真实离岸距离混合（多岛地形每片岛都有自己的浅水环与泻湖）；
	// 深浅水色带沿离岸距离；**大气透视按视距**（规格 §2，2026-09-28 用户方案）：
	// 近相机端永远用近景逻辑（按离岸色的通透水色）——旧实现按"离岛距离"混远海色，
	// 相机离岛 48+ 格时脚下海水被提前套上灰蓝"远海"，四个地点全部出现近景穿帮。
	// 只有真正远（视距 160-290 格）的水才渐变到天际反射色，与 far 裁剪线外的
	// 天空球远海（同一颜色的雾化版）无缝衔接。
	vec3 color = lagoon_color;
	color = mix(color, shallow_color, smoothstep(lagoon_radius, max(lagoon_radius + 0.001, shallow_radius), shore_d));
	color = mix(color, deep_color, smoothstep(shallow_radius, max(shallow_radius + 0.001, deep_radius) * 1.7, shore_d));
	if (sand_reach > 0.0) {
		color = mix(sand_color, color, smoothstep(0.6, sand_reach, shore_d));
	}
	float view_dist = length(world_pos.xz - cam_pos_w.xz);
	float dist_fade = 1.0 - smoothstep(100.0, 240.0, view_dist);
	// 流体折射：近岸（浅水）以折射像为主——沙底/石基透过波幅畸变的屏幕采样
	// 显现出来，加一层泻湖水色滤镜；离岸变深回归水色；远海折射关闭。
	vec2 refract_off = vec2(sin(world_pos.x * 1.4 + TIME * 1.1),
		sin(world_pos.z * 1.2 - TIME * 0.8)) * 0.0034;
	vec3 refracted = textureLod(screen_tex, SCREEN_UV + refract_off, 0.0).rgb;
	vec3 underwater = refracted * (lagoon_color * 1.35 + vec3(0.06));
	float refr_gate = (1.0 - smoothstep(5.0, 26.0, shore_d)) * dist_fade;
	color = mix(color, mix(underwater, color, 0.3), refr_gate);
	color = mix(color, sky_refl_color, smoothstep(160.0, 290.0, view_dist));
	// 菲涅尔掠射：视线越接近水平，水面反射天空越多（物理正确的海面表现）。
	// 高机位俯视 → 深浅水色主导；海平面机位 → 下半屏是映着天色的透视水面。
	float grazing = pow(clamp(1.0 - abs(normalize(cam_dir_w).y), 0.0, 1.0), 4.0);
	// 波面法线细节（cursor_work 移植改良）：细尺度噪声扰动掠射项与整体明度——
	// 中景水面出现随波流动的明暗变化，不再是均匀"泳池色块"。
	float slope_a = vnoise(world_pos.xz * vec2(0.50, 0.42) + vec2(TIME * 0.28, -TIME * 0.16)) - 0.5;
	float slope_b = vnoise(world_pos.xz * vec2(0.36, 0.55) + vec2(-TIME * 0.20, TIME * 0.24)) - 0.5;
	float grazing_local = clamp(grazing * 0.78 + (slope_a * 0.16 + slope_b * 0.12) * dist_fade, 0.0, 1.0);
	color = mix(color, sky_refl_color, grazing_local);
	color *= 1.0 + (slope_a + slope_b) * 0.05 * dist_fade;

	float total_foam = 0.0;
	// 域扭曲（与顶点一致）：湍流让破碎线/泡沫坐标自然摆动。
	vec2 warp = (vec2(vnoise(world_pos.xz * 0.06 + TIME * 0.06),
		vnoise(world_pos.xz * 0.06 + 4.7 - TIME * 0.05)) - 0.5) * 5.0;
	vec2 wpos = world_pos.xz + warp;
	if (breaker_intensity > 0.005) {
		// 破波带：一波一波向岸推进的白浪线——只在浅于破碎深度处出现，
		// 破碎线随岸形蜿蜒（噪声扰动破碎深度），沿岸断裂不连续，
		// 波峰到达时起白、随后消散（泡沫残留）。远处（深海）完全没有白线。
		float coast = vnoise(wpos * 0.16);
		float bdist = breaker_dist * (0.72 + 0.56 * coast);
		// 波群：两列相位错开的行波 + 慢包络（连涌两三波后歇一阵，像真海况）。
		float envelope = 0.55 + 0.45 * sin(TIME * 0.21 + vnoise(wpos * 0.03) * 6.0);
		float ph1 = fract(TIME / max(breaker_period, 0.5) + shore_d / breaker_wavespan + coast * 0.5);
		float ph2 = fract(TIME / max(breaker_period, 0.5) + shore_d / breaker_wavespan + 0.5 + coast * 0.5);
		float shoal = 1.0 - smoothstep(bdist - 1.5, bdist + 2.5, shore_d);
		float pulse = max(smoothstep(0.62, 0.0, ph1), smoothstep(0.62, 0.0, ph2) * 0.6) * envelope;
		pulse *= pulse;
		// 沿岸断裂：双层噪声相乘——碎成一段段的泡沫链，而不是均匀虚线。
		float gap = 0.25 + 0.75 * vnoise(wpos * 0.42 + vec2(TIME * 0.015, 0.0))
			* vnoise(wpos * vec2(0.9, 0.7) - TIME * 0.02);
		float surge = 0.55 + 0.45 * vnoise(world_pos.xz * vec2(0.05, 0.05) + 7.3);
		total_foam += pulse * shoal * gap * surge * breaker_intensity;
		// 拍岸泡沫（swash）：最靠岸的一圈随浪涌起落、渐淡到水线。
		total_foam += exp(-shore_d * 0.85) * breaker_intensity * 0.45
			* (0.65 + 0.35 * sin(TIME * 1.3 + coast * 6.0)) * gap;
	}
	if (whitecap_intensity > 0.005) {
		// 开阔海白色尖点：两层流动噪声相乘——稀疏、无风轴对称、随时间生灭。
		float sw1 = vnoise(world_pos.xz * vec2(0.35, 0.55) + vec2(TIME * 0.35, -TIME * 0.22));
		float sw2 = vnoise(world_pos.xz * vec2(0.50, 0.40) + vec2(-TIME * 0.28, TIME * 0.18));
		total_foam += smoothstep(0.72, 0.95, sw1 * sw2)
			* min(whitecap_intensity * 3.0, 0.5)
			* smoothstep(breaker_dist + 6.0, breaker_dist + 14.0, shore_d);
	}
	// 日/月光带：反射方向贴着天体方向（-sun_dir_w）时出现亮带，
	// vnoise 把带打散成细碎鳞光；日落低角度 → 反射角正对相机 → 金光大道。
	vec3 reflect_dir = reflect(normalize(cam_dir_w), vec3(0.0, 1.0, 0.0));
	float glint = pow(clamp(dot(reflect_dir, -sun_dir_w), 0.0, 1.0), 140.0);
	glint *= 0.45 + 0.55 * vnoise(world_pos.xz * 1.6 + vec2(TIME * 0.4, -TIME * 0.3));
	// 远处细节淡出（规格 §2）：泡沫与鳞光在 100-240 格渐隐，远水面趋近平色，
	// 与 camera.far 之外的天空球远海（同 fog 匹配色）无缝衔接——远处不再有闪动纹理暴露接缝。
	total_foam *= dist_fade;
	color = mix(color, foam_color, clamp(total_foam, 0.0, 0.85));
	color += glitter_color * glint * glitter_strength * dist_fade;
	ALBEDO = color * tint;
}
"""

var profile: HarborLocationProfile
var phase: int = HarborLocationProfile.Phase.DAY
var weather_on: bool = false

var environment := Environment.new()
var world_environment := WorldEnvironment.new()
var sea_curtain: MeshInstance3D
var sun := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()
var sky: MeshInstance3D
var water: MeshInstance3D
var sky_material := ShaderMaterial.new()
var water_material := ShaderMaterial.new()

var _tween: Tween
var _from: Dictionary = {}
var _to: Dictionary = {}


func setup(location_profile: HarborLocationProfile) -> void:
	profile = location_profile
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_height_density = 0.0
	environment.background_mode = Environment.BG_COLOR
	world_environment.environment = environment
	add_child(world_environment)

	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
	add_child(sun)
	fill.shadow_enabled = false
	fill.light_energy = 0.0
	add_child(fill)

	var sky_mesh := SphereMesh.new()
	sky_mesh.radius = SKY_RADIUS
	sky_mesh.height = SKY_RADIUS * 2.0
	sky_mesh.radial_segments = 16
	sky_mesh.rings = 10
	sky_material.shader = _shader(SKY_SHADER)
	sky_material.set_shader_parameter("sky_radius", SKY_RADIUS)
	sky = MeshInstance3D.new()
	sky.mesh = sky_mesh
	sky.material_override = sky_material
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)

	# 海 = 800×800 大平面（顶面 -0.23）：正交视野最宽 ~86 格、camera.far=300，
	# 平面边缘（≥400 格）永远在 far 之外被裁掉——任何机位都看不到几何边界（规格 §2）。
	# 岸线采样超出 shore_map 范围时 shader 侧自动取远海色带；水下视线由不透明平面兜底。
	var ocean := PlaneMesh.new()
	ocean.size = Vector2(800, 800)
	water_material.shader = _shader(WATER_SHADER)
	water = MeshInstance3D.new()
	water.mesh = ocean
	water.position.y = -0.23
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# 🔴 近机位水下幕帘（规格 §2，用户方案定稿）：正交视锥下缘在低角度会探到
	# 海平面以下——平面海无法接住"已在水面下"的射线（永不命中），露出的
	# 天空球下半球就是近景灰带（四地截图复验）。幕帘挂在海平面以下、
	# 每帧随相机前移 95 格，与海面同 shader 同色带 → 水下视线全部落在它上，
	# 近景与海面光照逻辑完全一致。位置/朝向在 _process 里跟随相机。
	var curtain_mesh := PlaneMesh.new()
	curtain_mesh.size = Vector2(220, 90)
	sea_curtain = MeshInstance3D.new()
	sea_curtain.mesh = curtain_mesh
	sea_curtain.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	sea_curtain.material_override = water_material
	sea_curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea_curtain)

	_build_sky_texture()
	apply_water()
	apply_phase(HarborLocationProfile.Phase.DAY, false, false)
	_build_scenery()


## 远景剪影群岛（地平线带）：让场景有纵深，同时暗示可建造区之外仍有世界。
## 剪影放在雾里（distance ≈ 90-150），随地点配色自动被雾冲淡成剪影。
func _build_scenery() -> void:
	if profile == null or profile.far_islands.is_empty():
		return
	var scenery := Node3D.new()
	scenery.name = "FarScenery"
	var haze := profile.fog_light_color.lerp(profile.water_deep_color, 0.35)
	for island in profile.far_islands:
		var width := float(island.get("width", 12.0))
		var height := float(island.get("height", 3.0))
		var base := MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = width * 0.5
		base_mesh.bottom_radius = width * 0.62
		base_mesh.height = 3.0
		base_mesh.radial_segments = 7
		base.position = Vector3(float(island.get("x", 0.0)), -1.2, float(island.get("z", 0.0)))
		base.material_override = _scenery_material(haze.darkened(0.08))
		scenery.add_child(base)
		if height > 0.5:
			var hill := MeshInstance3D.new()
			var hill_mesh := SphereMesh.new()
			hill_mesh.radius = width * 0.42
			hill_mesh.height = height * 2.2
			hill_mesh.radial_segments = 7
			hill_mesh.rings = 3
			hill.position = base.position + Vector3(0, 1.4 + height * 0.4, 0)
			hill.scale = Vector3(1.0, 0.9, 0.72)
			hill.material_override = _scenery_material(haze.darkened(0.14))
			scenery.add_child(hill)
	add_child(scenery)


func _scenery_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func debug_water_override(_mode: int = 1) -> void:
	## 渲染诊断用：水体强制成不透明洋红。
	water_material.set_shader_parameter("deep_color", Color(1, 0, 1))
	water_material.set_shader_parameter("shallow_color", Color(1, 0, 1))
	water_material.set_shader_parameter("lagoon_color", Color(1, 0, 1))
	water_material.set_shader_parameter("foam_color", Color(0, 0, 0))
	water_material.set_shader_parameter("tint", Color(1, 1, 1))
	water_material.set_shader_parameter("breaker_intensity", 0.0)
	water_material.set_shader_parameter("whitecap_intensity", 0.0)


func render_diagnostics() -> Dictionary:
	var fwd := -sun.global_transform.basis.z
	return {
		"water_visible": water.visible,
		"water_position": [water.global_position.x, water.global_position.y, water.global_position.z],
		"water_aabb": [water.get_aabb().size.x, water.get_aabb().size.y, water.get_aabb().size.z],
		"water_has_mesh": water.mesh != null,
		"water_has_material": water.material_override != null,
		"sun_dir": [snappedf(fwd.x, 0.001), snappedf(fwd.y, 0.001), snappedf(fwd.z, 0.001)],
		"sky_sun_dir": sky_material.get_shader_parameter("sun_dir"),
		"cel_disk": sky_material.get_shader_parameter("cel_disk"),
		"moon_glow": sky_material.get_shader_parameter("moon_glow"),
		"sky_cam_axis": sky_material.get_shader_parameter("cam_axis"),
		"sky_cam_pos": sky_material.get_shader_parameter("cam_pos"),
		"sky_cam_half": sky_material.get_shader_parameter("cam_half"),
		"sky_cel_halo": sky_material.get_shader_parameter("cel_halo"),
		"sky_tex_samples": _sky_tex_samples,
		"sun_elevation_deg": snappedf(rad_to_deg(asin(clampf(-fwd.y, -1.0, 1.0))), 0.1),
		"water_deep": str(water_material.get_shader_parameter("deep_color")),
		"water_tint": str(water_material.get_shader_parameter("tint")),
		"water_lagoon_radius": water_material.get_shader_parameter("lagoon_radius"),
		"water_shallow_radius": water_material.get_shader_parameter("shallow_radius"),
		"sky_top": str(sky_material.get_shader_parameter("top_color")),
		"sky_horizon": str(sky_material.get_shader_parameter("horizon_color")),
		"bg_mode": environment.background_mode,
		"bg_color": str(environment.background_color),
		"fog_density": environment.fog_density,
		"fog_color": str(environment.fog_light_color),
		"ambient": environment.ambient_light_energy,
		"ambient_color": str(environment.ambient_light_color),
		"exposure": environment.tonemap_exposure,
		"tonemap_mode": environment.tonemap_mode,
		"sun_energy": sun.light_energy,
		"sun_color": str(sun.light_color),
		"sun_rotation": [sun.rotation_degrees.x, sun.rotation_degrees.y],
		"fill_energy": fill.light_energy,
		"terrain_faces": 0,
	}


## 岸线距离场（texel=0.5 格，覆盖 ±SHORE_HALF）。rebuild 时由 build_world 调用。
const SHORE_TEX := 192
const SHORE_HALF := 48.0
var ring: Dictionary = {}   # Vector2i(列) -> 离水格数，供地形网格做滩涂过渡


## 由世界模型烘焙离岸距离场：R 通道 = min(d_texel,63)/63。
## 同时产出 ring（每个陆上列的离水格数），地形网格用它把沙滩顶面逐级压低。
func update_shore(source_model: HarborWorldModel) -> void:
	var step := SHORE_HALF * 2.0 / float(SHORE_TEX)
	var land: Array = []
	land.resize(SHORE_TEX)
	var dist: Array = []
	dist.resize(SHORE_TEX)
	for xi in range(SHORE_TEX):
		var land_row: Array = []
		land_row.resize(SHORE_TEX)
		var dist_row: Array = []
		dist_row.resize(SHORE_TEX)
		var wx := -SHORE_HALF + (float(xi) + 0.5) * step
		for zi in range(SHORE_TEX):
			var wz := -SHORE_HALF + (float(zi) + 0.5) * step
			var is_land := source_model.has_cell(Vector3i(floori(wx), 0, floori(wz))) \
				or source_model.has_cell(Vector3i(floori(wx), 1, floori(wz)))
			land_row[zi] = is_land
			dist_row[zi] = 0.0 if is_land else 1e9
		land[xi] = land_row
		dist[xi] = dist_row
	# 两遍 chamfer（8 邻域）求近似欧氏距离。
	for pass_index in range(2):
		var forward := pass_index == 0
		for xi in (range(SHORE_TEX) if forward else range(SHORE_TEX - 1, -1, -1)):
			for zi in (range(SHORE_TEX) if forward else range(SHORE_TEX - 1, -1, -1)):
				var row: Array = dist[xi]
				var best: float = row[zi]
				for offset in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var nx: int = xi + offset.x * (1 if forward else -1)
					var nz: int = zi + offset.y * (1 if forward else -1)
					if nx < 0 or nx >= SHORE_TEX or nz < 0 or nz >= SHORE_TEX:
						continue
					var cost := 1.0 if (offset.x == 0 or offset.y == 0) else 1.414
					best = minf(best, (dist[nx] as Array)[nz] + cost)
				row[zi] = best
	var image := Image.create(SHORE_TEX, SHORE_TEX, false, Image.FORMAT_R8)
	ring.clear()
	for xi in range(SHORE_TEX):
		var wx := -SHORE_HALF + (float(xi) + 0.5) * step
		for zi in range(SHORE_TEX):
			var wz := -SHORE_HALF + (float(zi) + 0.5) * step
			# R8 = texel/127 → shader 侧解码最大 63.5 格，覆盖塞舌尔 46 格深水色带。
			var value := minf((dist[xi] as Array)[zi], 127.0)
			image.set_pixel(xi, zi, Color(value / 127.0, 0, 0))
			if (land[xi] as Array)[zi]:
				var column := Vector2i(floori(wx), floori(wz))
				var cells := int(round(value * 0.5)) if value < 127.0 else 12
				if not ring.has(column) or int(ring[column]) > cells:
					ring[column] = cells
	water_material.set_shader_parameter("shore_map", ImageTexture.create_from_image(image))


## 程序生成天空层贴图（512×128，横向无缝）：
## R = 云 alpha（fbm，覆盖率随地点）｜G = 地平线远景剪影 alpha（双层噪声远山）｜B = 夜星点。
## 颜色不进贴图——四态 tint 由 sky shader 的 top/horizon/haze uniforms 提供。
func _build_sky_texture(cloud_override: float = -1.0) -> void:
	if profile == null:
		return
	var w := 512
	var h := 128
	var image := Image.create(w, h, false, Image.FORMAT_RGB8)
	var cloud := FastNoiseLite.new()
	cloud.seed = profile.world_seed + 77
	cloud.frequency = 0.010
	cloud.fractal_octaves = 4
	cloud.fractal_gain = 0.55
	var hills := FastNoiseLite.new()
	hills.seed = profile.world_seed + 91
	hills.frequency = 0.018
	hills.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = profile.world_seed + 5
	var stars := {}
	for i in range(240):
		stars[Vector2i(rng.randi_range(0, w - 1), rng.randi_range(int(h * 0.30), h - 6))] = 0.4 + rng.randf() * 0.6
	var coverage := clampf(profile.cloud_coverage if cloud_override < 0.0 else cloud_override, 0.0, 1.0)
	for y in range(h):
		var v := float(y) / float(h - 1)   # 0=地平线 1=天顶
		for x in range(w):
			var cloud_a := 0.0
			if coverage > 0.01 and v > 0.04 and v < 0.92:
				var n := cloud.get_noise_2d(float(x), float(y) * 1.6) * 0.5 + 0.5
				var band := smoothstep(0.04, 0.18, v) * (1.0 - smoothstep(0.66, 0.92, v))
				var th := 1.0 - coverage * 0.75
				cloud_a = smoothstep(th, th + 0.18, n) * band
			# 双层远山剪影：近层高、远层矮而淡（幅度压低，地平线处只是薄薄一条轮廓）。
			var c1 := (hills.get_noise_1d(float(x)) * 0.5 + 0.5) * 0.062
			var c2 := (hills.get_noise_1d(float(x) + 500.0) * 0.5 + 0.5) * 0.034
			var sil := 0.0
			if v < c1:
				sil = 1.0
			elif v < c1 + 0.012:
				sil = 1.0 - (v - c1) / 0.012
			if v < c2:
				sil = maxf(sil, 0.55)
			var star_b := 0.0
			var hit: Variant = stars.get(Vector2i(x, y), null)
			if hit != null:
				star_b = float(hit)
			image.set_pixel(x, y, Color(cloud_a, clampf(sil, 0.0, 1.0), star_b))
	# 横向无缝 wrap：尾部 72 列向头部对应列渐变混合（云/剪影噪声非周期，直接拼会有缝）。
	var fade := 72
	var wrapped := Image.create(w, h, false, Image.FORMAT_RGB8)
	wrapped.blit_rect(image, Rect2i(0, 0, w, h), Vector2i.ZERO)
	for i in range(fade):
		var t := (float(i) + 1.0) / float(fade)
		for y in range(h):
			var head: Color = image.get_pixel(i, y)
			var tail: Color = image.get_pixel(w - fade + i, y)
			wrapped.set_pixel(w - fade + i, y, tail.lerp(head, t))
	sky_material.set_shader_parameter("sky_tex", ImageTexture.create_from_image(wrapped))
	# 采样点存档（诊断用）：贴图 R=云 G=剪影 B=星，采样行覆盖地平线带到顶部。
	_sky_tex_samples = {}
	for point in [Vector2i(64, 2), Vector2i(64, 6), Vector2i(200, 4), Vector2i(64, 40),
			Vector2i(64, 90), Vector2i(300, 2)]:
		var c: Color = wrapped.get_pixel(point.x, point.y)
		_sky_tex_samples["%d,%d" % [point.x, point.y]] = [snappedf(c.r, 0.01), snappedf(c.g, 0.01), snappedf(c.b, 0.01)]


var _sky_tex_samples: Dictionary = {}


func set_profile(location_profile: HarborLocationProfile) -> void:
	profile = location_profile
	_build_sky_texture()
	apply_water()
	apply_phase(phase, weather_on, false)


func _process(_delta: float) -> void:
	## 海面光带与天体公告板跟随相机（正交相机视线统一，一帧一取即可）。
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var axis := -cam.global_transform.basis.z
		water_material.set_shader_parameter("cam_dir_w", axis)
		water_material.set_shader_parameter("cam_pos_w", cam.global_position)
		sky_material.set_shader_parameter("cam_axis", axis)
		sky_material.set_shader_parameter("cam_pos", cam.global_position)
		sky_material.set_shader_parameter("cam_half", cam.size * 0.5)
		# 水下幕帘：竖立在海平面以下、随相机前移 95 格（位于远海淡出带之前、
		# 大多数水下地形之后），面朝相机。上缘与海面齐平 → 水线即幕帘顶边。
		if sea_curtain != null:
			var fwd := Vector3(axis.x, 0.0, axis.z)
			if fwd.length_squared() > 0.0001:
				fwd = fwd.normalized()
				sea_curtain.global_position = cam.global_position + fwd * 95.0
				sea_curtain.global_position.y = -0.23 - 45.0   # 平面高 90，上缘贴海面
				sea_curtain.rotation.y = atan2(fwd.x, fwd.z)


## 天空球下半球的远海色 = 水面在 camera.far 处被雾淡出后的颜色（规格 §2）：
## 水平面在 far（300 格）处被环境雾雾化 f，far 裁剪线两侧（水面↔天空球远海）
## 只有同色才无缝。water 侧的雾由渲染器按同一 density 施加，此处 sky 侧手动对齐。
func _far_sea_for(state: Dictionary) -> Color:
	## 天空球下半球远海色 = 水面远带（天际反射色）被雾淡出后的颜色：
	## far 裁剪线两侧（水面↔天空球）同色才无缝（规格 §2）。
	var density := float(state.get("fog_density", 0.002))
	var fog_factor := 1.0 - exp(-density * 300.0)
	# 与水面 sky_refl 同源（天顶蓝为主），far 线两侧才无缝。
	var refl := (state.get("sky_top", Color.WHITE) as Color) \
		.lerp(state.get("sky_horizon", Color.WHITE), 0.55) \
		.lerp(state.get("fog_color", Color(0.8, 0.8, 0.8)), 0.25)
	return refl.lerp(state.get("fog_color", Color(0.8, 0.8, 0.8)), fog_factor)


func apply_water() -> void:
	if profile == null:
		return
	var wind_rad := deg_to_rad(profile.wind_direction_deg)
	water_material.set_shader_parameter("wind_dir", Vector2(cos(wind_rad), sin(wind_rad)))
	water_material.set_shader_parameter("breaker_intensity", profile.breaker_intensity)
	water_material.set_shader_parameter("breaker_period", profile.breaker_period)
	water_material.set_shader_parameter("breaker_dist", profile.breaker_dist)
	water_material.set_shader_parameter("breaker_wavespan", profile.breaker_wavespan)
	water_material.set_shader_parameter("whitecap_intensity", profile.whitecap_intensity)
	water_material.set_shader_parameter("deep_color", profile.water_deep_color)
	water_material.set_shader_parameter("sand_color", profile.water_sand_color)
	water_material.set_shader_parameter("sand_reach", profile.water_sand_reach)
	water_material.set_shader_parameter("shallow_color", profile.water_shallow_color)
	water_material.set_shader_parameter("lagoon_color", profile.water_lagoon_color)
	water_material.set_shader_parameter("lagoon_radius", profile.water_lagoon_radius)
	water_material.set_shader_parameter("shallow_radius", profile.water_shallow_radius)
	water_material.set_shader_parameter("deep_radius", profile.water_deep_radius)
	water_material.set_shader_parameter("foam_color", profile.foam_color)
	water_material.set_shader_parameter("wave_scale", profile.wave_scale)
	water_material.set_shader_parameter("wave_strength", profile.wave_normal_strength)


func state_for(target_phase: int, target_weather: bool) -> Dictionary:
	var params := profile.light_params(target_phase)
	return {
		"light_color": params["light_color"],
		"light_energy": params["light_energy"],
		"ambient": params["ambient"],
		"ambient_color": params["sky_horizon"],
		"shadow_blur": params["shadow_blur"],
		"shadow_opacity": params["shadow_opacity"],
		"sun_x": params["sun_rotation_x"],
		"sky_top": params["sky_top"],
		"sky_horizon": params["sky_horizon"],
		"fog_density": profile.fog_density_for(target_phase, target_weather),
		"fog_color": profile.fog_color_for(target_phase),
		"exposure": profile.tonemap_exposure,
		"water_tint": profile.water_tint_for(target_phase),
		"sky_night": (1.0 if target_phase == HarborLocationProfile.Phase.NIGHT
			else 0.25 if target_phase == HarborLocationProfile.Phase.DAWN else 0.0),
		# 日/月天体参数（R-ENG-26）：盘半径为世界单位（正交画面 zoom 20 高 20 单位），
		# 日落大而亮、夜态是月牙、昼/晨小。
		"cel_disk": (1.7 if target_phase == HarborLocationProfile.Phase.SUNSET
			else 1.15 if target_phase == HarborLocationProfile.Phase.NIGHT
			else 1.2 if target_phase == HarborLocationProfile.Phase.DAWN else 0.95),
		"cel_halo": (0.95 if target_phase == HarborLocationProfile.Phase.SUNSET
			else 0.30 if target_phase == HarborLocationProfile.Phase.DAWN else 0.18),
		"moon_glow": (1.0 if target_phase == HarborLocationProfile.Phase.NIGHT else 0.0),
		"glitter": (0.35 if target_phase == HarborLocationProfile.Phase.NIGHT
			else 0.85 if target_phase == HarborLocationProfile.Phase.SUNSET
			else 0.30 if target_phase == HarborLocationProfile.Phase.DAWN else 0.50),
	}


func apply_phase(target_phase: int, target_weather: bool, animate: bool = true) -> void:
	if profile == null:
		return
	phase = target_phase
	weather_on = target_weather and profile.has_weather_toggle
	# 云量天气（圣托里尼/CC）：开关切换重建天空贴图（开=浓云，关=该地日常云量）。
	if profile.weather_kind == "cloud":
		_build_sky_texture(0.85 if weather_on else -1.0)
	if not animate:
		_from = state_for(phase, weather_on)
		_apply_state(_from)
		return
	_from = _current_state()
	_to = state_for(phase, weather_on)
	if _tween != null and _tween.is_running():
		_tween.kill()
	var duration := 0.6
	if phase == HarborLocationProfile.Phase.SUNSET:
		duration = 2.2 * profile.sunset_duration_scale
	_tween = create_tween()
	_tween.tween_method(_apply_interpolated, 0.0, 1.0, duration)


func _apply_interpolated(t: float) -> void:
	_apply_state(_lerp_state(_from, _to, t))


func _current_state() -> Dictionary:
	return {
		"light_color": sun.light_color,
		"light_energy": sun.light_energy,
		"ambient": environment.ambient_light_energy,
		"ambient_color": environment.ambient_light_color,
		"shadow_blur": sun.shadow_blur,
		"shadow_opacity": sun.shadow_opacity,
		"sun_x": sun.rotation_degrees.x,
		"sky_top": sky_material.get_shader_parameter("top_color"),
		"sky_horizon": sky_material.get_shader_parameter("horizon_color"),
		"fog_density": environment.fog_density,
		"fog_color": environment.fog_light_color,
		"exposure": environment.tonemap_exposure,
		"water_tint": water_material.get_shader_parameter("tint"),
		"sky_night": sky_material.get_shader_parameter("night_glow"),
		"cel_disk": sky_material.get_shader_parameter("cel_disk"),
		"cel_halo": sky_material.get_shader_parameter("cel_halo"),
		"moon_glow": sky_material.get_shader_parameter("moon_glow"),
		"glitter": water_material.get_shader_parameter("glitter_strength"),
	}


func _lerp_state(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var result := {}
	for key in b:
		var value_a: Variant = a.get(key, b[key])
		var value_b: Variant = b[key]
		if value_b is Color:
			result[key] = (value_a as Color).lerp(value_b as Color, t)
		elif value_b is float or value_b is int:
			result[key] = lerpf(float(value_a), float(value_b), t)
		else:
			result[key] = value_b
	return result


func _apply_state(state: Dictionary) -> void:
	sun.light_color = state.get("light_color", Color.WHITE)
	sun.light_energy = float(state.get("light_energy", 1.0))
	sun.shadow_blur = float(state.get("shadow_blur", 1.0))
	sun.shadow_opacity = float(state.get("shadow_opacity", 0.5))
	sun.rotation_degrees = Vector3(clampf(float(state.get("sun_x", -48.0)), -82.0, -2.0),
		float(state.get("sun_rotation_y", profile.sun_rotation_y)), 0.0)
	environment.ambient_light_energy = float(state.get("ambient", 0.4))
	environment.ambient_light_color = state.get("ambient_color", Color.WHITE)
	environment.tonemap_exposure = float(state.get("exposure", 1.0))
	environment.fog_density = float(state.get("fog_density", 0.0035))
	environment.fog_light_color = state.get("fog_color", Color.WHITE)
	environment.background_color = state.get("sky_horizon", Color.WHITE)
	sky_material.set_shader_parameter("top_color", state.get("sky_top", Color.WHITE))
	sky_material.set_shader_parameter("horizon_color", state.get("sky_horizon", Color.WHITE))
	sky_material.set_shader_parameter("haze_color", state.get("fog_color", Color(0.8, 0.8, 0.8)))
	sky_material.set_shader_parameter("far_sea_color",
		_far_sea_for(state))
	sky_material.set_shader_parameter("night_glow", float(state.get("sky_night", 0.0)))
	water_material.set_shader_parameter("tint", state.get("water_tint", Color.WHITE))
	# 水面菲涅尔掠射的天空反射色 = 该态地平线色；远海与天空球共用同一 far_sea
	# （水盒外缘与海平线无缝衔接，R-ENG-28）。
	# 菲涅尔反射的是天空——取天顶与地平线的混合（蓝为主），只带少量雾；
	# 用地平线白做反射色会把远海染成白灰（2026-09-28 截图复验）。
	var sky_refl := (state.get("sky_top", Color.WHITE) as Color) \
		.lerp(state.get("sky_horizon", Color.WHITE), 0.55) \
		.lerp(state.get("fog_color", Color(0.8, 0.8, 0.8)), 0.25)
	water_material.set_shader_parameter("sky_refl_color", sky_refl)
	# 日/月天体：方向取太阳直射 forward，盘色直接用该态光源色（日落金橙/夜淡蓝=月色）。
	# 旋转刚写入，读取 basis 拿世界直射方向。
	var forward := -sun.global_transform.basis.z
	sky_material.set_shader_parameter("sun_dir", forward)
	sky_material.set_shader_parameter("sun_disk_color", state.get("light_color", Color.WHITE))
	sky_material.set_shader_parameter("cel_disk", float(state.get("cel_disk", 1.0)))
	sky_material.set_shader_parameter("cel_halo", float(state.get("cel_halo", 0.2)))
	sky_material.set_shader_parameter("moon_glow", float(state.get("moon_glow", 0.0)))
	water_material.set_shader_parameter("sun_dir_w", forward)
	water_material.set_shader_parameter("glitter_color", state.get("light_color", Color.WHITE))
	water_material.set_shader_parameter("glitter_strength", float(state.get("glitter", 0.5)))
	fill.light_color = profile.fill_light_color
	fill.light_energy = profile.fill_light_energy
	fill.rotation_degrees = profile.fill_light_rotation


func is_night() -> bool:
	return phase == HarborLocationProfile.Phase.NIGHT


func night_strength() -> float:
	## 灯体自发光与光斑贴片的强度：夜态 1.0，日落 0.45，其余 0。
	match phase:
		HarborLocationProfile.Phase.NIGHT:
			return 1.0
		HarborLocationProfile.Phase.SUNSET:
			return 0.45
		HarborLocationProfile.Phase.DAWN:
			return 0.12
		_:
			return 0.0


func next_phase() -> int:
	return (phase + 1) % 4


func phase_label() -> String:
	return profile.phase_name(phase) if profile != null else "昼"
