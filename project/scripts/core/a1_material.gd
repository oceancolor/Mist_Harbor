class_name HarborA1Material
extends RefCounted

## A-1 材质族工厂（光斑 / 微光箭头 / Cape Cod 光锥 / 覆盖热力图）。
##
## 🔴 R-ENG-19：原实现是自定义 shader（`unshaded + fog_disabled + blend_mix`），
## 但**自定义 shader 输出 ALPHA 在 Web 导出里静默不渲染**（证据链见 daylight.gd 顶部）。
## 现全部改走 StandardMaterial3D（透明 + unshaded）——实测可渲染。
## 代价：StandardMaterial3D 没有 fog_disabled，远处的光锥会被雾轻微冲淡（密度 ≤0.0075，可接受）。

## 光锥 / 光柱：沿长度先亮后完全消失（近端小 → 中段峰值 → 远端 0），不出现截断面。
static func beam(color: Color, strength: float = 0.16) -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.04), Color(1, 1, 1, strength * 2.6), Color(1, 1, 1, strength * 0.8), Color(1, 1, 1, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 16
	texture.height = 128
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.albedo_texture = texture
	material.vertex_color_use_as_albedo = false
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## 覆盖热力图 / 地面标记：径向柔边色块。
static func overlay(color: Color, strength: float = 0.35) -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, strength)
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	return material
