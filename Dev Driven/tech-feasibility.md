# 《雾港造物记》· 技术可行性答复（7 项阻塞 + core 底座复核）

> 版本 v1.0 ｜ 日期 2026-09-24 ｜ 作者：程基岩（engineering-lead）
> 关联：`water-lighting-params.md` v2.0、`quanzhou-seychelles-art.md` v1.0、`godot-web-perf.md` v1.0、`location-gameplay-design.md`
> 证据来源：**不是推测，是对已导出产物 `index.pck`（GDPC v2 / Godot 4.4.0 / 41 文件）的解包与字节码反汇编**
> 计量口径：1 人日 = 8 有效工时

---

## 0. 结论速览

| # | 事项 | 结论 | 工作量 | 风险 |
|---|---|---|---|---|
| 1 | 塞舌尔三段水深新增 2 个 uniform | ✅ **可行，做** | **0.5–0.75 人日** | 低 |
| 2 | 顶光阴影钳制 −82° | ✅ **可行，做**（但必须附带改 2 个数才有意义） | **0.5 人日** | 低 |
| 3 | 塞舌尔顶光补光 | ✅ **选方案 A**（无阴影平行光），但必须**常驻** | **0.25 人日** | 低（有 1 个陷阱，见 §3.3） |
| 4 | 泉州分时雾曲线 | ⚠️ **前提不成立**——当前 N 键是**瞬间跳转**，无 Tween | **最小 1 人日 / 完整 2 人日** | 中低 |
| 5 | ⭐ 暖光灯是真实光源还是自发光 | 🔴 **确认为真实 `OmniLight3D`，必须改造** | **必做 1 人日 / 完整 2 人日** | **高**（全项目最高） |
| 6 | 地点资产按需加载（.pck 分包） | ⚠️ **可行但不推荐**；本项目应走「几何数据化 + ArrayMesh」 | **2 人日**（推荐方案）vs 3.5 人日（.pck） | 中 |
| 7 | core 共享底座重构 | ⚠️ **复核：13–16 人日**（原估 15–20 偏低项与偏高项各有所抵消） | **13–16 人日** | 中 |
| ＋ | **43.6MB 首屏的真实归因（新增发现）** | 🔴 **与地点资产几乎无关**，是传输未压缩问题 | **0.5 人日 DevOps** | 见 §4 |

> **一句话给主理人**：7 项里 6 项绿灯、1 项（暖光灯）红灯且必须在泉州动工前修掉；第 6 项的立论前提有问题，但结论方向不变（按需加载仍要做，只是换了实现）。

---

## 1. 事实基线：我从导出产物里挖到的硬事实

我无法访问 Godot 工程源码（工作区里只有 `_probe/index.pck`），所以**直接把它解了**：PCK v2 → zstd 解压 41 个文件 → Godot 4.4 的 GDScript 二进制字节码（`.gdc`，zstd 帧 + 标识符表 **XOR `0xB6B6B6B6` 混淆**）→ 还原出标识符表、常量表、token 流（token 结构为 `uint32 = (value<<8)|type` + `uint32 line`）。

**还原精度自校验**：438 个标识符全部还原为合法英文标识符（含 `HarborBuildWorld` / `HarborWorldModel`，与 `global_script_class_cache.cfg` 完全对上）；常量表解析完 108 条后**落点字节精确对齐** token 区起点。结论可信度按源码级处理。

### 1.1 五个一直悬而未决的「待确认」，一次性关闭

| 待确认项 | 事实 | 出处 |
|---|---|---|
| 水面是 ShaderMaterial 还是 StandardMaterial3D？ | **`ShaderMaterial`**，且 GLSL 以**字符串常量硬编码在 `build_world.gd` 里** | 标识符 `sea_material: ShaderMaterial`、`shader.code = "<GLSL>"` |
| 水面是网格面片还是单张大平面？ | **单张 `PlaneMesh(600×600)`**，`position.y = -0.23`，`cast_shadow = OFF`，走 `material_override` | `_build_environment()` L79–103 |
| 岛屿中心是否固定在原点？ | **是**。现有 shader 用 `length(pos.xz)`（即世界原点到岛心距离）。三段水深方案可直接落地 | 现有 shader 第 10 行 |
| N 键是瞬间跳转还是渐变？ | **瞬间跳转，全项目零 `Tween`**（main.gd 438 / build_world.gd 245 / world_model.gd 157 个标识符里没有任何 Tween） | `main.gd` L494–497 |
| 暖光灯是真实光源还是自发光？ | 🔴 **真实 `OmniLight3D`** | `build_world.gd::_add_prop()` L224–231 |

### 1.2 现状参数快照（原样还原，可直接用于填 `LocationProfile`）

`scripts/build_world.gd :: _build_environment()` L59–103：

```gdscript
# L60-68   Environment
environment.background_mode     = Environment.BG_COLOR          # ⚠ 纯色背景，根本没有天空
environment.background_color    = Color("cfdfd6")
environment.ambient_light_source= Environment.AMBIENT_SOURCE_COLOR
environment.ambient_light_color = Color("dceae0")
environment.ambient_light_energy= 0.3
environment.tonemap_mode        = Environment.TONE_MAPPER_LINEAR
environment.fog_enabled         = true
environment.fog_light_color     = Color("cadfd8")
environment.fog_density         = 0.0035                        # ⚠ v1.2 更正：按真实距离（见补遗 §1.0.5）这不是"极淡"，
                                                                #    而是 最近 10.7% / 焦点 15.5% / 35格 23.8% 的一层薄纱。
                                                                #    v1.0 写的"极淡"是按错的单位(d=25)算的，勿引用。
# L69-71   WorldEnvironment
# L72-78   DirectionalLight3D
sun.rotation_degrees            = Vector3(-48, -30, 0)          # ⚠ x = -48°
sun.light_color                 = Color("ffe6bd")
sun.light_energy                = 0.55
sun.shadow_enabled              = true
sun.directional_shadow_max_distance = 85.0                      # ⚠ 世界只有 X/Z ±25，85 浪费 ~28% atlas
sun.shadow_bias                 = 0.05
# ⚠ sun.shadow_blur / shadow_opacity 从未设置 → 保持引擎默认（1.0 / 1.0）
# L79-103  水面
plane.size = Vector2(600, 600); water.position.y = -0.23
water.material_override = sea_material   # ShaderMaterial + 内联 Shader
water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
```

`scripts/build_world.gd :: set_night(value: bool)` L308–318：

```gdscript
night = value
environment.background_color  = Color("182d3b") if night else Color("cfdfd6")
environment.fog_light_color   = environment.background_color
environment.ambient_light_color = Color("7395ad") if night else Color("dceae0")
environment.ambient_light_energy = 0.25 if night else 0.3
sun.light_color  = Color("93b6cb") if night else Color("ffe6bd")
sun.light_energy = 1.75       if night else 0.55
sea_material.set_shader_parameter("deep_color",    Color("1f3d52") if night else Color("5e9e9e"))
sea_material.set_shader_parameter("shallow_color", Color("365764") if night else Color("a3ccc2"))
needs_rebuild = true                       # ⚠ 每次按 N 都会全量重建世界
```

水面 shader 原文（`build_world.gd` L86，可直接 diff）：

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.37, 0.62, 0.62);
uniform vec3 shallow_color : source_color = vec3(0.64, 0.80, 0.76);
varying vec3 pos;
void vertex(){ pos = VERTEX; }
void fragment(){
 float w = sin(pos.x * 1.5 + pos.z * 0.8 + TIME * 0.45);
 float w2 = sin(pos.z * 1.1 - pos.x * 0.4 - TIME * 0.22);
 float lines = smoothstep(0.97, 1.0, w * w2) * 0.11;
 float radial = clamp(length(pos.xz) / 100.0, 0.0, 1.0);
 ALBEDO = mix(shallow_color, deep_color, radial * 0.7 + w * 0.015) + lines;
}
```

**四个必须让美术指导知道的落差：**

1. **没有天空**——`background_mode = BG_COLOR`（纯色）。美术表 §5.2 的 `sky_top_color / sky_horizon_color / sun_angle_max / sun_curve` **当前一个都不存在**，属于净新建能力（+1.5 人日）。
2. **水波参数是硬编码的**——`wave_scale / wave_speed / wave_normal_strength / foam_* / transparency / reflection_strength` 在 shader 里**完全不存在**，`set_shader_parameter` 目前只接了 2 个颜色。美术表 §3 的十几个参数，除颜色外都要先"造出来"。
3. **`reflection_strength` 在当前架构下不可能实现**——水是 `render_mode unshaded`，不参与任何光照与反射。要做只能再加一个 `reflection_color` uniform 做 fake Fresnel（+0.5 人日），或直接砍掉这项。
4. **当前径向梯度被 `/100.0` 压扁了**——世界对角只有 ≈35，实际 `radial*0.7` 最大值仅 0.175，也就是说**现在的水面几乎全是浅水色**，深浅对比基本看不出来。改成可调半径后观感会大幅改善（这是顺带的白赚收益）。

---

## 2. Item 5 · ⭐ 暖光灯（最高优先级，必须先答）

### 结论：🔴 **是真实 `OmniLight3D`，一盏一个，夜间全量实例化。这是当前全项目最大的 Web 端风险，必须在泉州动工前改造。**

### 2.1 证据（`build_world.gd::_add_prop()`，还原自字节码）

```gdscript
# L224
if night and kind in ["lamp", "beacon"]:
    # L225
    var light: OmniLight3D = OmniLight3D.new()
    # L226
    light.position.y    = float(height) + 0.2
    # L227
    light.light_color   = Color("ffbd70")
    # L228
    light.light_energy  = 1.6
    # L229
    light.omni_range    = 3.0 if kind == "lamp" else 5.5   # beacon 5.5
    # L230
    root.add_child(light)
# L231
props.add_child(root)
```

这一段不需要任何推测——它就是源码。`light_energy 1.6 / range 3.0 / color ffbd70` 与 `palette.json` 里 lamp 的 `#EAC989` 同族。

### 2.2 为什么这在 WebGL2 上是灾难（三条叠加）

**① Godot 4 Compatibility 渲染器：每个 mesh 资源默认最多 8 盏 OmniLight。**
官方文档（`OmniLight3D` 类参考 / 3D 灯光与阴影）：Compatibility 下 per-mesh OmniLight 上限默认为 8，可通过 `ProjectSettings.rendering/limits/opengl/max_lights_per_object` 调高，**代价是 shader 编译时间变长、性能下降**；超限表现是「相机移动时灯光闪烁/弹出」。

**② 而本作的地形，是整个岛屿合并成的一个 ArrayMesh。**
`rebuild()` 把所有方块合并进同一个 `PackedVector3Array/PackedColorArray`，用 `add_surface_from_arrays` 生成单一 mesh（`terrain`），配合顶点色控制颜色。

> **① ＋ ② = 灾难**：8 盏的额度不是「每个灯周围 8 盏」，而是**全岛共享 8 盏**。泉州"厝墙灯笼成排"只要超过 8 盏，第 9 盏起的灯**在 WebGL2 下根本不会渲染**，而且相机一动就会 pop 闪烁。

**③ 地形合并恰恰是为 draw call 做的正确优化，两者直接冲突。**
这也解释了为什么这条必须在改任何其他东西之前修：你不可能既保留"单 mesh 全岛"，又保留"每盏灯一个真实光源"。二者只能留一个。

**附带代价**：每次擦掉/放置一盏灯（以及每次按 N）都会改变 mesh 的 shader 排列（1 directional + N omni），Godot 要为该材质**重新编译 permutation**；WebGL2 + 单线程下这是**主线程同步阻塞**，表现为整个页面冻住——这还不算 43.6MB wasm 的下载与初始化开销。

### 2.3 改造方案（推荐，分步）

**第 1 步 · 必做 · 1 人日**
删掉 `_add_prop()` L224–231 整段；给 lamp / beacon 建材改用**自发光材质**：

```gdscript
# 在 _material() 里按建材 definition 分支
mat.emission_enabled            = true
mat.emission                    = Color("ffbd70")
mat.emission_energy_multiplier  = 2.2      # 替代原 light_energy 1.6，需实机微调
# 昼夜二值切换：set_night 时 emission_energy_multiplier 在 0.0 / 2.2 之间切换
```

- **零新增 shader 排列**（emission 是 StandardMaterial3D 的标准分支），对 43.6MB wasm 与加载时间**零影响**。
- 本作所有材质都是纯色无贴图的 StandardMaterial3D，**自发光与实际点亮的视觉差异极小**，肉眼几乎等价。
- 副作用收益：删掉的每段都省一个 `OmniLight3D` 节点 + 一次 `add_child`，N 键切换也更轻。

**第 2 步 · 建议做 · 1 人日（找回"地上有暖光"的实感）**
不用真实光源，而是**把暖光斑烤进已合并地形的顶点色**：地形本来就是单 mesh + 顶点色，`rebuild()` 时对每个顶点计算到最近 N 盏灯的衰减（`1 - clamp(d/3, 0, 1)`），叠加暖色后写入 `PackedColorArray`。

- 用格子哈希把复杂度压到 `O(顶点数 × 邻域灯数)`，**不需要每帧算**，只在 rebuild 时算。
- **零额外 draw call、零 shader 变体、零灯光预算占用**，且"灯下有一圈暖光"的效果保留。
- 这是我认为性价比最高的一步：它同时解决了"夜晚灯火的实景感"与"性能"两个诉求。

**第 3 步 · 不做**
调高 `max_lights_per_object` 是一条**错误的路**：它会让首次 shader 编译从秒级涨到十几秒，Web 端不可接受。明确不做。

**不建议**：保留 ≤ 4 盏"真实灯"给最近的灯（对象池）。这会引入"哪几盏该亮"的歧义，玩家会看到灯光随相机跳动。直接全 emission 更干净。

### 2.4 风险与验证
- **风险：低**（第 1 步是删代码 + 改材质属性；第 2 步复用已有顶点色管线）。
- **验证标准**：泉州建成图放置 ≥ 30 盏灯 + 2 座灯塔，夜间切换 ≤ 0.5 s 完成、无明显卡顿、无 popping；Web 端实测帧率与放置前差距 < 5%。
- **给美术指导的回话**：你的警告是对的，而且比你担心的更糟——限制是**全岛 8 盏**而非"每个区域 8 盏"。改造后视觉几乎无损，我按上面 2 步做。

> ### ⚠️ 给后人：这条结论的失效条件（务必先读）
> **"全岛合并单 ArrayMesh"是本条结论成立的前提。若将来把它改掉，8 盏上限的结论会立刻失效。**
> - 若不拆（维持单 mesh）：per-mesh OmniLight 上限 = **全岛共享 8 盏** → 本条结论成立，emission 改造是唯一正解。
> - 若拆成 chunk（例如 16×16 一块、每块一个 mesh）：**每个 chunk 各自有 8 盏额度** → 灯上限问题自行消解，真实点光源重新变得可行（但仍不推荐，见下）。
> - 拆 chunk 的**其他**收益：可增量重建地形、可局部剔除、可缓解 N 键卡顿（见 §9 A）。
> - 拆 chunk 的代价：draw call 从 1 涨到 chunk 数（16–64），且**地形顶点色 bake 的暖光斑（第 2 步）会失去跨 chunk 的连续性**。
> **结论不要当教条用**：先按"不拆"做 emission 改造（1 人日，立刻见效）；拆 chunk 只在 §9 A 的卡顿实测证明不可接受时才启动，且启动后本条结论必须重估。

---

## 3. Item 1–4 · 四个参数化阻塞项

### 3.1 Item 1 · 塞舌尔三段水深（新增 2 个 uniform）

**结论：✅ 可行，做。批准，零犹豫。**

理由很简单：`sea_material` 已经是 `ShaderMaterial`，`set_shader_parameter()` 的管线**已经在 `set_night` 里跑通了**。加 uniform 不是"改造"，只是"多写两行 GLSL + 多赋两个值"。成本≈0，没有任何拒绝的理由。

**实现**（改 `build_world.gd` L86 的 GLSL 字符串）：

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3  lagoon_color   : source_color = vec3(0.31, 0.85, 0.75);
uniform float lagoon_radius  = 0.0;      // 非热带 = 0
uniform vec3  shallow_color  : source_color = vec3(0.18, 0.66, 0.75);
uniform float shallow_radius = 18.0;
uniform vec3  deep_color     : source_color = vec3(0.04, 0.29, 0.48);
uniform float deep_radius    = 24.0;

varying vec3 pos;
void vertex(){ pos = VERTEX; }

void fragment(){
    float dist     = length(pos.xz);
    float f_lagoon = smoothstep(lagoon_radius,  shallow_radius, dist);
    float f_deep   = smoothstep(shallow_radius, deep_radius,    dist);
    vec3  col      = mix(lagoon_color, shallow_color, f_lagoon);
    col            = mix(col, deep_color, f_deep);
    // 保留原有波浪与 lines，不动
    float w  = sin(pos.x*1.5 + pos.z*0.8 + TIME*0.45);
    float w2 = sin(pos.z*1.1 - pos.x*0.4 - TIME*0.22);
    col += smoothstep(0.97, 1.0, w*w2) * 0.11;
    ALBEDO = col;
}
```

**向下兼容性核对（我替美术验算过）**：非热带地点令 `lagoon_color = shallow_color` 且 `lagoon_radius = 0` 时，`mix(lagoon, shallow, f_lagoon)` 两端同色 → 无论 `f_lagoon` 取何值结果恒定 = shallow_color，然后进入第二段 mix。**确实是零分支、零额外成本，美术的判断完全正确。**

**顺带修掉的老 bug**：把硬编码 `/100.0` 换成可调半径后，`radial*0.7` 被压扁导致的"水面几乎全是浅色"会一并消失。这是四地点都吃到的白赚收益。

**工作量：0.5–0.75 人日**（GLSL 改写 1h + `LocationProfile` 新增字段 1h + `set_shader_parameter` 铺设 1h + 四地点视觉验收 2h）

**风险：低。** 需要注意的唯一一点：现有 shader 是 `unshaded`，改色不影响任何光照计算，回归面很小。

> ⚠️ 附带提醒美术：`reflection_strength` 这项目前**无解**（`unshaded` 不参与反射），需要再加一个 uniform 做 fake Fresnel（+0.5 人日）或从表里删掉。请二选一。

---

### 3.2 Item 2 · 顶光阴影钳制到 −82°

**结论：✅ 可行。批准 −82°，但只钳住角度是不够的——另一个元凶是 `directional_shadow_max_distance = 85`（浪费了近 30% 的 atlas 有效分辨率）。**

**现状**：`sun.rotation_degrees = Vector3(-48, -30, 0)`（`build_world.gd` L72）。

**必须同时做的三件事**（按收益排序）：

```gdscript
# 1. 【收益最大】收紧 shadow atlas 覆盖范围：85 → 60
sun.directional_shadow_max_distance = 60.0
#    依据：世界 X/Z ±25 → 对角 ≈ 35m；环绕相机可视距离 ~60m 足够。
#    85 → 60 意味着同一张 atlas 的线性纹素密度 ×(85/60) ≈ 1.42，即 +42%，
#    直接缓解 peter-panning 与 acne。这一项比钳角度本身更有效。

# 2. 【收益第二】补上从未设置的两个属性（现在用引擎默认 1.0 / 1.0）
sun.shadow_opacity = profile.shadow_opacity     # 泉州 0.50 / 圣托里尼 0.85 / Cape Cod 0.65 / 塞舌尔 0.92
sun.shadow_blur    = profile.shadow_blur        # 泉州 1.5  / 圣托里尼 0.6  / Cape Cod 1.2  / 塞舌尔 0.35

# 3. 【美术要求】角度钳制
var sx := clampf(profile.sun_rotation_x, -82.0, -5.0)   # -82 为幅值上限
sun.rotation_degrees = Vector3(sx, profile.sun_rotation_y, 0.0)
```

四地点取值：泉州 −65（夏至上限 −82）、圣托里尼 −54、Cape Cod −48、塞舌尔 −82。

**工作量：0.5 人日**

**风险：低。** 唯一不确定点：Compatibility 的 `shadow_blur` 底层是 PCF kernel，`0.35` vs `1.5` 的**实际档位是离散的**，实机可能两者差异不明显。建议先做一组 A/B 截图（每组 0.5h）再定值，不要照抄数值直接进开发。

---

### 3.3 Item 3 · 塞舌尔顶光补光：**选方案 A（无阴影平行光）**

**结论：✅ 方案 A。但有一个必须遵守的实现约束。**

**为什么选 A：**

1. **平行光的预算完全独立于 omni/spot。** Godot 4 各渲染后端均允许同屏最多 8 盏 DirectionalLight。多 1 盏**完全不触碰** `max_lights_per_object = 8` 这条已经很紧张的额度。
2. **Godot 官方文档明确**：只有「**开启阴影的**」额外平行光才会摊薄 shadow atlas 分辨率（atlas 在所有投影光之间共享）。我们补光 `shadow_enabled = false` → **零 atlas 代价**。
3. **方案 B 在塞舌尔是语义错误的。** 塞舌尔的设计核心是 `shadow_opacity 0.92` 的锐利硬阴影 + 深暗部 = "赤道顶光"。抬高 `ambient_light_energy` 恰恰是**无方向性地抬暗部**，等于亲手抹掉刚刚做出来的硬阴影。**B 可以用在泉州（本来就要柔），用在塞舌尔是自相矛盾。**
4. 补光颜色 `#B8D4E0`、energy 0.30、侧后方低位 —— 数值我认可，不改。

**⚠️ 必须遵守的实现约束（这条如果不看，会在 Web 上翻车）：**

> **`sun_fill`（第二盏平行光）必须常驻场景，非塞舌尔地点把 `light_energy` 设为 `0.0`，绝不能按需 add_child / remove_child。**

原因：Compatibility 会根据「场景中 participating directional lights 的数量」决定 shader permutation。泉州 1 盏、塞舌尔 2 盏 → 每次切地点都会改变排列 → **触发全场景 shader 重编译**，单线程 WebGL2 下是直接卡死的量级。常驻 2 盏、用 energy=0 关闭，则全局排列唯一，只在**首次**进游戏时编译一次。

```gdscript
# build_world.gd :: _build_environment() 追加
var sun_fill: DirectionalLight3D = DirectionalLight3D.new()
sun_fill.shadow_enabled = false                       # 关键
sun_fill.rotation_degrees = Vector3(-25, 200, 0)
add_child(sun_fill)

# _apply_daylight(phase) 里
sun_fill.light_color  = Color("b8d4e0")
sun_fill.light_energy = profile.fill_energy_night if night else profile.fill_energy
# 泉州 / 圣托里尼 / Cape Cod 的 LocationProfile 里填 0.0；塞舌尔填 0.30
```

**工作量：0.25 人日**

---

### 3.4 Item 4 · 泉州分时雾曲线的前提：**不成立**

> 🔄 **v1.2 追加**：本节关于"N 键瞬间跳转 / 需要 Tween 插值"的结论**仍然成立**（那是昼夜状态机的事，见 core #6）。但**其中的"雾分量"已作废**——雾不再是随时间变化的曲线，而是每地点 2 个常量（昼/夜），见补遗 §1.0。
> 具体说：下面"每帧含 `fog_density` / `fog_light_color` …"这组关键帧里，**`fog_density` 删掉**（改由 `profile.fog_density_for(state)` 按两档取值），**`fog_light_color` 保留**（它跟着天色走，且夜态要走 §5 的下限）。

**结论：⚠️ 当前 N 键是瞬间跳转，且每次切换都会全量重建世界。分时曲线现在毫无意义，必须先改造成插值。**

**证据**（`main.gd` L494–497，还原自字节码）：

```gdscript
func _toggle_night() -> void:
    world.set_night(not world.night)     # ⚠ 布尔取反，无过渡
    _refresh_ui()
    _toast("…" if world.night else "…", "N")
```

且 `build_world.gd :: set_night()` 最后一行 `needs_rebuild = true` → **每次按 N 都全量重建**（包含把所有灯重建一遍，见 Item 5）。**全项目零 `Tween`**（我已遍历三份脚本共 840 个标识符确认）。

⚠️ 顺带纠正一处认知：美术担心的是"曲线vs跳转"，但真正被牵连的还有一项——**每次按 N 都会重建整个世界**，`set_night()` 最后一行就是 `needs_rebuild = true`。在 12000 方块的图上，这是一次满负载重建。所以在这意义上看，昼夜切换先得做到"不必重建就能改光照"，分时曲线才有讨论空间。

**改造方案：**

不做"真实时间流逝"（会导致世界持续重建）。做 **Keyframe + Tween 插值**：

```gdscript
# LocationProfile 里放一组关键帧（清晨/上午/正午/下午/日落/夜间）
# 每帧含 fog_density / fog_light_color / ambient_energy / sun_color / sun_energy / sky_* / 水色

func _toggle_night() -> void:
    var tw := create_tween().set_trans(Tween.TRANS_LINEAR)
    tw.tween_method(_apply_daylight, phase_from, phase_to,
                    profile.sunset_duration_scale * 2.5)   # 塞舌尔 0.55 → 1.4s
    if crossed_dusk_threshold(phase_from, phase_to):
        needs_rebuild = true      # 只有跨过明暗阈值才重建一次（为灯）
```

**关键设计约束：光照插值必须与 rebuild 彻底解耦。** `_apply_daylight(phase)` 只允许写 Environment / Sky / Light 的属性（O(1)、零分配、每帧可调用），**绝不能触发 rebuild**。现在的 `set_night()` 把三件事（赋值光照、切换灯、`needs_rebuild`）捆在一起，必须拆开。

**Godot 4.4 单线程下 `Tween` 正常可用**（它由主循环 `_process` 驱动，不依赖线程），这一点不用担心。

**工作量：**
- **最小版（两状态 2.5s 渐变，够泉州雾"由浓到淡"的观感）**：**1 人日**
- **完整分时曲线版（6 关键帧 × 4 地点，含美术调参）**：**2 人日**

**风险：中低。** 难点从来不在代码（代码 1 天内能通），而在"6 关键帧 × 4 地点 = 24 组参数"的美术调试。建议先只做泉州，其余三地点沿用两状态版。

> 📌 给美术的回话：**你的判断完全正确，分时曲线目前确实无意义**。建议按"先做泉州 6 帧、其余三地走两状态"推进。

---

## 4. Item 6 · 地点资产按需加载：结论是「做，但不做 .pck」

### 4.0 先纠正前提：43.6MB 首屏**不是**地点资产造成的

这一条比 .pck 方案本身更重要，请主理人务必先看。

- 已导出 `index.pck` 总计 **373,456 字节**（含 8 个 GLB 转的 `.scn` 共 ≈83KB、中文字体 ≈210KB、脚本 ≈52KB）。
- 也就是说：**四个地点的全部几何资产加一起，量级是几十 KB～几百 KB，不是 MB。**
- 43.6MB 的 `index.wasm` 是 **Godot 引擎本体**，与地点数量基本无关（新增地点不会让 wasm 涨——shader 是运行时从文本编译的，不在包里）。

**结论：**
- 「多地点会把包体撑爆」这个前提是**错的**。四地点全内置的资源增量 ≈ 1–2MB，相对 43.6MB 是 3%左右。
- 「43.6MB 首屏是转化杀手」是**对的**，但解药是：
  1. **确认服务器开了 Brotli / gzip**（Godot Web 导出建议在服务端开启压缩；wasm 文本密度极高，Brotli 通常能压到 **~9–12MB**）。**这是 0.5 人日 DevOps，收益大于整个 .pck 工程。**
  2. 若需进一步压，走**自定义编译模板**裁掉未使用模块（本作不用物理刚体动力学、不用 TILED、不用 mono），可再降数 MB。**这是另一个 topic，不在此次 7 项范围内，我先登记为 R-ENG-01。**

**所以：按需加载仍然要做，但理由要换**——不是为了包体，而是为了：
- 内存（已挂载资源不能被卸载，见下）；
- 后续 DLC 的交付通道；
- 避免每次加地点都要重导整个主包（迭代速度）。

### 4.1 `.pck` + `load_resource_pack()` 正式评估（答复主理人的指定问题）

**可行性：✅ 可行。**
Godot 提供 `ProjectSettings.load_resource_pack(path, replace_files=false)`；`.pck` 由导出预设「Export PCK/Zip → Export Mode: *Export selected resources (non-runnable)*」产出，运行时挂载后进 `res://` 命名空间，之后 `ResourceLoader.load()` 透明可用。Web 导出支持。

**部署要求：**
- 任意静态托管 / CDN / OSS / Pages 即可；
- **必须 HTTPS 且同域或正确配置 CORS**（Godot Web 用 fetch/XHR 从远端取 pack）；
- 建议让浏览器处理压缩（服务端开 br 即可），**不要**手工 gzip 后再套一层 CDN 压缩，避免二次开销。

**副作用（每一条都是实测会踩的）：**

| # | 副作用 | 说明 |
|---|---|---|
| 1 | **引擎版本锁死** | pack 与导出时的 Godot 版本必须一致，否则直接 "Pack version unsupported"。本作从 4.4 升 4.5 时，**所有**历史地点包必须重导。单人开发维护多年，这是隐性长期负担。 |
| 2 | **主线程阻塞且无法卸载到后台** | 单线程（`GODOT_THREADS_ENABLED = false`）下 `load_resource_pack()` 是**同步**的；`ResourceLoader.load_threaded_request()` 在没有线程时退化/不可用。必然卡帧，只能配加载遮罩。 |
| 3 | **Godot 4 没有 `unload_resource_pack()`** | 一旦挂载就**永久占用内存**。玩家四个地点全逛一遍，内存占用回到"全量加载"的量级，对浏览器标签的 2–4GB 上限是真实风险。 |
| 4 | **资源路径/UID 冲突** | 多个 pack 的资源都在 `res://` 下共存，需严格按 `res://loc/<id>/…` 分区并管理 UID，否则同名 `Material` 会串。 |

### 4.2 明确结论：**本项目不用 .pck，改走「几何数据化 + 运行时 ArrayMesh」**

理由：`.pck` 的唯一优势是"承载任意 Godot 资源（贴图/场景/动画）"。而本作：

- **零贴图**（延续本体，纹理一律法线 fake 或顶点色）；
- 材质是运行时 `StandardMaterial3D.new()` 生成的**纯色**；
- 所有模型都由 Blender 脚本 `art/generate_harbor.py` **确定性程序化生成**（seed 240910）；
- `main.tscn` 是空的，全部靠代码构建。

→ 也就是说：`.pck` 那把"万能工具箱"，本作一样东西都用不上。

**推荐方案：**

1. 给 `art/generate_harbor.py` 加一个 **JSON / 紧凑二进制导出模式**（几何已程序化，加一个 dump 极其便宜）。
2. 地点几何以「顶点数组 + 面数 + 基准色」交付。估算：**每地点 150–400 KB**（float32 紧凑格式；塞舌尔新增 4,350 面，bin ≈ 250KB）。
3. 运行时 `HTTPRequest` 下载（**异步，单线程也不阻塞主循环**）→ 用已有的 `add_surface_from_arrays` 管线构造 `ArrayMesh`。**`build_world.gd` 里现成的合并管线几乎零成本复用。**
4. 可选：用 IndexedDB（`user://`）缓存，二次进入秒开。

**收益：零引擎版本锁 / 可流式 / 可热更 / 可按地点精确卸载（自己管内存，比 Godot 靠谱）/ 可被肉眼校验 / CI 无需双导出。**

**工作量对比：**

| 路线 | 工作量 | 长期维护成本 |
|---|---|---|
| **推荐：几何数据 + ArrayMesh** | **2 人日**（导出脚本 0.5 + 运行时 loader/缓存 1.0 + 旧 GLB 路径兼容 0.5） | 低 |
| .pck + load_resource_pack | 3.5 人日（导出预设 1.0 + 挂载/进度/遮罩 1.0 + 版本管理流程 0.5 + CI 双导出 1.0） | 高 |

> **何时才该换回 .pck**：未来若某个地点要引入**贴图**（比如夜景烘焙 emissive 贴图、水面 foam 纹理），那时再引入 .pck 局部承载。现在不要为尚不存在的需求预付这笔成本。

### 4.3 Shader 编译阻塞主线程的解法（**无论走哪条路线都要做**）

WebGL2 + 单线程下，shader 编译是**同步**的（走浏览器的 GLSL 编译器，且没有 Worker 可甩）。针对本作，解法意外地简单：

1. **离屏预热一帧**：进入地点前，在一个 1×1 的离屏 `SubViewport` 里，把该地点会用到的**每一种材质**各渲染一帧，强制 Godot 编译 permutation；预热完成后再切场景并收起遮罩。
2. **本作的排列数量是个位数**：材质是 `StandardMaterial3D` + 顶点色，排列维度只有 `unshaded? / vertex_color_use_as_albedo? / emission? / transparency?`。预热预计 **< 0.3 s**，而不是常见的十几秒。
3. **固定灯光数量**（呼应 Item 3）：常驻 **2 盏平行光 + 0 盏 omni**（Item 5 改造后 omni 归零），让 directional count 的排列全局唯一 → **切地点不再重编译**。这是 Items 3 和 5 之外，第三重保险。
4. UI 上配 `await RenderingServer.frame_post_draw` + "正在布置岛屿…" 遮罩，避免看起来像死了。

**工作量：0.5 人日**（可与 core 底座并行做）

---

## 5. Item 7 · core 共享底座重构：**复核结果 13–16 人日**

### 5.1 复核结论

原估 **15–20 人日**。我的复核是 **13–16 人日（中位 14）**。原估计既不是全然高估，也不是全然低估——是**两笔错误的方向相反，恰好部分抵消**：

- **省下来的地方**（−2～−3）：水面已经是 `ShaderMaterial`，`set_shader_parameter` **已经跑通**了，不需要重建水体管线；顶点色 / `add_surface_from_arrays` 的合并管线也已成规模，可直接复用。
- **多出来的地方**（+2～+3）：發現**三项能力当前根本不存在**，属于**净新建**而非"抽差异"：
  1. **天空**（`BG_COLOR` 纯色，无 ProceduralSkyMaterial）→ **+1.5**
  2. **分时光照驱动**（无 Tween、光/env/set_night 三者耦合）→ **+1.0～2.0**
  3. **资产按地点切换**（`scenes` 字典目前是全局单一时刻的）→ 已含在下面表里

**建议把这块正式命名为 `MH-CORE-001`，预算打 15 人日（留 buffer）。**

### 5.2 明细表

| # | 子项 | 人日 | 备注 |
|---|---|---|---|
| 1 | `LocationProfile` 资源（.tres 结构 + 加载器 + 校验） | **1.5** | 结构直接采用美术 §7 草案，我认可，不需改 |
| 2 | `_build_environment` / `_apply_daylight` 参数化（去除全部硬编码） | **2.0** | 包含把 `set_night` 拆成「赋光照」＋「切灯」＋「重建」三件事 |
| 3 | 水 shader 参数化 + 三段水深（Item 1） | **0.75** | 顺带修 `/100.0` 梯度压扁 bug |
| 4 | DirectionalLight 组参数化（含钳制 + 常驻补光，Items 2/3） | **0.75** | 含 shadow_blur / shadow_opacity 首次接入 |
| 5 | **ProceduralSkyMaterial 接入（净新建）** | **1.5** | ⚠ 当前压根没有天空；含 `sky_top/horizon/sun_angle_max/sun_curve` |
| 6 | 昼夜 keyframe + Tween 驱动（Item 4） | **1.0** 最小 / **2.0** 分时 | 建议先最小版 |
| 7 | 建材/植物表按地点切换（palette + model 表分区） | **1.5** | 与 `reskin-matrix-assessment.md` 的选址表对接 |
| 8 | 地点资产 loader（按 §4.2 推荐路线） | **2.0** | 含 IndexedDB 缓存 |
| 9 | shader 预热 + 遮罩 | **0.5** | 可与上并行 |
| 10 | 测试：单点冒烟 + 视觉回归截图 + JS 内存/帧率检查 | **1.5** | 严守真（QA）接入点 |
| — | **小计** | **12.5 / 13.5** | → 含 buffer **13–16** |
| ＋ | **暖光灯 OmniLight→emission 改造（Item 5，强烈建议不塞进 core，但要排在泉州之前）** | **1.0 / 2.0** | 独立任务 `MH-ENG-002` |

> **不含**：美术资产生产（建模/调色）、三地点内容填充、`design-strategist` 侧的玩法实现。这部分与 core 正交。

### 5.3 推荐执行顺序（按 risk-adjusted）

```
① MH-ENG-002  暖光灯改造        [1–2 人日]  ← 必须最先，它是其他一切的前提
② MH-ENG-003  shader 预热 + 灯数固定  [0.5 人日] ← 与 ① 并行
③ MH-ENG-004  水 shader 参数化 + 三段水深 [0.75 人日] ← 低风险热身
④ MH-CORE-001 LocationProfile + env/light 参数化 + 钳制/补光 [5 人日]
⑤ MH-ENG-005  昼夜 Tween（最小版）[1 人日]
⑥ MH-ENG-006  地点资产 loader [2 人日]
⑦ MH-ENG-007  ProceduralSkyMaterial [1.5 人日]
⑧ MH-ENG-008  泉州接入 + 回归 [3 人日]
```

**1 人日的 spike（强烈建议先做，用来给第 6/7 项定价）**：
新建一份泉州的 `LocationProfile`，只跑最小闭环（换 palette + 换光参数 + 换地点几何数据），**不做天空、不做分时**。跑通后，主理人对 core 估值的信心会从"纸面估算"变成"实测外推"。

---

## 6. 风险登记（新增项）

| ID | 风险 | 等级 | 缓解 |
|---|---|---|---|
| **R-ENG-01** | **43.6MB wasm 的真实归因未被确认**——若服务端未开 br/gzip，则所有"首屏优化"讨论都建立在错误前提上 | **高** | ⚠️ **这是 DevOps / 托管配置调查，不是资产优化项。** 0.5 人日：**先确认托管是否开了 Brotli/gzip**。结论无论成败，**都不应导向削减美术资产**——已导出 `index.pck` 仅 373KB，资产不是瓶颈。后人请勿把这条误读为"需要缩减美术"。 |
| **R-ENG-02** | 暖光灯 OmniLight 超限导致丢光/闪烁/重编译 | **高** | Item 5 第 1 步必须在泉州动工前完成 |
| **R-ENG-03** | 切地点改变 directional 灯数 → shader 重编译卡死 | 中 | 常驻 2 盏平行光（含塞舌尔补光），energy=0 关闭 |
| **R-ENG-04** | `shadow_blur` 在 Compatibility 下档位离散，美术给定值可能无效 | 中 | 先出 1 组 A/B 截图再定值 |
| **R-ENG-05** | `max_lights_per_object` 被后续开发者调高，引发带回 R-ENG-02 | 中 | 明确写入 `control-manifest.md`：**禁止调高，默认 8 不动** |
| **R-ENG-06** | 合并单 mesh 与 per-mesh 灯限的结构性冲突，在后续任何"加真实光源"需求上都会复发 | 中 | 写入控制清单：**本作禁止真实点光源，一律 emission + 顶点色 bake** |
| **R-ENG-07** | `.pck` 若后续引入，会导致 Godot 版本锁 + 无法卸载 | 中 | 按 §4.2 先走几何数据；引入 .pck 需重走决策 |

---

## 7. 需要主理人 / 用户拍板的三项

1. **`reflection_strength`（塞舌尔 0.55）如何处理？**
   - A. 加 `reflection_color` uniform 做 fake Fresnel（+0.5 人日，效果中等）
   - B. 从参数表删除该项（0 成本，接受"潟湖如镜"改为纯靠高饱和青绿表达）
   → 我建议 **B**：`unshaded` 水本来就不反射，"潟湖如镜"的观感主要由饱和色 + 窄泡沫带承担，不值得为它加 uniform。

2. **泉州分时曲线做完整版还是最小版？**（1 vs 2 人日）
   → 我建议**先做最小版**（白天/夜晚两个状态的 2.5s 插值），泉州先上线。分时曲线的边际收益主要在"泉州湾晨雾 → 洛阳桥落潮"这条叙事轴上，等 Web 端实测帧率与玩家反馈验证后，再补完整 6 关键帧。

3. **43.6MB 的优化是否列入本次排期？**
   → 强烈建议列。0.5 人日确认 Brotli，是所有 Web 指标里最大的单点杠杆，且独立性强，不阻塞任何美术/设计工作。

---

## 8. 附：证据与方法（可复现）

反向工程产物位于 `_probe/`：

| 文件 | 用途 |
|---|---|
| `_probe/extract_all.py` | PCK v2 解包（41 文件 → `unpacked/`） |
| `_probe/decomp.py` | `.gdc` zstd 帧解压 |
| `_probe/decomp_ids.py` | **Godot 4.4 标识符表还原（XOR `0xB6B6B6B6`）** |
| `_probe/parse_consts2.py` | 常量表解析（含 float32/float64 flag 区分） |
| `_probe/dump_tokens.py` | token 流还原（`(value<<8)|type` + `uint32 line`） |
| `_probe/main.gdc.dec` / `build_world.gdc.dec` / `world_model.gdc.dec` | 解压后字节码 |

**自校验记录**：main.gd 还原出 438 个标识符，前两位为 `Node3D` / `Model`，且有 `HarborWorldModel` / `HarborBuildWorld` 与 `global_script_class_cache.cfg` 完全吻合；标识符表终止字节 18100 与常量表起点 18104 严丝合缝；常量表解析 108 条后落点 12072 < token 区起点 16712（中间为对齐填充）。**结论按源码级可信度处理。**

> 备注：源码仓库（`scripts/*.gd`、`art/generate_harbor.py`）不在本工作区。若主理人能提供工程目录，我可直接给出带行号的 patch 而非依据还原的行号。还原行号已精确 ±1 行。

---

# 补遗 · 第二轮答复（v1.1）

> 🔄 **v1.2 追加（2026-09-24，用户拍板后）**：**雾已降级为「每地点视觉常量」**。
> 新增 §1.0（雾的最终口径，**覆盖 §1.1–§1.5**）、§7.1（R-ENG 雾相关条目 v1.2 复核）、§11（人日影响核算）。
> **读本文档时，凡涉及雾，一律先看 §1.0。** §1.1–§1.5 保留为沿革，作废项已在 §1.0.3 列全。

> 版本 v1.1 ｜ 日期 2026-09-24 ｜ 作者：程基岩（engineering-lead）
> **本轮方法论升级**：上一轮我把已导出的 `index.pck` 反编译到源码级；这一轮我直接读了 **Godot 4.4 分支源码**（`raw.githubusercontent.com/godotengine/godot/4.4/`，`version.py` 实测 = **4.4.2-rc**）。
> 因此本轮 ①②③ 的结论**不是"读文档推断"，是逐行源码判定**，证据 URL 见 §8。
> **本文对 v1.0 的取代范围**：§2（暖光灯方案②③步）、§5.2 第 ＋ 行（暖光灯不入 core）、以及任何"雾按 exp² 计算"的隐含前提。**冲突处以本节为准。**
### ⭐ 本文档的编号命名空间（2026-09-24 定，读本文档前必看）

本项目流通着**三套**编号，曾互相撞名，现按此表固定：

| 编号 | 归属 | 含义 | 维护人 |
|---|---|---|---|
| `MH-ENG-00X` / `MH-CORE-001` | 工程任务 | `MH-ENG-002a` = 删 `OmniLight3D` + 灯体 emission；`MH-ENG-002b` = 光斑贴片 MultiMesh | 程基岩 |
| 试玩 `T0-T4` | 发布 / 试玩里程碑 | T1 = 泉州切片首次对外试玩 | release-ops-lead / team-lead |
| 天空 `T1/T2` | 美术方案命名 | 沿用 `water-lighting-params.md` §5.2.1：T1 = 顶点渐变天空盒，T2 = `ProceduralSkyMaterial` | 美术 |

> 🔴 **规则：本文档内不再出现裸 `T1` / `T2`。** 工程任务一律写 `MH-ENG-00X`，天空一律写「天空 T1/T2」，试玩批次一律写「试玩 T0-T4」。
> ℹ **历史别名（仅供追溯旧消息，勿再使用）**：~~照明 T1~~ = `MH-ENG-002a`，~~照明 T2~~ = `MH-ENG-002b`。
> ⚠️ **为什么值得立这么一条**：撞名不是一次性的 —— 工程、发布、美术三方各自独立地、都很合理地选了 T1/T2。**这类冲突在当下完全看不出来，只在跨文档引用时爆发**，所以必须在每份文档的入口处显式声明，而不是靠"上下文能猜出来"。



## 0. 六项结论速览

| # | 事项 | 结论 | 影响面 | 工作量 |
|---|---|---|---|---|
| ① | Godot 4.4 默认雾模型 | ✅ **判定完毕：线性指数（Beer–Lambert）`O(d)=1−exp(−ρ·d)`**。<br>🔄 **v1.2 终裁（用户拍板）：雾降级为「每地点视觉常量」——回到默认 EXPONENTIAL、只有 `fog_density` 一个标量、只分昼/夜两档（4 地 × 2 = 8 个值，美术眼睛调）。DEPTH 迁移方案作废，但它没错——作废的是我们自设的那组判据** | 🟢 **阻塞解除** | 接入 **0.2 人日**（原 0.5）；**见 §1.0（覆盖本节 ① 行）与 §11 人日核算** |
| ② | `unshaded` / `blend_mix` 是否绕过 fog | 🔴 **都不绕过**（源码证实）。但正解不是 CanvasLayer，而是 **`render_mode fog_disabled`**（4.4 已有） | 🟢 省下 0.75–1 人日退路成本 | **≈0**（每个材质加一个 token） |
| ③ | 暖光灯改 `blend_mix` | ✅ **开销与 `blend_add` 完全相同**；**默认方案应为 MultiMesh 而非 ArrayMesh 合并**，L0 的 dirty flag 因此**根本不需要存在** | 🟢 | MH-ENG-002a **0.5–0.75 人日** / MH-ENG-002b **1 人日** |
| ④ | Cape Cod 能否用光斑替代 `SpotLight3D` | ✅ **可行，且应当采用**；`SpotLight3D` **完全不需要** | 🟢 解除 Cape Cod 排最后的两条理由之一 | 含在 MH-ENG-002b 内，**增量 ≈ 0.25 人日** |
| ⑤ | 夜间雾色下限 | ✅ 已写成可直接落地的实现条目（§5），含 `LocationProfile` 字段、代码、验收测试 | 🟢 | **0.25 人日** |
| ⑥ | 历史定性更正 | ✅ 已按正确版本改写（§6）；暖光灯改造重定级为 **core 层建材改造** | — | — |

---

## 1. ① 雾模型判定 → **v1.2 终裁：雾降级为「每地点视觉常量」**

### 1.0 ⭐ 最终口径（v1.2 · **本节以此为准**；§1.1 及以下为沿革）

> 本节由用户拍板后追加（2026-09-24）。**它与 §1.1–§1.5 的结论冲突时，一律以本节为准。** §1.1–§1.5 保留为沿革，其中被作废的部分已在 §1.0.3 逐条列出。

#### 1.0.1 裁定（用户已拍板，工程侧直接执行，不再讨论）

> 用户原话：**「雾这个概念并不是必须的，如果它造成了内在的冲突，我们可以不要这个设定。仅仅是全世界有特色的海岛、海角和海港风光和地貌的建造和文化底蕴的体现就已经足够了。」**
> 裁决结果：**降级，不删除。**

| 项 | v1.1（作废） | ⭐ **v1.2（生效）** |
|---|---|---|
| 雾模型 | 迁移到 `FOG_MODE_DEPTH` | **回到默认 `FOG_MODE_EXPONENTIAL`** |
| 需要改的代码 | 切换 mode + 每帧换算 begin/end | 🔴 **零。项目从未设过 `fog_mode`，回到默认就是不动它** |
| 可调参数 | `begin / end / curve / density` | **只有 `fog_density` 一个标量** |
| 档位数 | 四地 × 四态 = 16 组 | **昼档 / 夜档 2 档**；**晨态与日落态沿用昼档**。四地 × 2 = **8 个数值** |
| 数值来源 | 满足数学判据后反解 | **美术用眼睛调**（工程侧提供 §1.0.5 换算参考） |
| 四态概念 | 雾随四态变 | **四态保留为光照概念**（太阳色 / 水色 / 天色仍按四态切换），**雾不参与** |

> 🔴 **「一行代码都不用改」这句话本身就是一条实现要求，不是省事的说法。**
> `build_world.gd::_build_environment()` 从头到尾没有出现过 `fog_mode`（v1.0 §1.2 快照可核），`Environment.new()` 的成员初始化器给的就是 `FOG_MODE_EXPONENTIAL`。
> **所以禁止有人为了「让代码更明确」补一句 `environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL`** —— 那不是还原，那是一次 `set_fog_mode()` 调用，会踩 R-ENG-10（§1.0.6 陷阱 1）。

#### 1.0.2 为什么降回去 —— **优先级纠偏，不是技术失败**

> ### ⭐ 请务必读完这段，再改任何雾相关代码
> **降级雾不是技术失败，是优先级纠偏。** 这个产品的差异化在地点身份（闽南红砖 / 爱琴海白崖 / 科德角沙丘 / 塞舌尔花岗岩）与文化底蕴，不在大气效果。把大量工程投入到"让雾在 25 格处精确遮蔽 61.9%"这类**我们自己设定的判据**上，最后还让它成为唯一阻塞项，本身就是优先级错配的证据。

拆成三层写清楚，**防止后人误读成"DEPTH 方案有错"**：

1. **DEPTH 方案本身没有错。** 它是对的：`O(d) = pow(smoothstep(begin, end, d), curve) × density` 提供了「`begin` 以内严格为 0 + 远处封顶」的形状，这恰恰是 EXPONENTIAL 结构性做不到的（§1.0.5 限制一）。**作废它，不是因为它不成立。**
2. **驱动它的那组数值判据是我们自己加的。** 「25 格 ≥60%」「8 格 ≤12%」「晨/昼落差 ≥2.0」这三条，**没有任何一条来自玩家需求或用户原话**——它们是为"让四态看起来有区别"而自行设立的中间目标。
3. **正是这组判据逼出了 DEPTH。** 线性指数模型下它们数学无解（§1.2 的可行域为空证明），于是"必须换模型"成了唯一出路。**问题出在需求层，不在方案层。**

> ### ⭐ 与 v1.1 那条教训并列、且更贵的第二条方法论（两条都不许删）
> - **v1.1 教训（前提层）**：`fog_mode` 默认是 exp² 这个**前提**错了 → 推导再对也白搭。→ **先查后算。**
> - **v1.2 教训（需求层）**：判据是"让雾精确遮蔽 61.9%" → 前提对了、推导对了，**需求本身不值得做**。→ **先问值不值，再问对不对。**
>
> **需求层的错误比前提层更贵，而且更难自检**：前提错了还能靠"查源码 / 实测"证伪——**有外部事实可以对照**；而"25 格要遮蔽 60%"这种自己给自己定的判据，**没有任何外部事实能否证它**，它只有在被追到"为了它要换渲染模型"这一步时才会暴露。
> 📌 **本项目此后凡设立数值判据，一律要求三件事**：① 写出它服务哪一条**玩家可感知**的体验；② 写出它是谁提的（用户 / 设计 / 美术 / **工程自设**）；③ **工程自设的判据，在引发架构改动前必须先回问一次"这条还要不要"。**

#### 1.0.3 🔴 作废清单（**已作废，勿用**；保留沿革仅供追溯）

| # | 作废项 | 原出处 | 作废理由 |
|---|---|---|---|
| 1 | `FOG_MODE_DEPTH` 迁移方案 | §1.3 全节 | 判据作废 → 驱动消失；默认模型已够用 |
| 2 | `begin / end` 每帧按 `pitch` 换算（V4） | §1.3.2 风险二 | EXPONENTIAL 没有 `begin/end` 可算 |
| 3 | 格 → 世界单位换算表 `D(x) = √(x² + 2Rx·cos p + R²)` 及 `D(x,ℓ)` | §1.3.0 | **降级为调参参考**（§1.0.5），不再是必填项 |
| 4 | 四地四态 16 组数值表（含 §1.3.1 美术终值） | §1.3.1 / 美术 §5.1.1.4 | 改为 **8 个值**（昼/夜 × 4 地） |
| 5 | 🔴 「25 格 ≥60%」「8 格 ≤12%」「晨/昼落差 ≥2.0」等**全部数值判据** | §1.2 / §1.4 | **这些是我们自己加的，不是玩家要求** —— 见 §1.0.2。留着会再次逼出架构改动 |
| 6 | 8-bit 色阶标定法与反查表 | §1.5 | 改为"眼睛看着调"；色阶表会把人重新引回判据思维 |
| 7 | A-3 pitch 联动验收测试 | §1.5 末 | 无 `begin/end` 可联动；**且它防的那个问题在 EXPONENTIAL 下不存在**（§1.0.7 收益二） |
| 8 | 泉州"分时雾曲线"里的雾分量 | v1.0 §3.4 | 雾不再是随时间变化的曲线，是每地点常量 |

#### 1.0.4 ✅ 保留清单（**仍然生效，不许省**）

| # | 保留项 | 为什么不能省 |
|---|---|---|
| 1 | ⭐ **夜间雾色与背景解耦**：`fog_light_color = max(sky_horizon, night_fog_floor)`；四地夜态下限 泉州 `#6A7078` / 圣托里尼 `#5A6A84` / Cape Cod `#4E5A66` / 塞舌尔 `#5E7A82` | 🔴 **`fog_light_color = background_color` 不修，夜雾会变成"黑烟"，25 格外全吞，夜间建造直接不可用。** 实现见 §5 —— **不变，0.25 人日不变** |
| 2 | **`render_mode fog_disabled`**（泉州微光箭头 / Cape Cod 覆盖热力图 / 光斑贴片） | 见 §2；V2 仍是唯一需实机验证项 |
| 3 | 相机常量事实（`PROJECTION_ORTHOGONAL` / `R = 48.0` / `pitch 0.72` clamp `0.38–1.25` / `zoom 32`） | **降级为"调参参考"**（§1.0.5），不再是必填项 |
| 4 | `fog_aerial_perspective` 在 Compatibility 下是死参数 | 别把它当调参旋钮（§1.3.3 陷阱 4） |
| 5 | 四态光照（太阳色 / 水色 / 天色 / ambient）按四态切换 | 圣托里尼与塞舌尔的招牌画面是**日落**，戏剧性由**天色与光色**承担，不靠雾（美术侧已确认该方向） |

#### 1.0.5 ⭐ 「density → 观感」换算参考（美术调参用 · 唯一的数）

**（a）先记住一件事：引擎用的是相机到片元的欧氏距离，不是格数。**

`O(d) = 1 − exp(−ρ·d)`，其中 `d = length(vertex)`。等距视角下相机是斜的，所以**每一片元的距离里都压着约 48 的底噪**——屏幕上根本取不到 8 / 16 / 25 这种距离。想预测观感，必须按下表换算。

| 位置 | 相机到片元的距离 `d` | 备注 |
|---|---|---|
| 可见范围最近处 | ≈ **32.2** | 全屏下沿（含横向 ℓ=30） |
| **焦点（屏幕中心轨道点）** | **48.00** | ⭐ `D(0,0) = R`，**与 pitch 无关**，是最稳的锚点 |
| 8 格 | **54.27** | |
| 16 格 | **60.95** | ⚠️ team-lead 任务书里的"60.2"与同一公式不自洽（8→54.27、25→68.80 都能对上，16 格应为 60.95）。差异 0.75 单位 → 遮蔽率差 <0.3pp，**不影响调参**，但按 60.95 记，避免后人再来回一次 |
| 25 格 | **68.80** | |
| 35 格 | **77.81** | |

**（b）density → 遮蔽率对照表（%）。** `ρ` = `fog_density`，行为距离，列为 `O = 1 − exp(−ρ·d)`：

| `ρ` | 32.2 最近 | **48.0 焦点** | 54.27 (8格) | 60.95 (16格) | **68.80 (25格)** | 77.81 (35格) | 近→远落差 |
|---|---|---|---|---|---|---|---|
| 0.0005 | 1.6 | 2.4 | 2.7 | 3.0 | 3.4 | 3.8 | 2.2 |
| 0.001 | 3.2 | 4.7 | 5.3 | 5.9 | 6.7 | 7.5 | 4.3 |
| 0.002 | 6.2 | 9.2 | 10.3 | 11.5 | 12.9 | 14.4 | 8.2 |
| **0.0035** ⭐ | **10.7** | **15.5** | **17.3** | **19.2** | **21.4** | **23.8** | 13.2 |
| 0.005 | 14.9 | 21.3 | 23.8 | 26.3 | 29.1 | 32.2 | 17.4 |
| 0.006 | 17.6 | 25.0 | 27.8 | 30.6 | 33.8 | 37.3 | 19.7 |
| 0.0075 | 21.5 | 30.2 | 33.4 | 36.7 | 40.3 | 44.2 | 22.8 |
| 0.008 | 22.7 | 31.9 | 35.2 | 38.6 | 42.3 | 46.3 | 23.6 |
| 0.01 | 27.5 | 38.1 | 41.9 | 45.6 | 49.7 | 54.1 | 26.5 |
| 0.015 | 38.3 | 51.3 | 55.7 | 59.9 | 64.4 | 68.9 | 30.6 |
| 0.02 | 47.5 | 61.7 | 66.2 | 70.5 | 74.7 | 78.9 | **31.4**（峰值） |
| 0.03 | 61.9 | 76.3 | 80.4 | 83.9 | 87.3 | 90.3 | 28.4 |
| 0.05 | 80.0 | 90.9 | 93.4 | 95.3 | 96.8 | 98.0 | 18.0 |

> ### 🔴 读作三条结构性限制（**调参前必读**，否则会白调一天）
>
> **限制一 · EXPONENTIAL 下「近处干净」不可达。** 没有 `begin`，焦点处（48.0）的遮蔽率就是 `1 − exp(−48ρ)`，**永远是正的**。要焦点 ≤2% 得 `ρ ≤ 0.00042`，此时 35 格处只有 3.2% —— **雾等于不存在**。这是当初选 DEPTH 的唯一理由，现在作为代价接受。
>
> **限制二 · 远近落差最多 ≈31 个百分点，再多买不到。** 落差在 `ρ ≈ 0.02` 达到峰值 31.4pp，之后**反而下降**（ρ=0.05 只剩 18pp，因为远近全糊死了）。而 `ρ=0.02` 时焦点已被雾掉 **61.7%** —— 那不是"有雾的远景"，那是"整块屏幕隔着一层纱"。
> → **实用区间：`ρ ∈ [0.001, 0.006]`**（焦点 4.7%–25%、25 格 6.7%–33.8%）。**ρ > 0.01 基本不可用。**
>
> **限制三 · ⭐ `0.0035` 不是"几乎无雾"，它是"已经上线、且没人投诉过"的那一档。**
> v1.0 §1.2 我写"极淡"是按错的单位（`d = 25`）算出来的 8.4%；按真实距离，现状 **0.0035 = 最近 10.7% / 焦点 15.5% / 35 格 23.8%** —— 这是一层**明显但可接受**的薄纱，不是"几乎没有"。
> → **调参锚点请这样用**：`0.0035` = 现在玩家看到的样子；想要"更通透"往 0.001–0.002 走；想要"更沉"往 0.005–0.006 走。
> → 顺带一个巧合（不必用，但有助于校准直觉）：旧 DEPTH 方案里泉州昼"25 格 23.0%"这个目标，在 EXPONENTIAL 下对应 `ρ ≈ 0.0038` —— 也就是说**旧昼档观感本来就能用单个 density 近似复现**，只是近处会多出约 16% 的底噪（限制一）。

#### 1.0.6 🔴 保留的陷阱清单（**在 EXPONENTIAL 下仍然成立的那些**）

1. 🔴 **禁止任何 `fog_mode` 写入**（包括"显式设成默认值以求清晰"）。**唯一安全的做法是从头到尾不调用它。** → **R-ENG-10（休眠）**
   - 🔴 **精确机制（2026-09-24 补 · 比此前写的更糟，务必读这一段）** —— `scene/resources/environment.cpp` 原文：
     ```cpp
     void Environment::set_fog_mode(FogMode p_mode) {
         if (fog_mode != p_mode && p_mode == FogMode::FOG_MODE_EXPONENTIAL) {
             set_fog_density(0.01);
         } else {
             set_fog_density(1.0);
         }
         fog_mode = p_mode;
         _update_fog();
         notify_property_list_changed();
     }
     ```
     ⭐ **读法**：只有「当前是 DEPTH、正要改成 EXPONENTIAL」才落到 `0.01`；**其余所有情况一律落到 `1.0`**。而 `fog_mode` 的类默认**就是** `FOG_MODE_EXPONENTIAL`（枚举 0，枚举提示 `"Exponential,Depth"`）。
     → **"为了写得明确，显式设一次默认的 EXPONENTIAL"这个最像安全写法的动作，恰好走 else 分支，把 `fog_density` 打回 `1.0`** —— 比设成 DEPTH 还糟：`1 − exp(−1.0 × 48.0) ≈ 100%`，画面直接糊成 `fog_light_color`。
   - ⚠️ **同理适用于 `.tres` / `.tscn`**：资源加载走 `set()` → `set_fog_mode()`。**即使写的值是 `fog_mode = 0`（= EXPONENTIAL），只要它被序列化进文件，加载时同样把 density 打回 1.0**。→ 见 §13.3（A-7 判据）。
2. 🔴 **`fog_height_density` 必须恒为 0.0。** 它不是 DEPTH 专属风险 —— `max()` 发生在 `#ifdef USE_DEPTH_FOG` 分支**之后**，对 EXPONENTIAL 一样生效。见 §7.1 复核。 → **R-ENG-12（保留，等级不变）**
3. 🟡 `fog_sun_scatter > 0.001` 会改 `fog_color`（改**颜色**不是浓度）。**日落态是唯一可能想开它的态**（正好是圣托里尼/塞舌尔的招牌态）；若要开，先锁 `tonemap_exposure = 1.0` 再重新核一次夜雾下限。
4. 🟡 `fog_aerial_perspective` 在 Compatibility 下整块被注释掉 —— **不是调参旋钮，调了没反应**。
5. 🆕 **`fog_density` 必须在每次地点切换时被覆盖。** 只改颜色不改密度 → 上一地点的密度静默残留，且表现为"这个地点看起来不对"这种无法归因的观感问题。 → **R-ENG-15（新增）**

#### 1.0.7 🟢 降级白赚的四个收益（写下来，免得将来有人翻案时以为降级只有代价）

1. **R-ENG-09 休眠**：`fog_mode` 全程不变 → 永不触发 `USE_DEPTH_FOG` 变体编译；**V3 关闭**。
2. **pitch 联动问题自动消失**。EXPONENTIAL 下 25 格处遮蔽率随 pitch 只摆动 **≈3.1 个百分点**（0.38 → 22.2%、0.72 → 21.4%、1.25 → 19.1%，ρ=0.0035），肉眼不可见；DEPTH 下是 **17 个百分点**（23.0% → 5.7%）。
   → ⭐ **A-3 不是"作废了懒得测"，是它防的那个问题不存在了。** 这个区别要写清。
3. **横向渐晕从 3.5× 降到 ≈1.1×**。EXPONENTIAL 下 16 格中线 19.2% vs 侧边（ℓ=30）21.2%，Δ ≈ 2.0pp（DEPTH 下是 6.2% vs 21.7%）。
   → **§1.3.2 风险一从"必须写进验收单"降为"可接受，不必处理"**（径向雾的性质没变，只是不再被 smoothstep 放大）。
4. **`CAM_ORBIT_RADIUS` / `CAM_ZOOM_MAX` 常量拆分从"必须"降为"建议"**（R-ENG-13 降级：最坏后果从"雾值全错且不可归因"变成"相机构图变化且立即可见"）。

#### 1.0.8 实现条目（可直接开工 · 约 0.2 人日）

```gdscript
# LocationProfile：只存 2 个标量，四态由代码派生
@export var fog_density_day:   float = 0.0035   # 昼档（晨 / 昼 / 日落 三态共用）
@export var fog_density_night: float = 0.0035   # 夜档

func fog_density_for(state_idx: int) -> float:
    return fog_density_night if state_idx == 3 else fog_density_day
```

> ⭐ **为什么存 2 个标量而不是 4 态数组**：四态数组必然会长成"晨 0.0035 / 昼 0.0036 / 日落 0.0034"——**没人会故意这么填**，但它会在三次手工填值时自然产生，而且**不报错、不可归因**，事后只能靠逐格比对发现。存 2 个标量从结构上消灭它。

```gdscript
# _apply_daylight(state_idx: int) 内（唯一写入点）
environment.fog_density = profile.fog_density_for(state_idx)

# 三条断言（O(1)、零成本、进控制清单）
assert(is_equal_approx(environment.fog_density, want))
assert(is_equal_approx(environment.fog_height_density, 0.0))
assert(environment.fog_mode == Environment.FOG_MODE_EXPONENTIAL)   # 读，不写
```

> 📌 **边界不变**：8 个数值的**调优**属各地点的美术成本，工程侧只负责"能被驱动"这个能力（§9.3 判别动词）。**"四态雾能被参数系统驱动"仍是 core #12 的内容，只是实现方式从 DEPTH 换成单行赋值。**

#### 1.0.9 ⭐ 接入当天要做的最小验证集（**总耗时 ≤ 30 min**）

| # | 项 | 成本 | 判据 | 状态 |
|---|---|---|---|---|
| **V2** | 🔴 **`fog_disabled` → `FOG_DISABLED` 实机验证** | **≤5 min** | 泉州微光箭头 / Cape Cod 覆盖热力图 / 光斑贴片：转 yaw 一圈，三者颜色**不随位置变化**；对照组（未加 `fog_disabled` 的同材质物）颜色应随距离变化 | ⭐ **仍是唯一必须实机验证的项** |
| 2 | 夜雾下限 | ≤5 min | 四地夜态按 N，取 25 格外片元色，确认 ≥ 下限、且显著亮于夜背景（用现成的 `tests/test_fog_floor.gd`） | 保留（§1.0.4 #1） |
| 3 | 8 个 density 写入 + 四地 × 昼/夜 截图 | ≈15 min | 对照 §1.0.5 表：焦点不应超过 ~25%（ρ>0.006 就明显发灰）；夜档与昼档差值建议 ≤2× | 保留清单 #1 的配套 |
| 4 | 三条断言（代码级） | 1 min | `fog_density == want` / `fog_height_density == 0` / `fog_mode` 未被写 | §1.0.8 |
| 5 | 🆕 地点切换密度不残留 | 2 min | A→B→A 来回切，density 回到 A 的值（防 R-ENG-15） | 新增 |
| 6 | （可选）`fog_sun_scatter` / `fog_aerial_perspective` 置零确认 | 2 min | 只在开锁 sun scatter 时才需要 | 条件触发 |

**已关闭的三项**（勿再排期）：

| 项 | 结论 | 理由 |
|---|---|---|
| **V1**（径向 vs 轴向） | ✅ **关闭**（源码判定：径向） | 结论保留为事实；渐晕已量化，EXPONENTIAL 下 ≈1.1×，无需处理 |
| **V3**（`USE_DEPTH_FOG` 注入点） | ✅ **关闭** | DEPTH 作废 → 该 define 永不定义，**无需再定位**。⚠️ **复活条件**：将来任何人重新启用 `FOG_MODE_DEPTH`，必须回到这一条（并同时复活 R-ENG-09） |
| **A-3**（pitch 联动测试） | ✅ **作废** | 无 `begin/end`；且该问题在 EXPONENTIAL 下不存在（§1.0.7 收益二） |

> ⭐ **为什么 V2 必须留着**（它押的不是观感）：径向雾下，**同一块地在屏幕中线与侧边会读出不同的雾量** —— Cape Cod 覆盖热力图因此会"同一块地随 yaw 给出两种结论"。EXPONENTIAL 下这个差异从 DEPTH 的 ~15pp 降到 ~2pp，**但性质没变**：热力图是**数据读数**，任何非零的位置相关性都是数据可视化 bug，不是"看着还行"。

#### 1.0.10 ⭐ 8 个数值已交付（2026-09-24 美术定稿）· 工程侧核对

> 🔴 **唯一数据源：`water-lighting-params.md` §5.1.1.1 / §7。** 本文档**刻意不复制这 8 个数**，只记录工程侧的核对结论与派生量 —— **防止两份文档各存一份然后漂开**（与 R-ENG-15 同源的双源风险）。要数值，去美术文档取。

**（a）核对结论：八个值全部落在实用区间内 ✅**

派生遮蔽率（由 `O = 1 − exp(−ρ·d)` 算出，焦点 / 25 格 / 35 格 三档）：

| 地点 · 档 | 焦点 48.0 | 25 格 68.80 | 35 格 77.81 |
|---|---|---|---|
| 泉州 昼 / 夜 | 17.5% / 21.3% | 24.1% / 29.1% | 26.7% / 32.2% |
| Cape Cod 昼 / 夜 | 15.9% / **24.3%** | 21.9% / 32.9% | 24.4% / **36.3%** |
| 圣托里尼 昼 / 夜 | 6.9% / 11.7% | 9.8% / 16.4% | 11.0% / 18.3% |
| 塞舌尔 昼 / 夜 | **4.7%** / 8.3% | 6.6% / 11.6% | 7.5% / 13.1% |

1. ✅ **八个值全部 ≤ 0.006**（§1.0.5 限制二的实用区间上沿），无一越界。
2. ⚠️ **八个值里最高的是 Cape Cod 夜档**（焦点 24.3%、35 格 36.3%），**不是泉州夜档** —— 它才是真正的上边界。要做"夜间会不会糊"的 A/B，**先看 Cape Cod，泉州排第二**。
3. 🟢 **四地纵向关系没有被压扁**：昼档焦点 塞舌尔 4.7% → 圣托里尼 6.9% → Cape Cod 15.9% → 泉州 17.5%。当初 §1.4 代价二担心"四地差异被压得比原来还扁"，**实际没有发生** —— 因为判据撤销后不再需要把 ρ 挤进 `0.0005–0.0011` 那条窄缝里。

**（b）两条实现侧结论**

1. 🔴 **V2 现在是唯一解法，没有退路**（美术发现，工程侧背书）。DEPTH 时代"把引导箭头限制在近场、近场 `O ≡ 0` 所以不用 `fog_disabled` 也行"这条退路**已失效** —— EXPONENTIAL 下泉州昼**焦点就有 17.5%**。
   - ⚠️ **数字口径请统一**：覆盖热力图的读数摆幅，按**全屏可达区间 32.2–77.81** 算 = **12.1%–26.7% ≈ 14.7pp**；美术按"中线 33.5 → 25 格 68.8"算的 11.5pp 是同一现象的一个子区间。**结论一致，但文档里统一写 ≈15pp**，否则两份文档各写一个数，又是双源。
2. 🆕 **`fog_transition_sec` 字段建议删除**（或明确 `0.0` = 跟随全局 Tween）。它是给雾开的**第二个时间源**：若实现成"0 秒 = 瞬跳"，而天色/水色在 core #6 的 Tween 里渐变，会出现**雾瞬跳、光色渐变**的撕裂。正解是雾跟随 `_apply_daylight(phase)` 由**同一个 Tween** 驱动，不单独插值。

**（c）泉州 vs Cape Cod 昼档只差 1.1–2.3pp —— 工程侧的判断**

| 距离 | 泉州 0.0040 | Cape Cod 0.0036 | 差 |
|---|---|---|---|
| 焦点 | 17.47% | 15.87% | **1.6pp** |
| 25 格 | 24.06% | 21.94% | **2.1pp** |
| 35 格 | 26.75% | 24.43% | 2.3pp |

- **实机能不能读出？大概率读不出。** 大面积均匀场的亮度差觉察阈约 1–2%（Weber），2pp 正好卡在临界：**A/B 瞬切能察觉、静态并排看读不出**，更不可能读出"性格"。
- ⭐ **但"性格"本来就不该由 density 承担**：`mix(base, fog_color, O)` 里 `O` 只管**明度**，`fog_color` 管的是**色相与冷暖**。泉州 `#DCDAD0`（暖灰）vs Cape Cod `#B4C0C8`（冷灰蓝）的色相差，可读性远大于 2% 明度差 —— **美术"靠雾色与天色拉开"的处理方向是对的，而且比拉 density 有效得多。**
- 🟢 **还有一个零成本、且更强的旋钮：雾色与天色地平线的接近程度。** 两者接近 → 远处融进天空（通透、看不到雾带）；两者拉开 → 远处出现一条可辨的雾带（沉、大气厚重）。**它对"性格"的贡献远大于 density，且不花任何工程量。** 建议美术把它作为性格指标写进文档。
- 🔴 **不为"泉州 / Cape Cod 的性格差异"投入任何额外工程。** 若实机仍觉得太像，按此顺序处理：**① 拉雾色 → ② 调雾色与天色的关系 → ③ 接受"这两个地点的雾就是相近的"**。不要为拉开性格去拉 density（会把泉州推向糊、Cape Cod 推向无），**更不应当因此翻案回 DEPTH**（那需要用户重新拍板）。

**（d）泉州夜档 0.0050 要不要 A/B —— 要，但 15 分钟，且先看 Cape Cod**

量化（夜雾色亮度 0.44 vs 夜背景 0.16 ⇒ 雾是"抬暗部 + 压亮部"的**双向**压缩）：

| 夜档 ρ | 焦点 O | 灯 : 墙 对比 |
|---|---|---|
| 0.0035 | 15.5% | 8.3 : 1 |
| **0.0050（泉州）** | 21.3% | **6.6 : 1** |
| 0.0058（Cape Cod） | 24.3% | 6.0 : 1 |
| 0.0060 | 25.0% | 5.8 : 1 |
| 0.0080 | 31.9% | 4.7 : 1 |

- 🟢 **预判 0.0050 能过**（6.6:1 仍在可读范围）。**而且实际观感比这个数更好** —— 光斑贴片已是 `render_mode fog_disabled`（§1.0.4 #2），**灯笼的辉光不会被雾洗掉**，被压的只是灯体与厝墙的明暗。
  - ⚠️ 这同时是 **V2 更关键的又一个理由**：若 `fog_disabled` 没生效，辉光也被吃掉，夜间画面会明显塌。
- 📌 **判据：灯与墙对比 ≥ 5:1；不满足就降到 0.0040，不要去改别的东西。**
- 📌 **执行方式**：并入 §13.1 的运行时调参滑块（**已批准**）顺手做，**不单独排 A/B 场次**。

**（e）人日：不变。** 8 个值交付不改变 §11 的任何数字。

---

（以下 §1.1 起为 v1.1 沿革。模型判定的**事实**仍然成立，并继续作为 §1.0 的地基；其中与 DEPTH 相关的方案与数值已按 §1.0.3 作废。）

### 1.1 结论（沿革 · **事实仍然成立**）

> **Godot 4.4 的 `Environment` 默认雾模式是线性指数（Beer–Lambert）模型：`O(d) = 1 − exp(−ρ·d)`。**
> **不是 exp²。** —— 而 v1.2 的裁定是：**就停在默认这个模型上，不再迁移**（§1.0.1）。因此"与美术推导不符"这件事不再是偏差，而是被接受的现状。

先更正一处命名：team-lead 转述的"`FOG_MODE_EXP2` 还是 `FOG_MODE_LINEAR`"两个名字在 **4.4 里已经不存在**。4.4 改过名并加了新模式：

**证据链（三份源码，逐字引用）：**

| 环节 | 文件 | 原文 | 含义 |
|---|---|---|---|
| ① 枚举与默认值 | `scene/resources/environment.h`（分支 4.4） | ```cpp enum FogMode { FOG_MODE_EXPONENTIAL, FOG_MODE_DEPTH, }; ``` … ```cpp FogMode fog_mode = FOG_MODE_EXPONENTIAL; float fog_density = 0.01; ``` | **默认值 = `FOG_MODE_EXPONENTIAL`**（枚举下标 0） |
| ② 属性提示顺序 | `scene/resources/environment.cpp` | `ADD_PROPERTY(PropertyInfo(Variant::INT, "fog_mode", PROPERTY_HINT_ENUM, "Exponential,Depth"), "set_fog_mode", "get_fog_mode");` | 与 ① 一致：**Exponential 在前 = 默认** |
| ③ **Compatibility 的真实公式** | `drivers/gles3/shaders/scene.glsl`（⭑ 本项目跑的就是这个渲染器） | ```glsl #ifdef USE_DEPTH_FOG float fog_z = smoothstep(scene_data.fog_depth_begin, scene_data.fog_depth_end, length(vertex)); fog_amount = pow(fog_z, scene_data.fog_depth_curve) * scene_data.fog_density; #else fog_amount = 1.0 - exp(min(0.0, -length(vertex) * scene_data.fog_density)); #endif ``` | 默认分支 = **`1 − exp(−ρ·d)`** |

**为什么"没有显式 `fog_mode`"就等于默认：**
`build_world.gd::_build_environment()` 的还原结果里**从头到尾没有出现 `fog_mode`**（只有 `fog_enabled` / `fog_light_color` / `fog_density` 三个赋值，见 v1.0 §1.2 参数快照）。`Environment.new()` 走的是 `environment.h` 的成员初始化器 → `fog_mode = FOG_MODE_EXPONENTIAL` → `_update_fog()` 把它打到渲染服务器 → GLES3 侧 `scene_state.ubo.fog_mode = 0` → `USE_DEPTH_FOG` 未定义 → 落到 `#else` 分支。
**这条链是闭合的，不需要实测就已经定案。**

补充两个"货不对板"的点，请美术知悉：

1. `length(vertex)` 是**片元到相机的欧氏距离**（视空间坐标模长），不是"深度 z"。等距斜视角下这两个值差很多——做标定时必须用真距离，见 §1.5。
2. 本项目 `fog_density = 0.0035` 在真实模型下 O(25) = **8.4%**（v1.0 §1.2 我写"极淡"是对的）；若按美术假想的 exp² 只有 **0.76%**（等于没有）。**这也是"实际需求 vs 模型"的一处旁证**——真实观感偏向淡但可见。

> ### ⚠️ 实现注意事项（由 team-lead 指定写入，必看）
> **`length(vertex)` 是相机到片元的欧氏距离，不是地板格数。任何以"格"为单位的雾标定都必须先做坐标系换算，否则标定结果与实际观感不符。**
>
> 理由是它会让人栽得毫无警觉：美术 §5.1.2 那套"放 8 格黑柱取色"的标定法**看起来极其合理**——标记柱确实摆在离 8 格远的地方，谁也不会想到引擎算的是另一回事。但等距视角下相机是斜的，`length(vertex)` 比地板格距大出一截，**下一个标定雾的人一定会用同样的方式再栽一次**。
> 落地要求：标定时必须让**相机到柱心的直线距离**等于目标值（正上方俯视，或用 `camera.global_position.distance_to(pillar_center)` 实测确认），而不是让地面上量出来的格数等于目标值。

### 1.2 🔴 已作废 · 四个泉州雾值在真实模型下的实际表现（沿革：判据与模型的结构性冲突）

> **本节整体作废（v1.2）。** 保留原因有二：① 下面的"可行域为空"证明是 §1.0.2 第 3 点的**证据**（正是这组判据逼出了 DEPTH）；② §1.2 末尾那条方法论教训仍然有效。
> **具体数字不要引用**——它们既踩了单位坑（见下方原注），也因判据作废而失去意义。

> ⚠️ **读本节前先看 §1.3.0。** 本节用来证明「线性指数模型下判据无解」的 O(8) / O(16) / O(25) 三列，**同样踩了单位坑**——它们算的是「相机距离 8 / 16 / 25」处的遮蔽率，而游戏里取不到这些距离（真实可达区间约 32 – 79）。
> **但结论不但成立，而且更强**：把距离换成真实值后冲突只会更剧烈（见 §1.4 的换算后复核）。本节保留原文，用来记录「判据与模型的结构性冲突」这个推理；**具体数字不要引用**。

按 `O(d) = 1 − exp(−ρ·d)` 重算（ρ 沿用美术原值）：

| N 键态 | ρ | O(8 格) | O(16 格) | **O(25 格)** | 美术原判据 | 判定 |
|---|---|---|---|---|---|---|
| **① 晨** | 0.040 | **27.4%**（原估 9.7%） | 47.3% | 63.2% | 8 格 ≤12% | 🔴 **破表 2.3 倍** |
| **② 昼** | 0.014 | **10.6%**（原估 1.2%） | 20.1% | **29.5%**（原估 11.5%） | 8 格 ≤5% / 25 格 ≤25% | 🔴 **两条建造底线全部破表** |
| **③ 日落** | 0.025 | 18.1% | 33.0% | 46.5%（原估 32.3%） | — | 🔴 过浓 |
| **④ 夜** | 0.030 | 21.3% | 38.1% | 52.8%（原估 43.0%） | — | 🔴 过浓 |

**更要命的是：这不是"调小即可"，是数学无解。**

> **晨态判据冲突证明**（可直接给美术看）：
> - 25 格 ≥ 60% ⟹ `1 − exp(−25ρ) ≥ 0.60` ⟹ `ρ ≥ 0.03665`
> - 8 格 ≤ 12% ⟹ `1 − exp(−8ρ) ≤ 0.12` ⟹ `ρ ≤ 0.01598`
> **`0.03665 > 0.01598`，可行域为空。** 在 Beer–Lambert 模型下，不存在任何 ρ 能同时满足这两条。
> ⭑ 有意思的是：美术当初正是用这个"线性指数无解"的论证反推出"必须是 exp²"（`water-lighting-params.md` §5.1.1）——**论证本身完全正确，只是它的结论被用反了方向**：它证明的是"exp² 才配得上这套判据"，而不是"引擎会是 exp²"。

> ### 📌 留给后人的一条方法论（请务必读完再写任何数值）
> **美术的推导没有任何错误。他证明了"线性指数下这套判据无解"，而引擎恰恰就是那个无解的模型——于是一次完全正确的推导把他带到了一条正确的死路上。**
>
> **前提比推导更容易出错，也更难自检。**
> 推导可以被复核、可以被第二个人验算、可以被数字证伪；而"`fog_mode` 默认是 exp²"这类**默认假设通常无人复核**——它不像公式那样写在纸上等着被检查，它藏在引擎默认值里，不查源码就看不见。
>
> ⭑ **本项目此后凡涉及引擎行为的数值设定，一律要求：先查（源码 / 官方文档 / 实测，三选一），后算。禁止由"设计需要什么"反推"引擎应该是什么"。**
> 本次付出的代价是泉州四态全部作废 + 一次 cross-reference 返工；若下次这套误设前提的方法用在 shadow atlas / tonemap / 色彩空间上，代价会更大。

### 1.3 🔴 已作废 · 原解法建议：改用 `FOG_MODE_DEPTH`（沿革保留 · **请勿实施**）

> **本节及 §1.3.0–§1.3.3 全部作废（v1.2，用户拍板降级）。** 见 §1.0.3 作废清单 #1–#4。
> **方案本身没有错**——它提供"近处严格为 0 + 远处封顶"的形状，EXPONENTIAL 做不到（§1.0.5 限制一）。作废是因为**驱动它的判据被撤销了**，见 §1.0.2。
> ⚠️ **复活条件**：若将来重新启用 DEPTH，必须同时复活 V3（`USE_DEPTH_FOG` 注入点）与 R-ENG-09（变体编译阻塞），并回看 §1.3.0 的单位坑。

与其把判据砍掉，不如换一个**形状可控**的雾模型。Godot 4.4 的 DEPTH 模式恰好就是为此存在的：

```glsl
O(d) = pow(smoothstep(begin, end, d), curve) × density
```

它的形状是：**`begin` 以内严格为 0 → smoothstep 平滑起雾 → `end` 处达到 `density`（=最大遮蔽率上限）**。这正是"近处可建造、远处看不见"的语义，**在默认指数模型里做不到**。

### 1.3.0 🔴 作废声明：本节初版换算表已作废（美术纠正 + 我复核确认，**请勿使用**）

初版给的 `begin = 8 / 12 / 10 / 10`、`end = 25 / 30 / 30 / 28` 是**错的**——错因不是算错，是**单位错**：我把「地板上的格数」直接当成了 `length(vertex)` 的世界单位数。

`length(vertex)` 是**相机到片元的欧氏距离**（§1.3.3 有源码逐字引用）。本项目相机是**正交投影、绕 focus 点轨道运行、半径 48.0 世界单位**，所以**每一片元的距离里都压着约 48 的底噪**，屏幕上根本取不到 8 / 16 / 25 这种距离。

🔴 **按初版直接填表的后果**：可见范围内每片元距离都 > `end = 25` ⇒ `smoothstep` 恒为 1 ⇒ **整张图是一片等于 `density` 的纯雾**（泉州昼 0.25 → 全屏均匀 25% 白雾；泉州晨 0.65 → 全屏 65%）。不是「偏浓」，是直接糊死。

> **原表（已作废，勿用，留档以防有人从旧版本抄）**：晨 8/25 · 昼 12/30 · 日落 10/30 · 夜 10/28；三地昼态 塞舌尔 20/45 · 圣托里尼 18/40 · Cape Cod 14/32。

**相机常量（美术从 `_probe/main.gdc.dec` 读出，我独立复核）**

| 常量 | 值 | 我的复核结果 |
|---|---|---|
| 投影方式 | `PROJECTION_ORTHOGONAL`（正交） | 采用美术读数（正交/透视都不改 `length(vertex)` 的量纲） |
| 轨道半径 `R` | **48.0** | ✅ f32，偏移 **18852**，**全文件仅 1 处** |
| 默认 `pitch` | **0.72 rad**（41.25°） | ✅ f64，偏移 18368 |
| `pitch` 可调范围 | **0.38 – 1.25 rad** | ✅ 0.38 f64 @18916；1.25 f32 @18928 |
| `camera.size`（zoom） | 默认 **32.0**，clamp **10.0 – 48.0** | ✅ 32.0 f32 @18380；⚠️ 上限 48.0 与 `R` 疑似同一常量池条目（§1.3.2 风险三） |
| `near` / `far` | **0.1 / 300.0** | ✅ 0.1 f64 @18412；300.0 f32 @18424（对雾不起约束作用） |
| focus 横向钳制 ±23 | — | ⚠️ 未能独立复核：23.0 未以浮点出现（疑为 int 或内联常量）。**不影响距离结论** |

**换算公式（我的推导与美术的推导代数等价，两条路径互相印证）**

```
D(x, ℓ) = sqrt( x² + ℓ² + 2·R·x·cos(pitch) + R² )
#   x = 沿视线方向的地板格数（远离相机为正）；ℓ = 横向偏移格数
#   D(0, 0) = R = 48.0  ← 焦点处片元距离恒等于 R，与 pitch 无关（R²cos²p + R²sin²p = R²）
```

**可达区间（默认 pitch 0.72，ℓ = 0）**：x = 8 → **54.27**；x = 10 → **55.91**；x = 16 → **60.95**；x = 25 → **68.80**；x = 28 → **71.48**；x = 35 → **77.81**。
全屏范围：我按「岛面半幅 30 格、含横向 ℓ=30」算得 **32.2 – 79.2**；美术按 ℓ=0 算得 **33.5 – 74.5**。**两者同量级，结论一致：8 / 16 / 25 全部落在可达区间之下。**

### 1.3.1 🔴 已作废 · ~~采纳美术终值（四地四态 16 组）~~

> **作废（v1.2 §1.0.3 #4）。** 四地四态 16 组数值 → 改为 **8 个值**（昼/夜 × 4 地），且由美术用眼睛调、不用判据反解。
> 复算过程本身无误（我与美术两路独立推导逐位吻合），作废的是**输入判据**。

美术已给出四地四态终值（以**格**表达语义，运行时按上式换算成引擎单位）。我**独立复算了泉州昼/晨两态的关键格，与美术表逐位吻合**：

**泉州昼（`x_begin 10 / x_end 28 / curve 1.0 / density 0.25`，pitch 0.72，ℓ = 0）**

| 量 | 我复算 | 美术表 | 判定 |
|---|---|---|---|
| `begin` 引擎值 D(10) | **55.909** | 55.91 | ✅ |
| `end` 引擎值 D(28) | **71.476** | 71.48 | ✅ |
| O(8 格) | **0.0%**（8 < begin，结构性为 0） | 0.0% | ✅ |
| O(16 格) | **6.2%** | 6.2% | ✅ |
| **O(25 格)** | **23.0%** | 23.0% | ✅ |
| O(35 格) | **25.0%**（35 > end，已满值） | 25.0% | ✅ |

**泉州晨（`x_begin 8 / x_end 30 / density 0.72`）**：O(25 格) 我复算 **61.9%**，美术 61.9% ✅。

> ⭐ **该表可作为实现值直接使用。** 初版表作废后不再存在第二套数，杜绝双源。判据核销已在美术文档 §5.1.1.5 完成（昼 8 格 0% ≤5%；昼 25 格 23.0% ≤25%；晨 25 格 61.9% ≥60%），我不重复核销。

### 1.3.2 ⚠️ 已降级 · 我复算时新发现的三条（**只有"风险一"仍部分成立**）

> **v1.2 复核：**
> - **风险一（横向渐晕）** → 🟢 **保留为事实，但降级为"不必处理"**：径向雾的性质没变，但 EXPONENTIAL 下不再被 smoothstep 放大，Δ 从 3.5× 降到 **≈1.1×**（§1.0.7 收益三）。**不要再写进验收单。**
> - **风险二（pitch 联动 / V4）** → 🔴 **作废**：无 `begin/end` 可算；且该问题在 EXPONENTIAL 下不存在（§1.0.7 收益二）。
> - **风险三（`48.0` 常量共用 = R-ENG-13）** → 🟡 **降级为低**：不再喂任何每帧换算，最坏后果从"雾值全错不可归因"变为"相机构图变化立即可见"（§7.1）。

**风险一 · 正交 + 径向雾 ⇒ 横向渐晕，而且比想象中大。**
`length(vertex)` 把**横向偏移 ℓ 也算进距离**（源码确认是径向不是轴向，见 §1.3.3）。同一「格数」在屏幕中线与屏幕侧边的雾量不同：

| 位置（泉州昼） | D | O |
|---|---|---|
| 16 格，中线 ℓ=0 | 60.95 | **6.2%** |
| 16 格，侧边 ℓ=30 | **67.93** | **21.7%** |
| 25 格，中线 ℓ=0 | 68.80 | 23.0% |
| 25 格，侧边 ℓ=30 | **75.06** | **25.0%**（已满值） |

→ 美术按中线（ℓ=0）定值是对的，**但实机画面左右两侧会明显比中线浓**（16 格处达 3.5 倍）。这不是 bug，是正交相机 + 径向雾的固有性质；**想消除只能改轴向雾，而那要改引擎 shader，本项目不做**。
→ **要求：美术验收一律「看中线」定档位；实现注释里写清「左右两侧更浓是预期行为，不要当 bug 修」。**

**风险二 · 每帧换算（V4）的收益我已量化，比「防抖动」更强。**
泉州昼 O(25 格) 随 pitch 的变化（我逐点复算）：

| pitch | 硬编码 `begin/end`（错误做法） | **每帧换算（正确做法）** |
|---|---|---|
| 0.38（压低视角） | **24.9%** | **21.8%** |
| 0.72（默认） | 23.0% | **23.0%** |
| 1.25（抬起视角） | **5.7%** ← 雾几乎消失 | **22.7%** |

→ 硬编码摆动 **19.2 个百分点**（相对幅度 4.4×）；每帧换算摆动 **1.2 个百分点**。美术说的「抬起视角雾就没了」在数字上完全成立（23.0% → 5.7%）。
→ ⭐ **V4 从「需查抖动」降级为「按构造正确」**：`begin/end` 是 `pitch` 的**纯函数**（O(1) 浮点运算、无历史状态、无累积误差），不存在任何抖动来源。真正要防的是「忘了算」，不是「算了会抖」。
→ **实现要求：`pitch` 必须取相机当前实际值（单一数据源），禁止另存一份会滞后的副本。**

**风险三 · 🔴 `48.0` 在常量池里只有一份，疑似被「轨道半径」与「zoom 上限」共用。**
我在 `_probe/main.gdc.dec` 里按 f32 字节模式扫描，`48.0` **全文件仅出现 1 次**（偏移 18852）；而美术读出的相机代码里同时存在 `clampf(zoom, 10.0, 48.0)` 与 `... * 48.0`（轨道半径）。若二者确实是同一常量池条目，则**任何「改 zoom 上限」的改动会连带改掉轨道半径 → begin/end 换算全部失真**，且失真不会报错、只会「雾突然不对了」。
→ **实现要求：源码层给这两个语义各起一个具名常量（`CAM_ORBIT_RADIUS` / `CAM_ZOOM_MAX`），并加断言 `assert(is_equal_approx(CAM_ORBIT_RADIUS, 48.0))`。** 已登记 **R-ENG-13**（R-ENG-11 已由 §7 登记表的 MultiMesh 条目占用；**已登记的号不再改号**，新风险取新号）。
→ 我无法从字节码 100% 坐实（需源码确认），但成本极低，按「有风险」处理。

### 1.3.3 关闭美术的两个待验证项（V1 / V3）—— **v1.2 均已关闭，见 §1.0.9**

> **v1.2 状态**：**V1 关闭**（源码判定径向，结论保留为事实）；**V3 关闭**（DEPTH 作废，`USE_DEPTH_FOG` 永不定义）。
> ⚠️ **下方"陷阱 1（set_fog_mode 改写 density）"在 EXPONENTIAL 下仍然成立，且更容易被触发** —— 见 §1.0.6 陷阱 1。**陷阱 3（height fog `max()`）同样在 EXPONENTIAL 下成立** —— 见 §7.1 对 R-ENG-12 的复核。**这两条是本节唯一仍然生效的内容。**

> ⚠️ **V 编号以 `water-lighting-params.md` §5.1.3 为准**：**V1 = 径向 vs 轴向**、V2 = `fog_disabled` 映射、**V3 = `USE_DEPTH_FOG` 注入点（是否触发重编译）**、V4 = 每帧更新。
> 我早期的一条消息里把 V1 / V3 说反过，本文档已按上表对齐。跨文档引用时**一律以语义标题为准，不要只写 V1 / V3**。

**V1（径向 vs 轴向）—— ✅ 已关闭，答案是径向。** `drivers/gles3/shaders/scene.glsl` 逐字：

```glsl
#ifdef USE_DEPTH_FOG
	float fog_z = smoothstep(scene_data.fog_depth_begin, scene_data.fog_depth_end, length(vertex));
	fog_amount = pow(fog_z, scene_data.fog_depth_curve) * scene_data.fog_density;
#else
	fog_amount = 1.0 - exp(min(0.0, -length(vertex) * scene_data.fog_density));
#endif // USE_DEPTH_FOG
```

→ **两个雾模式用的都是 `length(vertex)`（径向欧氏距离）**；`-vertex.z`（轴向）只出现在后面的 PSSM 阴影代码 `float depth_z = -vertex.z;`，**与雾无关**。
→ ⭐ **美术文档 §5.1.1.2 里那条「轴向（`-vertex.z`，备用）」分支可以删掉了**——它不成立，留着只会误导后人。§1.3.2 风险一的横向渐晕也由此**确认存在**（不再是待验证）。

**V3（`USE_DEPTH_FOG` 的注入点 / 是否触发重编译）—— ⚠️ 未逐字定位，但工程结论不变。** 已坐实的两点：① 它是**编译期 `#ifdef`**，不是运行时 uniform；② `fog_mode` 同时也以 `scene_state.ubo.fog_mode` 下发。无论它是「材质创建期变体」还是「绘制期 spec constant」，两条路径都指向同一约束：**首次进入 DEPTH 雾的那一帧会触发一批 shader permutation 编译，单线程 WebGL2 上是同步阻塞**。
→ 所以 §1.3 陷阱 2 / **R-ENG-09** 的既有约束（每个地点全程只用一种 `fog_mode`、在预热阶段设一次、四态只改 UBO 值）**照旧成立，而且更必须**。**不阻塞本议题，按「未定位但无害」处理。**

**🔧 两个必须写进实现注释的陷阱：**

1. ⭐ **`set_fog_mode()` 会强制改写 `fog_density`。** `environment.cpp` 原文：`if (fog_mode != p_mode && p_mode == FogMode::FOG_MODE_EXPONENTIAL) { set_fog_density(0.01); } else { set_fog_density(1.0); }` —— **必须先设 mode，后设 density**，否则你的 `0.65` 会被无声改成 `1.0`。已登记为 **R-ENG-10**。
2. ⭐ **`USE_DEPTH_FOG` 是编译期 define**（`scene.glsl` 里是 `#ifdef USE_DEPTH_FOG`），切换 `fog_mode` 极可能触发一次 scene shader variant 编译。单线程 WebGL2 上这是同步阻塞。
   → **实现约束：每个地点全程只用一种 `fog_mode`，在地点加载 / shader 预热阶段设一次；N 键切四态只改 `begin/end/density` 三个 UBO 值，绝不动 `fog_mode`。** 已登记为 **R-ENG-09**，并入既有 `MH-ENG-003`（shader 预热）清单。

3. ⭐ **高度雾会 `max()` 掉深度雾。** 同一份源码：`if (abs(scene_data.fog_height_density) >= 0.0001) { ... fog_amount = max(vfog_amount, fog_amount); }` —— 只要 `fog_height_density` 非 0（哪怕 0.0001），它就**取两者较大值**，把你的 `begin/end` 静默盖掉，且**不会有任何报错**。
   → **必须保持 `fog_height_density = 0.0`**，并在 `_apply_daylight()` 里断言。已登记 **R-ENG-12**。
4. ⭐ **Compatibility 下 `fog_aerial_perspective` 完全不生效。** 源码里那段 aerial perspective 整块被 `/* */` 注释掉（位于 `#ifdef USE_RADIANCE_MAP` 内）。任何「远景偏向天空色」的期待在 WebGL2 上都不会发生——**别把它当调参旋钮**。
5. ⭐ **`fog_sun_scatter > 0.001` 会直接改 `fog_color`**（源码：`fog_color += light_color * light_amount * scene_data.fog_sun_scatter;`）。它改的是雾的**颜色**不是**浓度**，会让 §1.5 的取色标定失真。标定时务必置 0。

### 1.4 ✅ 已被采纳（v1.2 反转）· 备选：若坚持用默认指数模型

> **v1.2 反转：本节从"我不建议的备案"变成"最终采纳口径"。** 采纳理由不是 §1.4 里那些"可用区间被压扁"的代价消失了——**那些代价全都还在**（近处必然有雾、四地差异被压扁，见 §1.0.5 限制一/二）——而是**逼我们放弃它的那组判据被撤销了**（§1.0.2）。
> ⭐ 换句话说：**代价我们认了，因为收益本来就不值这个价。**
>
> ⚠️ **本节内"可用 ρ 上限"那张表仍按错误距离反解**（见原注），**不要引用其中的数字**；调参一律用 §1.0.5 的表。

> ⚠️ **本节的 ρ 上限也是按错误距离反解的**（同 §1.3.0）。按真实距离重算一遍，**结论不变且冲突更剧烈**：
>
> | 判据 | 旧（d = 8 / 25） | **新（D = 48 屏幕中心 / 68.8 即 25 格）** |
> |---|---|---|
> | 昼态近处 ≤5% | ρ ≤ 0.00641 | **ρ ≤ 0.00107**（−ln0.95 / 48） |
> | 昼态远处 ≤25% | ρ ≤ 0.01151 | ρ ≤ 0.00418（−ln0.75 / 68.8，不起约束） |
> | 晨态远处 ≥60% | ρ ≥ 0.03665 | **ρ ≥ 0.01332**（−ln0.40 / 68.8） |
> | **冲突倍数** | 5.7× | **12.5×** |
>
> 可用区间从 `0.0030 – 0.0064` 压到 **`0.0005 – 0.0011`**，四地差异被压得比原来还扁。**→ 走 §1.3（DEPTH 模式）的决定不受影响，反而更没有悬念。**

必须接受判据降级。安全密度上限由"昼态 8 格 ≤5%"反解：`ρ ≤ 0.00641`（另一条"25 格 ≤25%"对应 `ρ ≤ 0.01151`，不起约束作用）。

| 地点 | 可用昼态 ρ 上限 | O(8) | O(25) |
|---|---|---|---|
| 塞舌尔 | **0.0030** | 2.4% | 7.2% |
| 圣托里尼 | **0.0050** | 3.9% | 11.8% |
| 泉州 | **0.0064** | 5.0% | 14.8% |
| Cape Cod | **0.0064**（已触顶） | 5.0% | 14.8% |

🔴 **代价一：泉州晨态直接消失。** 晨态要 O(25)≥60% 需 `ρ ≥ 0.03665`，此时 **O(8) = 25.4%**——玩家根本没法在晨态建造。要么砍掉"8 格 ≤12%"这条判据，要么砍掉泉州的招牌画面。
🔴 **代价二：四地差异被压扁。** 可用区间只剩 `0.0030–0.0064`，泉州与 Cape Cod **被迫取同一个值**，"最浓 → 最通透"这条四地纵向关系丢失一半。

> **结论：走 §1.3（改 DEPTH 模式）。** §1.4 只在"DEPTH 模式实测不可用时"启用的备案。

### 1.5 🟡 已降级 · 实测法：降级为「调参参考」（不做判据、不做验收）

> **v1.2 状态：整体降级为调参参考，不再是必做项。**
> - **8-bit 色阶标定法与反查表 → 作废**（§1.0.3 #6）。改为"眼睛看着调"，物理量级看 §1.0.5。
> - **A-3 pitch 联动验收 → 作废**（§1.0.3 #7 / §1.0.7 收益二）。
> - ⭐ **仍然有效、请保留的三条**：① **改动 3（锁 `tonemap_exposure = 1.0`、`tonemap_mode = LINEAR`）** —— 调雾与调曝光必须分开，否则两个旋钮互相甩锅，这条在"眼睛调"模式下**更重要**；② **改动 0 的"禁止数格子定位"**（距离要用 `camera.global_position.distance_to(pillar_center)` 实测）；③ **取色前置零** `ambient_light_energy` / `fog_sun_scatter` / `fog_height_density` / `fog_aerial_perspective`。
> - 末尾原记的"0.25 人日（四地雾值换算填入 + pitch 联动验收截图）"**含在 core #12 内，不单独计**；其 pitch 部分已作废，见 §11 人日核算。

美术的黑柱法**方法是对的**，但标定距离（8/16/25 格）**在游戏里取不到**，必须换锚点。共四处改动：

**改动 0 · 🔴 8 / 16 / 25 格在游戏里取不到。** 见 §1.3.0——相机轨道半径 48.0，可见片元距离约 **32 – 79**，8/16/25 全部落在区间之下，按它们摆柱子等于在测不存在的距离。

→ **新锚点（默认 pitch 0.72，ℓ = 0，即屏幕纵向中线）**：`x = 10 格`（= `x_begin`，应读到**纯黑**）、`x = 25 格`（主判据）、`x = 35 格`（> `x_end`，应读到**满值**）。做本节下方「density = 1.0 管线自检」时再加一根 `x = 16 格`。
→ **禁止「数格子」定位**：运行时打印 `camera.global_position.distance_to(pillar_center)`，确认等于 **55.91 / 68.80 / 77.81**（16 格为 60.95）再截图。

**改动 1 · 预测值要过一遍 linear→sRGB。** 引擎在 `mix(base, fog_color, fog_amount)` 之后依次做 `frag_color.rgb *= exposure;` →（可选 tonemap）→ `linear_to_srgb()`。把线性值直接当 8-bit 写会差一大截。

泉州昼（begin 55.91 / end 71.48 / density 0.25）、黑柱（`unshaded` 纯黑，linear 0）、`fog_light_color = #FFFFFF`、`fog_light_energy = 1.0`、`exposure = 1.0`、**tonemap 关闭**：

| 标定柱 | D | 遮蔽率 O | 线性值 | 直接写 8bit（错误口径） | **引擎实际输出 sRGB** |
|---|---|---|---|---|---|
| **10 格** | 55.91 | **0.0%**（= begin） | 0.000 | `#000000` | **`#000000`** |
| **25 格** | 68.80 | **23.0%** | 0.230 | `#3B3B3B` | **`#848484`** |
| **35 格** | 77.81 | **25.0%**（已满值） | 0.250 | `#404040` | **`#898989`** |

> ⚠️ **25 格与 35 格只差 5 个色阶（`#848484` vs `#898989`），肉眼分辨不出来。** 正式验收**必须用取色器读数值**，不能靠「看着差不多」。

> ⭐ **更有区分度的做法是管线自检：临时把 `density` 拉到 1.0**，此时三根柱子应读到 **10 格 `#000000` / 16 格 `#888888` / 35 格 `#FFFFFF`**。这三条同时成立 = 「格 → 引擎距离」的换算链路是通的。**这一步比读终值更有价值——它验的是管线，不是数值。**

> ⚠️ **必须判 10 格柱这条规则不变**（美术是对的：远端柱子因超过 `end` 会全部读成满值，无法区分模型）。
> 现在有了源码判定，**实测已从「必要」降级为「交叉验证」**——它真正验证的是「工程里有没有别的地方偷偷改了 `fog_mode` / 设了 `fog_height_density` / 挂了第二个 Environment」，以及 begin/end 换算是否真的接上了 pitch。

**改动 2 · 距离的标定方式（按径向雾重写）。** `length(vertex)` 是**相机到片元的欧氏距离，含横向偏移 ℓ**（§1.3.3 源码确认）。所以柱子必须放在 **ℓ = 0 的屏幕纵向中线上**，否则读到的距离比表格大、雾比预期浓（§1.3.2 风险一：16 格中线 6.2% vs 侧边 21.7%）。
→ 柱子用 **`unshaded` 纯黑**（`StandardMaterial3D` + `shading_mode = UNSHADED`；「unshaded 依然吃雾」已在 §2 证实）。
→ 取色前必须置零：`ambient_light_energy = 0`、`fog_sun_scatter = 0`（改雾色，见 §1.3 陷阱 5）、**`fog_height_density = 0`**（会 `max()` 掉深度雾，见 §1.3 陷阱 3）、`fog_aerial_perspective = 0`（Compatibility 下本就无效，置零只为排除干扰）。

**改动 3 · 🔴 必须锁 `tonemap_exposure = 1.0`（美术提的第三条标定偏置，我采纳并给出源码依据）。**
源码顺序是 `mix()` → `*= exposure` → tonemap → `linear_to_srgb()`。**`exposure` 是在雾之后相乘的**，所以 exposure 一变，雾的观感与取色全变，而 `fog_amount` 一个数没变——这会让「到底是雾调错了还是曝光调错了」彻底无法归因，四态调参会在两三个旋钮之间来回甩锅。
→ **标定与验收全程锁 `tonemap_exposure = 1.0`、`tonemap_mode = LINEAR`（或关闭）**，把 exposure 从变量里彻底拿掉。等四态定完，再单独调 exposure，且**调完不用回头改雾值**（因为两者正交）。

**⭐ 新增验收项 · pitch 联动必须单独测一次（这是「每帧换算有没有真接上」的唯一判据）。**
把 pitch 拉到 **1.25 rad** 再截一张 25 格柱：
- 每帧换算正确 → O ≈ **22.7%**；
- 硬编码（错误） → O ≈ **5.7%**，雾几乎消失。

差值 17 个百分点，**肉眼一眼可见**，比读终值可靠得多。已并入 §1.3.2 风险二；**这一条必须进验收单，不能只测默认 pitch**。

**工作量：0（静态判定已完成）+ 0.25 人日（四地雾值换算填入 + pitch 联动验收截图）。** 不变。

---

## 2. ② `unshaded` / `blend_mix` 是否绕过 fog 注入

### 2.1 结论：🔴 **都不绕过，而且绕不过去**

`drivers/gles3/shaders/scene.glsl`（Compatibility 唯一走的 scene 着色器）的 BASE_PASS 原文：

```glsl
#ifdef MODE_UNSHADED
	frag_color = vec4(albedo, alpha);
#else
	...
	frag_color = vec4(diffuse_light + specular_light, alpha);
	frag_color.rgb += emission + ambient_light;
#endif //!MODE_UNSHADED          ← unshaded 的分支在这里就结束了

#ifndef FOG_DISABLED
	fog.xy = unpackHalf2x16(fog_rg);
	fog.zw = unpackHalf2x16(fog_ba);
	frag_color.rgb = mix(frag_color.rgb, fog.rgb, fog.a);   ← 两类材质都走到这里
#endif // !FOG_DISABLED
```

**读法**：`#endif //!MODE_UNSHADED` 与 `#ifndef FOG_DISABLED` 是**两个独立的代码块**。unshaded 材质只是"跳过了光照"，**雾的 `mix()` 在它后面照常执行**。

由此三条定性全部关闭：

| 美术提的备选 | 判定 | 依据 |
|---|---|---|
| 自定义 ShaderMaterial + `render_mode unshaded` | 🔴 **不生效**（这是当前 `quanzhou-seychelles-art.md` §5.0.1 正在用的方案） | 上面的代码块分析 |
| `StandardMaterial3D` + `SHADE_MODE_UNSHADED` | 🔴 **不生效**，同上 | 同一个 `MODE_UNSHADED` 分支 |
| `blend_add` / `blend_mix` 混合模式 | 🔴 **与雾无关**——雾的 `mix()` 发生在 **片元着色器内、混合之前**；混合是随后的固定管线状态，改它不影响"雾已经把颜色拉向 fog color"这个事实 | 同上（同一段代码块） |

> 一句话：**雾是在着色器里改 `rgb`，混合模式只决定这个 `rgb` 怎么和帧缓冲相加。两者正交，不存在"换个混合模式就躲开雾"这条路。**
> 顺带确认：泉州晨态下引导箭头会被雾吃掉这件事**是真的**，且当前 `quanzhou-seychelles-art.md` §5.0.1 的材质救不了它。

### 2.2 ⭐ 正解：`render_mode fog_disabled`（Godot 4.4 自带，一个 token，零成本）

Godot 4.4 空间着色器文档原文（多语言版 4.4 文档一致）：

> **`fog_disabled` — Disable receiving depth-based or volumetric fog. Useful for `blend_add` materials like particles.**

对应到 §2.1 那份 shader 里的 `FOG_DISABLED` define：一旦定义，`vec4 fog` 不声明、`fog_process()` 不调用、**`mix()` 不执行**——**整条雾路径被编译期剔除**（顺带省一点点 ALU）。

**不需要 CanvasLayer，不需要 SubViewport，不需要换配方。** 给美术的两处具体改动：

```glsl
// res:// 泉州引导箭头材质（基于 §5.0.1 现有写法，仅加一个 token）
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;  // ⭐ 末尾加 fog_disabled
```

③ 的暖光斑材质同理：`render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled`。
（Cape Cod 地面大光斑、④ 的灯塔光锥也一律加上。）

### 2.3 CanvasLayer 2D 叠加退路：**不需要**（仍给出完整评估，以备将来翻案）

| 项 | 评估 |
|---|---|
| 实现成本 | **0.75–1 人日**：在 HUD 的 CanvasLayer 下加一个自定义 `_draw()` 的 Control；每帧对每个箭头调 `camera.unproject_position(world_pos)`；自己画多边形 + 描边；处理相机旋转/缩放时的失效与重绘 |
| 对现有 HUD 的影响 | ① 需要把 `Camera3D` 引用透传给 HUD 层，违反"UI 不持有游戏状态"的控制清单原则；② 与现有 HUD / minimap 的 `z_index` 与 `mouse_filter` 有真实冲突面（minimap 区域需要屏蔽）；③ 正交相机下 `unproject_position` 在近平面附近有退化，需额外兜底 |
| 对相机的影响 | 每帧 CPU 计算 N 个箭头的投影（单线程），N 大时有可见 CPU 成本；相机连续平移/旋转时需要逐帧重算，等于把 GPU 的活搬回主线程 |
| 🔴 **致命缺点** | **2D 叠加层没有深度，箭头会穿透并浮在建筑物之上。** 现有 3D 方案由深度天然处理遮挡；走 2D 会出现"箭头贴在一堵墙正面上"的穿帮。对一个引导系统来说这是功能性退化，不是风格差异。 |
| **结论** | 🟢 **不采用。`fog_disabled` 一行解决，省 0.75–1 人日，且不引入上述四个新问题。** |

> 📌 唯一还需要 2D 层的场景：未来若要求"箭头必须永远画在最上层、不允许被任何物体遮挡"——那时再回来评估。目前设计没有这条要求。

---

## 3. ③ 暖光灯改造：按 `blend_mix` 重新评估

### 3.0 先确认美术推翻自己方案这件事：**他对了，而且理由比他给的更强**

美术的判据"光斑是被照亮的地面，不是发光体；被照亮的表面应趋近光色，不该累加光色"——我可以从数学上确认并加强它：

> **同色 alpha 混合与绘制顺序无关（可证）**：两层同色 `C`、alpha 分别为 `a₁ a₂`，混合到背景 `D`：
> `C·a₁ + (1−a₁)(C·a₂ + (1−a₂)D) = C·a₂ + (1−a₂)(C·a₁ + (1−a₁)D) = C·(a₁ + a₂ − a₁a₂) + (1−a₁)(1−a₂)·D`
> 展开两边完全相等。**所以：① 无需按距离排序；② 覆盖率只会单调趋近 1，永远不会超过 `#FFBD70`。** 这正是"自收敛"的数学证明。
> 而 `blend_add` 的结果 = `C·(a₁ + a₂ + … + a₇)`，**七盏密集灯笼 = ×7 → clip 成纯白**。美术说的"在最需要它的画面里翻车"，准确。

### 3.1 `blend_mix` vs `blend_add` 在 Web 端的开销差异

> 🟢 **结论：完全相同。选 `blend_mix` 是纯画质理由，不需要付任何性能代价。**

| 维度 | `blend_add` | `blend_mix` | 差异 |
|---|---|---|---|
| GPU 混合操作 | 固定管线 blend，**1 次 framebuffer 读 + 1 次写** | 同为固定管线 blend，**1 次读 + 1 次写** | **0** |
| Shader 变体 | 无差别（混合不是 shader permutation） | 同 | **0** |
| 是否需要排序（本项目 `depth_draw_never` + 不写深度） | 不需要 | **不需要**（§3.0 已证顺序无关） | **0** |
| ALU | 无差别 | 需多算一个 `ALPHA` 值（本来的衰减函数就要算） | ≈0（多一两条指令） |
| Overdraw | 同为一个 quad 覆盖同样像素 | 同 | **0** |
| 理论唯一差别 | — | 需要 `ALPHA` 有意义；写 alpha 多一个 32-bit 分量 | 可忽略 |

**反向提醒**：`blend_add` 在 `TONE_MAPPER_LINEAR` + sRGB 输出下更容易 clip；`blend_mix` 天然不会。所以 **`blend_mix` 不仅不贵，反而更兼容现有的 tonemap 配置**。

### 3.2 fillrate：直接采用美术的数值（不再自行推算）

| 同屏灯数 | 光斑覆盖像素 | 折合全屏 overdraw | 判定 |
|---|---|---|---|
| 40 盏 | ≈ 25.5 万 | **0.28×** | ✅ 可忽略 |
| 120 盏 | ≈ 76 万 | **0.84×** | ✅ 可接受（泉州预计量级） |
| 400 盏 | ≈ 256 万 | **2.7×** | ⚠️ 才需要降级 |

⭑ **我补一条让这组数字更稳的话**：overdraw 是**比值**，因此与分辨率、devicePixelRatio、是否 Retina **完全无关**——屏幕像素涨 4 倍，全屏和被光斑覆盖的像素同时涨 4 倍，比值不变。所以这组估算不需要按设备重做，可以当常量用。✅ 安全。

### 3.3 draw call：美术判断正确，这是唯一可能的真瓶颈

| 方案 | draw call | 备注 |
|---|---|---|
| 一盏一个 `MeshInstance3D`（现状思路） | **= 灯数**（40–120） | 🔴 每个节点还要走 transform 更新 + 视锥剔除 + 渲染列表构建，**单线程 WebGL2 上主线程成本 >> GPU 成本**。绝不可取 |
| **MultiMeshInstance3D**（⭐ 我的建议，取代美术的 L0） | **1** | 且**零网格重建** |
| 合并进单个 ArrayMesh（美术的 L0） | 1 | 但每次增删灯要**重建顶点数组** |

### 3.4 ⭐ L0 的 dirty flag 惰性重建：会不会重蹈 `needs_rebuild` 覆辙？

**直接回答：如果我们照美术的 L0 原样做，它不会重蹈覆辙（量级差 20 倍以上），但它仍然是一条"为不必要付出的复杂度 + 引入了一个新的 rebuild 面"的路。正确做法是把这一步换掉——用 MultiMesh，让这条路上根本不存在 rebuild。**

#### 3.4.1 先说为什么 ArrayMesh 版不会重蹈覆辙（但也不该做）

`needs_rebuild` 灾难的两个成因，逐条对照：

| 灾难成因 | 地形（现状） | 光斑 ArrayMesh（美术 L0） | 判定 |
|---|---|---|---|
| **① 重建范围** | 全岛合并单 ArrayMesh，**12,000 方块** | 只有灯的 quad，**≤ 400 个 quad = 800 三角面** | 🟢 **量级差 ~15–30 倍**（按顶点数），单次重建约 **0.1–0.3 ms**（中端笔记本），肉眼不可见 |
| **② 触发条件** | `set_night()` 末行无条件 `needs_rebuild = true` → **每次按 N 都全量重建** | 只在"放了/拆了一盏灯"时触发 | 🟢 触发面窄得多 |

所以**不会崩**。但有两个必须守住的边界，守不住就会崩：

> 🔴 **边界 A：光斑 mesh 绝不能和地形共用同一个 ArrayMesh / 同一个 surface。**
> 一旦合并进去，"放第 9 盏灯"就重新变成"重建 12,000 方块的地形"——灾难原地复活。**必须是一个独立的 `MeshInstance3D`。**
> 🔴 **边界 B：绝不能复用 `needs_rebuild` 这个 flag。**
> 它是 `set_night()` 的旧负债（见 §3.6 MH-ENG-002a：它本来就该被删）。共用 flag 会让"按 N"和"放灯"互相引爆。必须是独立的 `_patches_dirty`。

**正确的 dirty flag 写法（若坚持 ArrayMesh）**——注意关键在"**先清标志，后重建**"：

```gdscript
# ⚠️ 仅在坚持 ArrayMesh 路线时如此；推荐走 §3.4.2 的 MultiMesh
const PATCH_CAP := 512
var _patches_dirty := false

func mark_patches_dirty() -> void:
    _patches_dirty = true          # 只置位，O(1)，不在这里做重建

func _process(_dt: float) -> void:
    if not _patches_dirty:
        return
    _patches_dirty = false         # ⭐ 先清标记再重建：否则重建途中再次置脏会多算一帧
    _rebuild_patch_mesh()          # 全量重扫灯列表，一次成型；每帧最多一次（process 频次天然保证）
```

#### 3.4.2 ⭐ 推荐：把 L0 换成 MultiMesh，**从此没有 rebuild 这个概念**

同样的 1 个 draw call，但**增删一盏灯 = 改 1 个实例的 transform + 改 1 个计数**，不重分配任何缓冲区、不重建任何顶点数组：

```gdscript
# scripts/core/light_patches.gd —— core 层，四地点共用
extends MultiMeshInstance3D
class_name HarborLightPatches

const CAPACITY := 512                  # 泉州预计 40–120；512 留足余量，内存 ≈ 24 KB

var _lamp_cells: PackedVector2iArray = []
var _lamps_dirty := false

func _ready() -> void:
    var q := QuadMesh.new()
    q.size = Vector2(1.0, 1.0)
    multimesh = MultiMesh.new()
    multimesh.mesh                = q
    multimesh.transform_format    = MultiMesh.TRANSFORM_3D
    multimesh.use_colors          = true          # 承载"次第亮起"的逐灯亮度
    multimesh.custom_data_format  = MultiMesh.CUSTOM_DATA_NONE
    multimesh.instance_count      = CAPACITY      # ⭐ 只在 _ready 设一次
    multimesh.visible_instance_count = 0
    material_override = preload("res://materials/light_pool.tres")   # fog_disabled + blend_mix
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    set_process(false)             # ⭐ 没有每帧逻辑，由 owner 在脏时调用 apply_if_dirty()

func set_lamp_cells(cells: PackedVector2iArray) -> void:
    _lamp_cells = cells
    _lamps_dirty = true            # O(1) 置位，绝不同步重建

func apply_if_dirty(world) -> void:
    if not _lamps_dirty:
        return
    _lamps_dirty = false           # ⭐ 先清标记
    var n := mini(_lamp_cells.size(), CAPACITY)
    for i in n:
        var c: Vector2i = _lamp_cells[i]
        multimesh.set_instance_transform(i, _xf_for(c, world))   # 位置 + 朝向 + 半径缩放
        multimesh.set_instance_color(i, Color(1, 1, 1, 1))       # 逐灯亮度/alpha 走这里
    multimesh.visible_instance_count = n                          # ⭐ 唯一的"开关"
```

**四条硬约束（将写入 `control-manifest.md`）：**

1. 🔴 **运行时绝不修改 `multimesh.instance_count`** —— 改它会触发 GPU 缓冲重分配，那就等于把 `needs_rebuild` 又造了一遍。**只改 `visible_instance_count`**。
2. 🔴 **绝不合并进地形 ArrayMesh**（对应 §3.4.1 边界 A）。
3. 🟢 **「灯火次第亮起」用 `set_instance_color()` 的 Tween 实现**，逐灯 alpha/亮度渐变，**零网格改动、零灯光预算、零 draw call 增量**——文策渊的设计完全保留（美术在 §5.1.2 担心的"20 次全岛重建卡顿"不会出现，因为根本没有重建）。
4. 🟢 **墙面光斑天然支持**：每个实例是一个完整的 `Transform3D`（含旋转基），朝向墙面法线只需换一个旋转即可。**这比 ArrayMesh 方案更强**——后者要支持墙面就得手工计算每个 quad 的四个顶点坐标与法向。

> **回答 team-lead 的原问题**：会不会重蹈"12,000 方块全量重建"的覆辙？
> **不会——而且不是"小心一点就不会"，是"这条路上根本没有了重建这件事"。** 我建议直接从图上删掉 L0 这一步。

#### 3.4.3 ⚠️ 给后人：不要给这套光斑加 dirty flag（动手前必读）

> **下一个人几乎一定会本能地想加一个 dirty flag** —— 因为这个项目里到处都是 `needs_rebuild` 的模式，加 flag 看起来是"谨慎"。这里明确记录为什么不要加，免得下一个人善意地把灾难引回来：
>
> **1. MultiMesh 路径上根本不存在"重建"这个动作。** 增删一盏灯 = `set_instance_transform()` + `set_instance_color()` + 改 `visible_instance_count` 三个操作，全部是写入**已有的** GPU 实例缓冲，**不重分配、不重建顶点数组、不调用 `add_surface_from_arrays()`**。没有可供 flag 去推迟的事情。
>
> **2. 加了 flag 反而更差。** dirty flag 的本质收益是"把同一帧内的 N 次变更合并成 1 次执行"。而 MultiMesh 的写入本来就是 O(1) 的即时操作——**合并没有收益，只多一个状态位和一个"忘了置脏就不同步"的失效面。**
>
> **3. 若 ArrayMesh 路径被恢复（不推荐），有两条保命边界，违规一次灾难立刻复活：**
> - 🔴 **边界 A · 不得合并进地形 ArrayMesh。** 一旦合流，"放第 9 盏灯"就重新变成"重建含 12,000 方块的地形 mesh"——这正是本轮要消灭的东西。
> - 🔴 **边界 B · 不得复用 `needs_rebuild`。** 它是 `set_night()` 的旧负债（MH-ENG-002a 会删掉它）；共用 flag 会让"按 N"和"放灯"互相引爆。必须用独立的 `_patches_dirty`。
> - 若坚持 ArrayMesh：**先清标记、后重建**（`dirty = false` 写在重建函数**之前**），否则重建途中再次置脏会多算一帧。写法见 §3.4.1。
>
> **4. 🔴 为什么 L3（退回顶点色烘焙）应该被删除。** L3 唯一的存在理由是"省 draw call"。但 MultiMesh 已经把 draw call 压到 **1**，**L3 买不到任何东西**；而它的代价是丢掉"墙面光斑"能力——按美术自己的论证，那正是泉州夜景（厝墙灯笼成排）的全部价值。**L3 是负收益条目，不是备选方案，请直接从图上删除。**
>
> **5. 运行时禁止修改 `multimesh.instance_count`。** 改它 = GPU 缓冲重分配 = 你又亲手造了一个 `needs_rebuild`。只在 `_ready()` 里设一次，之后只动 `visible_instance_count`。

#### 3.4.4 四级降级阶梯：逐条重评

| 级别 | 美术原方案 | 我的评估 | 处置 |
|---|---|---|---|
| **L0** | 全部光斑合并进单个 ArrayMesh + dirty flag 惰性重建 | draw call = 1 ✅，但引入了本可避免的重建面 | ⭑ **换成 MultiMesh**：同为 draw call = 1，**且零重建**（§3.4.2） |
| **L1** | 距离剔除 20 格 | MultiMesh 下实现为"重排可见列表 + 压 `visible_instance_count`"，**节流到相机移动 > 2 格 或 0.25 s 一次**即可，O(n log n)、n ≤ 512 → 忽略不计 | ✅ 保留为可选质量档，**默认关闭**（120 盏的 fillrate 已证明安全） |
| **L2** | 最近 32 个上限 | 同上机制，只是一行 `mini(n, 32)` | ✅ 保留为低端设备的配置旋钮（进 `godot-web-perf.md` §4 的 Low 档），**默认关闭** |
| **L3** | 退回顶点色烘焙 | 🔴 **反对。** 它会丢掉"墙面光斑"——而按美术自己的论证，那正是泉州夜景的全部价值。且 MultiMesh 已经把 draw call 压到 1，**L3 不再能买到任何东西了** | ❌ **删除 L3** |

**修订后的阶梯**：`MultiMesh 默认`（draw call = 1）→ `L1 距离剔除`（可选）→ `L2 数量上限`（仅 Low 档）。**L3 删除。**

#### 3.4.5 整套光斑系统的 draw call 结算

| 项 | draw call |
|---|---|
| 灯体（现有 props 路径，已存在） | 1（沿用现状） |
| 地面 + 墙面暖光斑（本节 MultiMesh） | **1** |
| Cape Cod 灯塔旋转光锥（§4） | **1** |
| **合计新增** | **+2** |

### 3.5 ⭐ 排期约束能否降级：能，按 MH-ENG-002a / MH-ENG-002b 分两级 — 这是可以直接交给运营的答案

先确认一件事：**team-lead 要求的"core 层建材改造"定性是对的**（详见 §6）。改造**必须分两级**，只有第一级挡在泉州前面：

| 分级 | 内容 | 是否必须排在泉州之前 | 工作量 | 理由 |
|---|---|---|---|---|
| **MH-ENG-002a · 排泉州之前（不可降级）** | 删除 `_add_prop()` L224–231 的 `OmniLight3D` 整段 + 灯体改 emission + **把 `set_night()` 末行的 `needs_rebuild = true` 一并删掉** | 🔴 **必须** | **0.5–0.75 人日** | 这是**删代码 + 改材质属性**，不是新系统。它修的是一个**今天就已经存在的正确性故障**（见 §6），不是"为了泉州才做的改造" |
| **MH-ENG-002b · 可排泉州之后（可降级）** | 光斑贴片系统（MultiMesh + `blend_mix`）、"次第亮起"、Cape Cod 灯塔光锥 | 🟢 **可以** | **1 人日** | 纯画质增量。它的**最坏失败模式是"看起来差一档"，不是"坏掉"**。泉州可以在 MH-ENG-002b 之前动工 |

> ### 📌 给运营排产的一句话
> **原约束「暖光灯改造必须排在泉州之前」降级为：「灯移除部分（MH-ENG-002a，0.5–0.75 人日）必须排在泉州之前；光斑贴片部分（MH-ENG-002b，1 人日）可与泉州并行或排在其后，不构成泉州的开工阻塞」。**
> **净效果：泉州的开工前置项从 ~2 人日降到 ~0.75 人日，且 MH-ENG-002b 的 1 人日可以从关键路径上移出来做并行。**

**顺带白赚**：MH-ENG-002a 删掉 `set_night()` 的 `needs_rebuild = true` 后，**N 键不再触发全岛 12,000 方块重建**——这是 v1.0 §3.4 里标为中低风险的"按 N 卡顿"，会被 MH-ENG-002a 顺手解决掉（且这本来就是 Tween 落地的前置条件）。⭑ 但这一删需要确认没有其他逻辑依赖该 flag，这是 MH-ENG-002a 里唯一需要小心的地方。

---

## 4. ④ 问题 D：Cape Cod 能否复用同一套光斑替代 `SpotLight3D`

### 4.1 结论：✅ **可行，且应当采用。`SpotLight3D` 完全不需要，而且本来就不能用。**

### 4.2 三条依据

**① 系统是同一套，不需要任何新东西。**
都同一个 `MultiMesh` + 同一个 `light_pool.tres` 材质（`fog_disabled` / `blend_mix` / `depth_draw_never`）。差异只有一个实例级的缩放系数：

| 用途 | 实例半径 | 备注 |
|---|---|---|
| 泉州灯笼地面光斑 | 1.5 格 | 沿用原 `omni_range = 3.0` |
| 泉州姑嫂塔地面光斑 | 2.75 格 | 沿用原 beacon `omni_range = 5.5` |
| **Cape Cod 灯塔地面覆盖** | **8–14 格** | 由美术定灯锥半径，改 `Transform3D` 缩放即可 |

即：**④ 不需要新系统 / 新 shader / 新 resource 类型**，只是多传给同一个 MultiMesh 一组更大的 transform。**增量 ≈ 0.25 人日**（含美术调灯锥配色）。

**② ⭐ 地面高低起伏的贴合：在这个项目里是个伪问题。**
`world_model` 的高度是**逐格离散的**（每格一个整数高度）。这意味着灯塔光锥**不需要任何射线投影或地形采样**——直接从 height map 生成：对每个被锥体覆盖的格子，在"该格自己的表面高度 + 0.02"处放一个 quad。零 geometry projection、零 raycast。
墙面同理：若相邻格为空，就在该侧面上放一个旋好朝向的 quad。
→ **这也是我把 §3.4.2 的 MultiMesh 作为默认方案的第三个理由：它对 per-cell placement 天然适配。**

**③ `SpotLight3D` 在本项目里本来就是禁用项，不是"可以省"。**
- Compatibility 下 positional light 的上限由 `max_lights_per_object`（默认 8）与 `max_renderable_lights` 双重限制；
- **更致命的是 §2.2 已确认的前提：地形是全岛合并的单 ArrayMesh → per-mesh 额度是全岛共享**；
- 而且：新增一个 SpotLight 会改变 scene shader 的 light permutation → **触发全场景 shader 重编译**（R-ENG-03 的同款灾难）。
→ **用真实 SpotLight 做灯塔，等于同时踩中"额度"和"重编译"两个坑。必须排除。**

### 4.3 旋转光扫怎么实现（若要经典"转一圈"的效果）

**不要每帧重算那几百个 per-cell quad**——用 **1 个大 quad 实例**：
一个扇形/圆形 mesh（radial alpha + 角度衰减），每帧只更新 **1 个 `Transform3D`**（绕 Y 轴旋转）。
成本：**1 draw call + 1 次 transform 写入/帧**。可以忽略。
（它与地面静态斑不是同一个 mesh → 放进第二个 MultiMesh，仍是 1 draw call，合计 §3.4.4 的 +2。）

### 4.4 唯一的取舍：**光斑不会投射阴影**

光斑不会投射阴影，所以灯塔光被树木/房屋挡住时不会出现结构化的暗区——但对一个**夜间地面辉光**来说这项需求根本不存在。若未来要做"被遮挡的光锥"，那是另一个（昂贵的）话题，届时再立项。**对当前 Cape Cod 的核心视觉没有任何损失。**

### 4.5 📌 给运营排产的一句话

> **✅ 可行，据已定案执行。Cape Cod 用同一套光斑系统 + 逐格铺贴实现灯塔地面照明，`SpotLight3D` 完全不用（它在 Compatibility + 全岛单 mesh 下本来就不可用）。**
> **后果：Cape Cod 排在最后的理由之一（"要看真实 SpotLight 数量够不够 / 地面照不照得亮"）正式解除。Cape Cod 的排位今后只由美术资产量决定，不再受引擎能力约束——如果产能需要，它可以往前挪。**

---

## 5. ⑤ 夜间雾色下限：实现条目（可直接开工）

### 5.1 为什么必须解耦（复述并背书美术的物理论证）

夜间背景 `#182d3b` 亮度 **0.16**，而夜态所需雾色亮度 **0.44**——**差 2.75 倍**。
雾是散射介质，夜里被月光与灯火照亮，**应比夜空更亮**。跟随背景会让雾变成"黑烟"，25 格外全吞，**夜间建造直接不可用**。美术的论证我完全背书，这不需要再讨论。

### 5.2 `LocationProfile` 新增字段

```gdscript
# 追加到 LocationProfile（美术 `water-lighting-params.md` §7 结构之后）
@export var fog_floor_by_phase: PackedColorArray   # [晨, 昼, 日落, 夜]；非夜态填 Color(0,0,0,0)
```
四地只用得到下标 3（夜）：

| 地点 | 夜态 `fog_light_color` 下限 | 亮度 |
|---|---|---|
| 泉州 | **`#6A7078`** | 0.44 |
| 圣托里尼 | **`#5A6A84`** | 0.44 |
| Cape Cod | **`#4E5A66`** | 0.35 |
| 塞舌尔 | **`#5E7A82`** | 0.44 |

> **非夜态一律填黑**（`Color(0,0,0,0)`），此时 `max()` 自动退化为原值，无需任何 `if phase == "night"` 分支——**零分支、零额外开销**。

### 5.3 替换 `build_world.gd` 里现有的耦合

现状（`set_night()` L308–318）：
```gdscript
environment.fog_light_color = environment.background_color     # 🔴 要删的就是这一行
```

替换为：
```gdscript
# _apply_fog_color(state_idx: int) -> void
func _apply_fog_color(state_idx: int) -> void:
    var base: Color = profile.fog_light_color_by_phase[state_idx]   # 或天空 T1/T2 上线后 = sky_horizon_of(state)
    var f: Color    = profile.fog_floor_by_phase[state_idx]
    environment.fog_light_color = Color(
        maxf(base.r, f.r), maxf(base.g, f.g), maxf(base.b, f.b))
```

**四条实现要求：**

1. 🔴 **`fog_light_color = background_color` 这行必须删干净**，`_apply_fog_color()` 是唯一写入点。夜态以外的另外三个态仍可继续“派生自天空地平线”（美术 §5.1.1 已核准派生），与本条不冲突。
2. 🟢 与 **① 的 EXPONENTIAL 模式**不冲突（v1.2 由 DEPTH 改回默认）：`fog_light_color` 在两种 `fog_mode` 下都是同一个 UBO 字段，`fog_process()` 照常取用；雾色下限管的是**颜色**，与 `fog_density` 这一个标量**正交**，降级不影响本条。
3. 🟢 与 **`fog_aerial_perspective` / `fog_sun_scatter`** 不冲突：后者只改 `fog_color`（冷暖偏移），本条改的是"下限"这一层，叠加顺序是 `max(base, floor)` 先做，再叠 sun scatter。
4. 🟡 **知识缺口标记**：`maxf` 比较发生在 **sRGB 数值空间**（`Color` 分量即 sRGB 编码值），而着色器内部会 `srgb_to_linear` 后再比较。严格说"最亮"应以 linear 为准。但四地下限都落在明确的中间调亮度区间 [0.35, 0.44]，且此时 base（夜间 sky horizon）必然更暗，因此 `maxf` 在 sRGB 与 linear 两个空间下结论一致，不会翻案。**保留此标记给后人，不要当成 bug 改。**

### 5.4 验收（给严守真的测试用例）

```gdscript
# tests/test_fog_floor.gd
func test_night_fog_reaches_floor() -> void:
    for p in ["quanzhou", "santorini", "capecod", "seychelles"]:
        var prof := load("res://locations/%s.tres" % p) as LocationProfile
        _apply_daylight(NIGHT)
        var got := env.fog_light_color
        var flr := prof.fog_floor_by_phase[NIGHT]
        assert(got.get_luminance() >= flr.get_luminance() - 0.01, "%s 夜态雾色未到下限" % p)
        # 同时断言：夜雾必须显著亮于夜背景（否则又变成"黑烟"）
        assert(got.get_luminance() > env.background_color.get_luminance() * 1.8)
```

**工作量：0.25 人日**（字段 0.05 + 写入 0.05 + 四地填值 0.05 + 测试 0.1）。

---

## 6. ⑥ 历史定性更正（按 team-lead 给出的正确版本）

### 6.1 生效表述（替换此前任何版本的措辞）

> **`godot-web-perf.md` §2 的前瞻警告，今天被字节码反汇编证实。**
> 该文档写作时尚未读取源码，仅基于 Godot Web 端渲染常识推断"每个灯都是真实 `OmniLight3D` 会导致 Web 端崩溃"；`build_world.gd::_add_prop()` 的实际实现证实这个推断完全正确，并且还暴露了当初未预料到的一层恶化——地形是全岛合并的单 ArrayMesh，导致 per-mesh 8 盏上限变成**全岛共享 8 盏**。

**并据此明确更正两条旧措辞：**

| 旧措辞（作废） | 正确表述 |
|---|---|
| ~~"这是已知项延期至今"~~ / ~~"被忽略的旧警告"~~ | **不成立**：`godot-web-perf.md` 写于 9 月 23 日，**游戏本体建得更早**。顺序是**先有判断、后有证据**，不存在"警告在前、忽视在后"。 |
| ~~"暖光灯改造 = 泉州地点级改造"~~ | 🔴 **它是 core 层建材改造**（见 §6.2） |

> 备注：`godot-web-perf.md` 第 54 行现已被同步加上同样的说明；本条以本文为准。

### 6.2 暖光灯改造的重定级：**core 层建材改造，不是泉州地点级 hack**

**定性**：暖光灯是现有 **13 种建材之一**，**四个地点都在用它**（`quanzhou-seychelles-art.md` §4.1 #12「暖光灯 `#EAC989` ✅ 直接复用 → 灯笼」、§9.1 #12 同样 ✅ 复用）。所以它属于 core 共享底座，与地点无关。

**真实故障面（按此写进所有后续文档）：**

| 项 | 内容 |
|---|---|
| **故障现象** | 玩家在四个地点中**任何一个**，放第 **9** 盏暖光灯，第 9 盏起**不再渲染**；相机移动时灯光还会 pop 闪烁 |
| **触发条件** | 与地点无关、与美术资产无关，**只与灯的数量有关** |
| **当前状态** | 🔴 **本体（已上线的基础版）就已经存在此故障**，不是"将来做泉州才会有的风险" |
| **为什么更严重** | 每次放/拆灯会改变该 mesh 的灯光排列（1 directional + N omni）→ Godot 为该材质**重新编译 permutation** → WebGL2 单线程下**主线程同步阻塞**，表现为整个页面冻住 |
| **结论** | 它必须在 MH-ENG-002a（0.5–0.75 人日）修掉，且这个优先级**不因任何地点的排期变化而变化** |

> v1.0 §5.2 那句"暖光灯改造……**强烈建议不塞进 core**"**作废**。正确表述是：**改造本体属于 core，独立立为 `MH-ENG-002`；MH-ENG-002a 与 MH-ENG-002b 都不算 core base 的人日，但 MH-ENG-002a 必须排在泉州之前。**

---

## 7. 本轮新增 / 变更风险登记

> 🔄 **v1.2 复核：雾相关的 R-ENG-08 / 09 / 10 / 12 / 13 的新状态一律见 §7.1。**
> 本表保留 v1.1 原文不动（避免外部文档出现悬空引用），**因此本表里那些"按 §1.3 改用 DEPTH""只改 begin/end"的缓解措辞已过时，不要照着做**。新增条目 R-ENG-14 / R-ENG-15 也在 §7.1。

| ID | 风险 | 等级 | 缓解 |
|---|---|---|---|
| **R-ENG-08** | ⚠️→🔴 **已确认的偏差（不是风险）**：雾模型为 Beer–Lambert，与美术推导所用的 exp² 不符；泉州四个雾值与三地昼态值全部作废 | **高** | 按 §1.3 改用 `FOG_MODE_DEPTH` 并重算（0.5 人日）；§1.5 三张截图交叉验收 |
| **R-ENG-09** | 运行时切 `fog_mode` 可能触发 scene shader variant 重编译（`USE_DEPTH_FOG` 为编译期 define） | 中 | **每地点全程只用一种 mode**，在地点加载 / 预热阶段设一次；N 键只改 `begin/end/density`。并入 `MH-ENG-003` 清单。动手前花 10 分钟实测一次首次切换耗时确认 |
| **R-ENG-10** | `set_fog_mode()` 会强制改写 `fog_density`（0.01 / 1.0） | 中 | 写进控制清单：**必须先设 `fog_mode`，后设 `fog_density`**；并在 `_apply_daylight()` 里加断言 `assert(is_equal_approx(env.fog_density, want))` |
| **R-ENG-11** | 运行时改 `MultiMesh.instance_count` 会触发 GPU 缓冲重分配（等于再造一个 `needs_rebuild`） | 中 | 写进控制清单：**`instance_count` 只在 `_ready` 设一次；运行时只改 `visible_instance_count`** |
| **R-ENG-12** | `fog_height_density` 只要非 0（≥ 0.0001）就会 `max()` 掉深度雾，静默盖掉 `begin/end`，**不报错** | 中 | 写进控制清单：**`fog_height_density` 恒为 0**；在 `_apply_daylight()` 里断言。<br>⚠️ **这是休眠风险**：高度雾只在 `y_dist = y − fog_height < 0` 时起作用，默认 `fog_height = 0` + 地面 `y≈0` ⇒ 恰好不发作。**一旦有人动 `fog_height` 就立刻咬人**，所以它必须留在表里。<br>🔴 **验收的反向确认必须同时设 `fog_height = +100` + `fog_height_density = 0.5`**（只改 density 不改 height，画面**不会有任何变化**，会得到假阴性） |
| **R-ENG-13** | `48.0` 疑似被「相机轨道半径」与「zoom 上限」共用同一常量池条目 → 改 zoom 上限会连带改掉轨道半径，使全部 `begin/end` 换算失真，**不报错** | 中 | 源码层拆成 `CAM_ORBIT_RADIUS` / `CAM_ZOOM_MAX` 两个具名常量 + 断言；验收须做「改 `CAM_ZOOM_MAX` → 轨道半径不变」的反向确认 |
| **R-ENG-02**（更新） | 暖光灯超限 | 高 → **MH-ENG-002a 落地后降为低** | MH-ENG-002a 必须排在泉州之前；真实故障面见 §6.2 |
| **R-ENG-06**（更新） | 合并单 mesh 与 per-mesh 灯限冲突 | 中 | MH-ENG-002a 之后本项目**真实点光源归零**（0 omni + 0 spot）→ 该冲突消失；顺带使 scene shader permutation 全局唯一，**消灭 R-ENG-03 的复发路径** |

> 📌 **R-ENG 编号规则**：号一经进入本表即**不再改号**（避免外部文档出现悬空引用）；新风险一律取新号。跨文档引用时**以语义标题为准，不以数字为准**（V 编号曾发生跨文档错位，见下）。

### 7.1 ⭐ v1.2 复核：雾相关条目的新状态（逐条）

> 起因：雾降级为「每地点视觉常量」（§1.0）。**原则是"不因为现在用不到就删掉"，每条都要写清它在什么条件下会复活。**

> 🔴 **表头约定（2026-09-24 立，读本表必看）· 今后对外引用 R-ENG 一律写「编号 + 语义标题」，不要只写编号。**
> **只写编号的引用视为无效引用，接受者有权要求补齐语义标题。**
> 立这条约定是因为同一个混淆**已经发生两次**：`acceptance-checklist.md` L58 把 R-ENG-11 / R-ENG-13 记成了相反口径；主理人的任务书也记错过一次（把 R-ENG-11 记成「`48.0` 常量共用」，实为 MultiMesh 条目）。
> 编号只是行号，**语义标题才是身份**。冲突裁决（2026-09-24，主理人）：**以本表为准**，理由沿用 §7 既有规则 —— **已登记的号不再改号，新风险取新号**。

| ID | 语义标题 | v1.1 | ⭐ **v1.2 新状态** | 依据 / **复活条件** |
|---|---|---|---|---|
| **R-ENG-08** | 雾模型 Beer–Lambert 与美术 exp² 不符 | 高 | ✅ **关闭**（结论保留为事实基线） | 判定本身永久成立，且现在是**被采纳**的模型，不再是"偏差"。条文保留，供后人知道 16 组值为什么作废 |
| **R-ENG-09** | 运行时切 `fog_mode` 触发 shader 变体重编译 | 中 | 😴 **休眠（等级 → 低）** | 全程 EXPONENTIAL、从不调用 `set_fog_mode()` → 永不触发。**复活条件：任何 `fog_mode` 写入**（含重新启用 DEPTH）；复活时必须同时回到 **V3** |
| **R-ENG-10** | `set_fog_mode()` 会强制改写 `fog_density` | 中 | 😴 **休眠（等级不变）** | 同上。**⚠️ 复活条件比直觉更宽**：连"为了让代码更明确而显式设成默认的 `FOG_MODE_EXPONENTIAL`"也算一次写入——**这是最可能被触发的一条，因为它长得像更安全的写法**（§1.0.6 陷阱 1） |
| **R-ENG-11** | ⭐ **运行时改 `MultiMesh.instance_count` 触发 GPU 缓冲重分配**（🚨 **与雾无关**；曾两次被误记为「`48.0` 共用」——**那是 R-ENG-13**） | 中 | 🟢 **保留，与雾无关，不受本次降级影响** | ⚠️ team-lead 任务书把 R-ENG-11 记为「`48.0` 常量共用」，**那是 R-ENG-13**。R-ENG-11 是 MultiMesh 条目（见 §1.3.2 风险三的括注），**维持原状** |
| **R-ENG-12** | `fog_height_density` 非 0 会 `max()` 掉雾 | 中 | 🔴 **保留，等级不变（中）** | ⭐ **它不是 DEPTH 专属风险**——推导见 §7.1.1。**复活条件：任何 `fog_height_density` 写入，或任何使 `y − fog_height < 0` 的改动**（抬高 `fog_height` 做海面雾、负 y 的水下/地下几何） |
| **R-ENG-13** | ⭐ **`48.0` 被「相机轨道半径」与「zoom 上限」共用**（🚨 **相机常量，不是 MultiMesh**；曾两次被误记为 R-ENG-11） | 中 | 🟡 **降级为低（保留，不关闭）** | 相机常量仍然真实存在，共用风险仍然真实存在。**降级理由不是风险消失，是最坏后果变了**：不再喂任何每帧换算 → 从"雾值全错且不可归因"变为"相机构图变化且立即可见"。5 分钟的具名常量拆分即可彻底消除，**建议仍做** |
| **R-ENG-14** 🆕 | **EXPONENTIAL 无 `begin` ⇒ 近处必然有雾，"近处干净"不可达** | — | 🆕 **中** | 焦点处恒为 `1 − exp(−48ρ) > 0`；要焦点 ≤2% 需 `ρ ≤ 0.00042`，此时 35 格仅 3.2%＝雾不存在（§1.0.5 限制一）。**缓解：把 §1.0.5 的表交给美术，明确"近处干净"不可达，只能整体取淡——防止按直觉越调越小、最后把雾调没** |
| **R-ENG-15** 🆕 | 地点切换时 `fog_density` 未覆盖 → 上一地点密度静默残留 | — | 🆕 **低** | 只写颜色不写密度时必然发生；表现为"这个地点看起来不对"这类不可归因的观感问题。**缓解：`fog_density` 与雾色同在 `_apply_daylight()` 唯一写入点；验收加"A→B→A 来回切"一条** |

**与雾强相关但不受影响的**：R-ENG-02（暖光灯，高，MH-ENG-002a 落地后降为低）、R-ENG-06（点光源归零后冲突消失）—— 均与雾降级无关，**维持原状**。

#### 7.1.1 R-ENG-12 在单一 density 模式下是否仍然成立 —— ⭐ **是，而且完全一样**

**源码结构**（§1.3.3 引用的同一段，`drivers/gles3/shaders/scene.glsl`）：

```glsl
#ifdef USE_DEPTH_FOG
    float fog_z = smoothstep(fog_depth_begin, fog_depth_end, length(vertex));
    fog_amount = pow(fog_z, fog_depth_curve) * fog_density;
#else
    fog_amount = 1.0 - exp(min(0.0, -length(vertex) * fog_density));
#endif
// ↓ 下面是独立的一段，不在 #ifdef 内
if (abs(scene_data.fog_height_density) >= 0.0001) {
    // ...
    fog_amount = max(vfog_amount, fog_amount);
}
```

四点判定：

1. **`max()` 在 `#ifdef` 之外**，两种模式共用 → **风险与 `fog_mode` 无关**。改回 EXPONENTIAL 不会让它消失。
2. 它仍然**静默**：不报错、不警告，只是雾量变了。
3. 它仍然**休眠**：默认 `fog_height = 0`、地面 `y ≈ 0` ⇒ `y_dist = y − fog_height ≈ 0` ⇒ 恰好不咬人。
4. ⭐ **在"美术用眼睛调 8 个值"的新模式下，它比 DEPTH 时代更危险**：DEPTH 时代还有 `begin/end` 可以反查核对；现在只有一个标量，**一旦 height fog 悄悄介入，调出来的数就再也无法复现**，而且现场没有任何线索指向 `fog_height_density`。

> ⚠️ **反向确认的方法不变，且必须两个参数一起改**：只把 `fog_height_density` 设成 0.5 而**不动 `fog_height`**，画面**不会有任何变化**（会得到假阴性，误判成"风险不存在"）。必须 **`fog_height = +100` + `fog_height_density = 0.5` 同时设**，画面才应立刻起雾。

**待写入 `docs/architecture/control-manifest.md` 的条目**（该文件尚未创建，先登记在此；**第 3/4 条已按 v1.2 改写**）：
1. 禁止调高 `rendering/limits/opengl/max_lights_per_object`（保持 8）。
2. 本项目禁止真实点/聚光源，一律 emission + 光斑贴片。
3. 🔴 **禁止写入 `fog_mode`（一行都不要写）** —— 默认 `FOG_MODE_EXPONENTIAL` 即所需模型；写了就踩 R-ENG-10（`set_fog_mode()` 会强制改写 `fog_density`）。<br>~~必须先设 `fog_mode`，后设 `fog_density`~~（v1.2 废止：正解是不调用它）。
4. 🔴 **`fog_density` 必须随四态与地点切换写入**，唯一写入点 `_apply_daylight()`；并断言 `fog_height_density == 0.0`。<br>~~`fog_mode` 仅在地点加载时设置，禁止随 N 键切换~~（v1.2 废止：无 mode 可设）。
5. 运行时禁止修改 `MultiMesh.instance_count`，只改 `visible_instance_count`。
6. 光斑贴片不得合并进地形 ArrayMesh，不得复用 `needs_rebuild`。
7. 🆕 `fog_height_density` 恒为 0.0（R-ENG-12；反向确认须连 `fog_height` 一起改，见 §7.1.1）。

---

## 8. 本轮证据清单（可复现）

全部取自 `https://raw.githubusercontent.com/godotengine/godot/4.4/` 分支，该分支 `version.py` 实测 = **Godot 4.4.2-rc**（已核对）。

| 结论 | 文件 | 用途 |
|---|---|---|
| 默认 `fog_mode = FOG_MODE_EXPONENTIAL`、`fog_density = 0.01` | `scene/resources/environment.h` | ① 判定核心 |
| 枚举提示 `"Exponential,Depth"`、`set_fog_mode()` 改写 `fog_density` | `scene/resources/environment.cpp` | ① + R-ENG-10 |
| **Compatibility 实际雾公式** `1 − exp(−ρ·d)` 与 `#ifdef USE_DEPTH_FOG` 分支 | `drivers/gles3/shaders/scene.glsl` | ① 判定核心 + ② unshaded 不绕过雾 |
| fog 参数走 UBO（`fog_mode` / `fog_density` / `fog_depth_*`） | `drivers/gles3/rasterizer_scene_gles3.cpp` | ① 链路闭合 |
| `render_mode fog_disabled` 的存在与语义 | Godot 4.4 官方文档 *Spatial shaders → Render modes* | ② 正解 |

**未完全闭合的知识缺口（诚实标注）**：

1. 🟡 `USE_DEPTH_FOG` 的确切设置点未能定位到（`rasterizer_scene_gles3.cpp` 超过了单次抓取长度）。**它是否为 shader specialization bit 未 100% 验证** → R-ENG-09 按"会重编译"的保守假设制定缓解，已足够安全；动手前用 10 分钟实测首次切换耗时即可关闭。
2. 🟡 `fog_disabled` → `FOG_DISABLED` define 的映射点同样未直接读到；但 **4.4 官方文档明确列出该 render mode**，且 Compatibility scene shader 里存在语义完全对应的 `FOG_DISABLED` 编译期开关，两者闭合可信度高。**首次实机验证成本 ≈ 5 分钟**（泉州晨态下一眼可见），建议由严守真在接入时顺手确认。
3. 🟡 `INSTANCE_COLOR` 是否可在 **fragment()** 中直接读取未确认（该内置量肯定在 vertex 可用）。§3.4.2 的做法按"需要在 vertex 读取后用 varying 传递"编写，因此无论哪种都成立。

---

## 9. ⭐ core 共享底座人日：**统一口径 = 18（区间 17–20）**

> 本节用于**终结** v1.0 §5.2（我给的 13–16）与 `location-gameplay-design.md` §4.3（设计侧 15–20）之间的口径冲突。
> **两处旧值同时作废**：13–16 是**缺项**，15–20 是**重复计列 + 缺项**。真相落在中间的 **17–20**。

### 9.1 先回答 team-lead 的三个问题

**问题 1 · 13–16 是否包含本轮的 MH-ENG-002a（0.5–0.75）与 MH-ENG-002b（1）？**
→ 🟢 **都不包含，而且它本来也不该包含。** MH-ENG-002a/MH-ENG-002b 是 `MH-ENG-002` 的独立票（core 层建材改造），与"多地点参数化底座"正交。**本节给出的 18 同样不包含 MH-ENG-002a/MH-ENG-002b**（见 §9.4 的两张三行结账表）。

**问题 2 · 15–20 与 13–16 的差额在哪些条目上？**
→ **两个方向都有，且都成立**，逐条见 §9.2 / §9.3。一句话概括：
- **我少算了 4.0** —— 漏列了设计 §4.3 A 里的 **存档 / UI / 网格·相机 三项 core 结构抽取**。
- **他们多算了 ≈2** —— A(10–14) 与我对同一组子系统的细项定价存在重叠，且他们的 A+B 是"打包估"而非细项估。
- **我顺带省了 1.0** —— 天空由**天空 T2**（`ProceduralSkyMaterial`，1.5）降级为美术已拍板的**天空 T1**（顶点渐变天空盒，0.5）。

**问题 3 · 统一口径的最终值？**
→ 🟢 **core 共享底座 = 18 人日（区间 17–20）**。**不随 MH-ENG-002a/MH-ENG-002b 调整**（另计），详见 §9.2–§9.4。

### 9.2 并集去重的合并明细表（每项只出现一次）

| # | 条目 | 人日 | 归属说明 |
|---|---|---|---|
| 1 | `LocationProfile`（.tres 结构 + 加载器 + 校验） | **1.5** | 我 v1.0 #1 |
| 2 | 地点切换器（装配 + 生命周期 + 冷启动/回切） | **1.5** | 设计 §4.3 B 中"LocationProfile/水面"之外的那一半，我 v1.0 **漏列** |
| 3 | `_build_environment` / `_apply_daylight` 参数化（去全部硬编码） | **2.0** | 我 v1.0 #2 |
| 4 | DirectionalLight 组参数化（钳制 + 常驻补光） | **0.75** | 我 v1.0 #4 |
| 5 | 水 shader 参数化 + 三段水深 | **0.75** | 我 v1.0 #3 |
| 6 | 昼夜状态机 keyframe + Tween（**最小版**） | **1.0** | 我 v1.0 #6 |
| 7 | 建材/植物表按地点切换 | **1.5** | 我 v1.0 #7 |
| 8 | 🆕 **存档多地点化**（schema + 版本迁移） | **1.5** | 设计 §4.3 A 的"存档"，**我 v1.0 完全没列** |
| 9 | 🆕 **UI/HUD 地点无关化**（最小钩子，非重做） | **1.0** | 设计 §4.3 A 的"UI"，**我 v1.0 完全没列** |
| 10 | 🆕 **网格/相机 core 化**（world model 与渲染解耦的最小抽取 + 相机 preset） | **1.5** | 设计 §4.3 A 的"网格/相机"，**我 v1.0 完全没列** |
| 11 | 天空 **T1（顶点渐变天空盒）**（⭑ 非**天空 T2** ProceduralSkyMaterial） | **0.5** | 由我 v1.0 #5 的 **1.5 下调**（美术已拍板 v1 上**天空 T1**） |
| 12 | 🆕 雾：`FOG_MODE_DEPTH` 切换 + 四地四态接入 | **0.5** | 本轮 §1（v1.0 时此工作不存在） |
| 13 | 🆕 夜间雾色下限解耦（含验收测试） | **0.25** | 本轮 §5 |
| 14 | 地点资产 loader（几何数据化 + IndexedDB） | **2.0** | 我 v1.0 #8 **=** 设计 §4.3 C，**两侧口径已一致** |
| 15 | shader 预热 + 加载遮罩 | **0.5** | 我 v1.0 #9；**设计侧未列** |
| 16 | 测试：冒烟 + 视觉回归 + JS 内存/帧率 | **1.5** | 我 v1.0 #10；**设计侧未列** |
| — | **点估合计** | **18.25 → 定 18** | **区间 17–20** |

### 9.3 两处旧值各自的错处（记账式，可复核）

**13–16 为什么不是对的（我的错，明确承认）**

| 方向 | 条目 | 人日 |
|---|---|---|
| ➕ 漏列 | #8 存档 / #9 UI / #10 网格·相机（core **结构抽取**） | +4.0 |
| ➕ 漏列 | #2 地点切换器 | +1.5 |
| ➕ 本轮新增 | #12 雾 DEPTH + #13 夜雾下限 | +0.75 |
| ➖ 省下 | #11 天空：T2(1.5) → T1(0.5) | −1.0 |
| — | 13.0（原小计下沿）+ 净 **+5.25** | **= 18.25** |

> **根因**：v1.0 我把"core 底座"理解成了"**多地点参数化能力**"，而设计侧的 `core 抽取` 指的是**代码结构层**（网格/相机/UI/昼夜/存档/建材基类）。二者是**并集关系，不是同义词**——我按自己的口径估得很细很准，**却漏掉了对方的半个定义域**。
> 我已逐条核对 #8/#9/#10 与我 v1.0 的那十条**无一重合**，所以它们是**净漏列**，不是重复计列。

**15–20 为什么偏高**

- 他们的 A(10–14) + B(3–4) = **13–18**，覆盖"6 个子系统 + 切换器 + LocationProfile + 水面"；我对**同一集合**的细项定价是 #1+#2+#3+#4+#6+#7+#8+#9+#10 = **11.25** → **高出 1.75–6.75**。差额来自"A/B 是打包估、且 A 的括号里那 6 个子系统粒度太粗不好核价"。
- 同时他们的 15–20 **完全没有** #11 天空(0.5) / #15 预热(0.5) / #16 测试(1.5) / #12 雾(0.5) / #13 下限(0.25)，合计 **3.25**。
- 两者相抵：13–18 + 3.25 = **16.25–21.25** —— 与我 §9.2 的 **17–20 高度吻合**。
- **结论：15–20 是"正确的形状、偏高的项"，13–16 是"缺项"，取并集去重后落在 17–20。**

**关于 team-lead 猜测的"你少算了 fog 四态 × 四地点的美术调试"** —— 🟢 **这个猜测不成立，但它指出了一个真实的口径边界，我把它写明：**
core 只承担"**四态雾能被参数系统驱动**"这一能力，已在 #12（0.5）内；**每一组具体数值的调优属于各地点的美术成本**，不属于 core。若把它计入 core，需要 **+0.5–1.0**，但那样就必须**同时从四地点的美术预算里扣掉**，否则同一个调试动作被计两次。
→ **我的建议：不计入 core，边界按本段执行。**

### 9.4 结账口径（两张表，可直接给运营）

**表 A · core 底座本体**

| 口径 | 人日 | 用途 |
|---|---|---|
| **点估（基准）** | **18** | 排期、产能、现金流测算一律用这个 |
| 乐观 | 17 | 地板线用的口径（= 18 − 测试减 1.0 − UI 减 0.5 ≈ 16.75 进位） |
| 悲观 | 20 | 风险储备，不做排期承诺 |
| **不含** | MH-ENG-002a(0.5–0.75) + MH-ENG-002b(1.0) | 它们是 `MH-ENG-002`，见表 B |

**表 B · 与 MH-ENG-002a/MH-ENG-002b 的关系**

| 票 | 人日 | 是否含在 core 18 内 | 关键路径 |
|---|---|---|---|
| core 底座 | 18 | — | 必须在泉州之前 |
| **MH-ENG-002a**（删 `OmniLight3D` + 灯体 emission + 删 `set_night()` 的 `needs_rebuild`） | **0.5–0.75** | ❌ 不含 | 🔴 **必须在泉州之前**；⭑ 且必须**排在 core #3（`set_night` 参数化）之前——两者改同一段代码，先删后参数化，否则参数化完再返工** |
| **MH-ENG-002b**（光斑贴片 MultiMesh + 次第亮起 + Cape Cod 光锥） | **1.0** | ❌ 不含 | 🟢 可与泉州并行或排其后 |

> 📌 **给运营的两个可直接引用的数**：
> - **"能开工泉州前必须完成的工程量" = core 18 + MH-ENG-002a 0.75 = ≈19 人日**
> - **"可从关键路径移出并行的工程量" = MH-ENG-002b 1.0 人日**

### 9.5 行-by-row 推导：三个口径的最终结账数

> ⚠️ **本节替换了 v1.1 初稿给出的 82–106。那一版是错的（见 §9.5.4），团队不得使用。**

#### 9.5.1 行 1 · 地点合计（不含 core）

取自 `location-gameplay-design.md` §4.4 块的四行（**该块明确写的是「圣托里尼 v1.0（20–26）」，即减配档**，不是 §4.2 的 25–35）：

| 地点 | 低 | 高 | 中位 |
|---|---|---|---|
| 泉州·雾港 | 12 | 16 | 14 |
| 圣托里尼（**v1.0 减配**） | 20 | 26 | 23 |
| 塞舌尔 | 20 | 28 | 24 |
| Cape Cod | 12 | 18 | 15 |
| **小计（不含 core）** | **64** | **88** | **76** |

**自校验**：12+20+20+12 = **64** ✅、16+26+28+18 = **88** ✅ —— 与设计侧已发布的「合计（不含 core）64–88」**逐位吻合**。
这也反过来确认了：**设计侧的合计用的是减配档**，不是全量 25–35。

#### 9.5.2 行 2 · 含 core 的满配区间

区间传播必须**端点对端点**（core 下沿配地点下沿、core 上沿配地点上沿）：

| 口径 | 算式 | 结果 |
|---|---|---|
| 下沿 | core **17** + 地点 **64** | **81** |
| 上沿 | core **20** + 地点 **88** | **108** |
| 点估 | core **18** + 地点 **76** | **94** |

> 🟢 **满配口径 = 81–108（点估 94）。这是可用值。**
> 旧值 79–108 的下沿 79 = 15 + 64（用旧 core 下沿 15），与我这次的差异**只来自 core 下沿 15 → 17 这 +2 人日**，上沿 108 完全未变。

#### 9.5.3 行 3 · 地板线与推荐排期（**统一含 MH-ENG-002a**）

地板线构成取自 `location-gameplay-design.md` §4.7.3，我只替换其中的 core 分量（15 → 17）：

| 分量 | 旧地板线 | 新地板线 | 说明 |
|---|---|---|---|
| core（地板口径） | 15 | **17** | 见 §9.4 表 A；= 18.25 − 测试减 1.0 − UI 减 0.5 ≈ 16.75 → 进位 17 |
| 泉州 floor | 10 | 10 | 不变 |
| 圣托里尼 floor | 20 | 20 | 不变（已是 v1.0 减配） |
| 塞舌尔 floor | 16 | 16 | 不变 |
| Cape Cod floor | 10 | 10 | 不变 |
| **小计** | **71** | **73** | +2 = core 的增加额 |
| **＋ MH-ENG-002a（泉州开工前必须）** | — | **+0.75** | ⭑ 采纳 team-lead 决定：对外统一含 MH-ENG-002a |
| **地板线（对外）** | **71** | 🟢 **74** | 73.75 → 进位 74 |

推荐排期的构成沿用既有关系（**差额恒为 7**：泉州 floor 10 → 中位 14 计 **+4**；圣托里尼 floor 20 → 中位 23 计 **+3**）：

| 口径 | 算式 | 结果 |
|---|---|---|
| 推荐排期（不含 MH-ENG-002a） | 73 + 4 + 3 | **80** |
| **推荐排期（对外，含 MH-ENG-002a）** | 73.75 + 7 | 🟢 **81** |

> ✅ **两行同口径校验**：81 − 74 = **7**，与旧关系的 78 − 71 = **7** 完全一致。**地板线与推荐排期现在可比了。**

**统一结账表（给运营，三行全部含 MH-ENG-002a 0.75）**

| 口径 | 不含 MH-ENG-002a | 🟢 对外（含 MH-ENG-002a） |
|---|---|---|
| 齐发地板线 | 73 | **74** |
| **推荐排期** | 80 | **81** |
| 满配区间 | 81–108 | 81.75–108.75（仍建议报 **81–108**，见下方注） |
| 点估 | 94 | 94.75 |

> 注：满配区间的跨度（27 人日）远大于 MH-ENG-002a 的 0.75，**是否含 MH-ENG-002a 落在舍入噪声内**，且它的用途是"上限/现金流失控边界"，不需要与地板线精确可比。因此建议对外仍报 **81–108**，在脚注写明"地板线与推荐排期已含 MH-ENG-002a；满配区间的不确定度远大于 MH-ENG-002a，故不再单独标定"。
> 首发债务 **19–33 不变**（与 core 无关），1.1 偿付压力不变。

#### 9.5.4 🔴 明确记录一次我的错误（防止后人重犯）

**v1.1 初稿我给的 82–106 是错的。** 错误不是算错加减法，而是**区间传播的方式**：
我把 core 的**点估 18** 同时加到了区间的两端（`64+18=82`、`88+18=106`），而正确做法是**端点对端点**（`64+17=81`、`88+20=108`）。

> ⭐ **为什么这个错误比"差几个人日"更值得写下来**：
> **用点估压和一个区间，会把不确定性"吃掉"，产出一个比任何输入都更窄的区间。**
> 它对外呈现为"更精确"，实际是**虚假精确** —— 输入的 core 是 17–20（跨 3 人日），产出的总区间却只跨 24 人日而不是真实的 27 人日。
> **凡本文此后的区间运算，一律端点对端点；点估只用于单值口径（如现金流的基准场景），不得用于压和区间。**

---

### 9.6 🔴 记账禁令（防止跨边界双重计费）

> 由 team-lead 提出并采纳。这类错误的特征是：**它在当下完全看不出来，要到后期对账时才暴露，而那时已经按错误数字排过产能和现金流。**

**禁令一（正式） · 禁止同一个工作项在 core 与地点预算各记一次。**
任何单一工作项必须**在一处记全额、在另一处记 0**，并在**两处都写明本项记于何处**。禁止两边各记一部分。

**判别动词（core vs 地点的边界）**

| core 只记 | 地点只记 |
|---|---|
| **能力**：系统能做什么（状态机、参数通道、切换器、loader） | **内容**：用这个能力填进去的东西（具体数值、具体资产、具体判定规则） |
| 一次性实现，四个地点共同继承 | 每地点各自的美术 / 设计 / 内容填充 |
| 例：四态雾**能被驱动** | 例：这 16 组雾**数值的调优** |

**已识别的一处待裁决嫌疑（我不自行扣减）**
`location-gameplay-design.md` §4.2 里 Cape Cod 的「⑤ 雾态需扩昼夜状态机」，与 core #6（昼夜 keyframe + Tween）与 core #12（四态雾接入）**可能存在重叠**：若这条指的是"扩状态机"这个机制，它已由 core 提供一次；若指的是"填四态雾数值"，则属地点成本。
→ **我不擅自扣减设计侧的数字。** 若确认为机制性重复，需从对应地点预算扣除（量级约 **0.5–1.0/地点，合计 0–2**），**由 design-strategist 裁决后执行**。在此之前，§9.5 的所有数字维持**未做任何地点级扣减**的口径。

**禁令二 · 任何导致 core 或地点预算变动的重核，必须同时给出「扣在哪一行」的清单，不能只改总数。**
（本次已按此执行：core 由 15–20 改为 18，只动 §4.3/§4.4 的 core 行与 §4.7.3 的 core 分量，**四个地点行与首发债务 19–33 均未动**。）

---

### 10. 给 `reskin-matrix-assessment.md` 的门控改写件（可直接粘贴）

> 起因：release-ops-lead 指出 reskin-matrix 里仍有 6 处用已废弃的 `.pck` 分包当门控规格。
> **原则引用 `location-gameplay-design.md` §4.7.4：「门的内容不能写成废弃方案，否则验证的是错的东西」。**
> 本节给出每处的**替换原文**，均为技术侧裁定口径，**可直接粘贴，不必再向我确认**。

### 10.1 先给一句总口径（可引用）

> ### ⭐ G1 / 技术成立 / T0 的统一口径
> **地点资产按需加载的现行路线是「几何数据化 + 运行时 `ArrayMesh`」（2 人日，§4.2），`.pck` + `load_resource_pack()`（3.5 人日）已于 §4.2 裁决不采用。**
> **因此任何构建门、判据、spike、风险行，都不得再出现 `.pck` / PCK / `load_resource_pack` 字样**——门验证的是"我们要走的那条路能通"，写成废弃方案等于把 T0 的一次黄金验证机会花在一个我们不做的东西上。

### 10.2 六处逐条替换件

| # | 位置 | 现文案（作废） | ⭐ 替换为 |
|---|---|---|---|
| 1 | **L139** | 必须在 core 完成后立刻做 T0 内部技术试玩，把 `.pck` 分包与地点切换的管线风险压在静默期结束之前 | 必须在 core 完成后立刻做 T0 内部技术试玩，把**运行时资产加载（几何数据化 + ArrayMesh）**与地点切换的管线风险压在静默期结束之前 |
| 2 | **L202**（§3.3 技术成立判据） | `.pck` 分包按需加载 spike 通过；主包不内置全部地点资产；加载失败可恢复；存档带 `location_id` 与 `schema_version` | **运行时资产加载（几何数据化 + `ArrayMesh`）spike 通过**；主包不内置全部地点资产；**下载可重试/可恢复**；**地点资源可在运行时精确卸载**；存档带 `location_id` 与 `schema_version` |
| 3 | **L270**（时间表） | PCK 分包 spike | **运行时资产加载 spike（几何数据化 + ArrayMesh）** |
| 4 | **L271**（T0 内容） | T0 内部技术试玩（现有本体跑地点切换 + `.pck` 分包加载） | T0 内部技术试玩（现有本体跑地点切换 + **运行时几何数据加载**） |
| 5 | **L306**（**构建门 G1**） | Windows/Steam 候选构建、PCK 分包、加载失败恢复、回滚包 | Windows/Steam 候选构建、**运行时资产加载（几何数据化 + ArrayMesh）管线通过**、**下载失败可重试与可恢复**、**地点可精确卸载**、回滚包 |
| 6 | **L348**（Blocker 风险行） | PCK 分包失败 ｜ Blocker ｜ 多地点全进主包会放大 43.6MB 首屏问题 | **运行时资产加载管线失败** ｜ Blocker ｜ 见下方 §10.4（⚠ **原写的"放大 43.6MB 首屏"这个依据是错的，必须一并改掉**） |

### 10.3 G1 的五项可核验收据（建议作为行宽度不足时的展开内容）

1. **主包不动**：切换/新增地点**不需要重新导出** `index.pck` / `index.wasm`。⭑ **这是本条最关键的核验点**——它正是"几何数据化 + ArrayMesh"相对 `.pck` 的核心收益（避开 Godot 版本锁：pack 与导出版本必须一致，本作从 4.4 升 4.5 时所有历史地点包都得重导）。
2. **异步不阻塞**：单线程（`GODOT_THREADS_ENABLED = false`）下用 `HTTPRequest` 下载，**主循环不卡死**，加载遮罩期间 UI 仍可响应。（这也是选它的理由之一：`.pck` 的 `load_resource_pack()` 在无线程时是同步的。）
3. **可精确卸载**：反复进入/离开同一地点 N 次后，JS 堆不呈单调增长。⭑ 这是 `.pck` 做不到的——**Godot 4 没有 `unload_resource_pack()`**，挂载即永久占用内存。
4. **失败可恢复**：断网 / 404 / 数据校验不符，三种情况都进入**可重试状态**并给出明确报错，不白屏、不崩溃。
5. **回滚包**：加载中断或数据损坏时，能退回上一个可用地点状态。

### 10.4 ⚠️ L348 的 Blocker 行：连带修掉一个错误的归因

原文写的理由是「多地点全进主包会**放大 43.6MB 首屏问题**」。**这个依据已被证伪，请勿沿用**（见 §4.0 与 R-ENG-01）：

- 已导出 `index.pck` 总计 **373,456 字节**（含 8 个 GLB 转的 `.scn` ≈83KB、中文字体 ≈210KB、脚本 ≈52KB）；**四个地点的全部几何资产加一起是几十 KB～几百 KB 量级**。
- 43.6MB 的 `index.wasm` 是 **Godot 引擎本体**，与地点数量基本无关。**新增地点不会让它涨。**

> ⭐ **这条 Block 的真实理由应该写：**
> **风险**：不卸载控制的内存增长（浏览器标签 2–4GB 上限）+ 每次加地点都要重导主包的迭代成本。
> **缓解**：最先做技术 spike（并入 T0）；几何数据自带版本号与校验和；加载失败不阻塞主循环；按 §10.3 五项验收。
> 🔴 **请勿把这条再误读为"需要缩减美术资产"** —— 资产不是瓶颈。这一条我在 §4.0 已经强调过一次，这里再绑一次到具体的门控行上，因为它最容易在转述中变形。

### 10.5 编号命名空间结论（撞名结案）

**你的照明改造两个分级（原称 T1 / T2）已于 2026-09-24 正式更名为工程任务编号：**

| 旧称 | ⭐ 现称（生效） | 内容 | 人日 |
|---|---|---|---|
| ~~照明 T1~~ | **`MH-ENG-002a`** | 删 `OmniLight3D` + 灯体改 emission + 删 `set_night()` 的 `needs_rebuild` | 0.5–0.75 |
| ~~照明 T2~~ | **`MH-ENG-002b`** | 光斑贴片 MultiMesh（`blend_mix`）+ 次第亮起 + Cape Cod 灯塔光锥 | 1.0 |

> **`T0–T4` 命名空间现已完全归还给试玩批次**（`location-gameplay-design.md` §4.7.4）。
> reskin-matrix 里临时立的"涉及人日一律写『照明 MH-ENG-002a/照明 MH-ENG-002b』"这条补充规则**可以删除了**——它解决问题的方式是加限定词，而正解是让工程任务离开 T 命名空间，现在冲突源已经没有了。
> **是否要把试玩批次再改叫 P0–P4**：技术侧**不反对，但也不认为有必要**。撞名已由我方改名消除，维持 T0–T4 不再产生任何歧义。这属于运营/发布侧自己的标识习惯，**由 team-lead 或你决定即可，不用问我**。

### 10.6 ✅ 静默期的两个数（你的第 3 问，需要改）

**你的算术没错 —— 但泉州取错了估计量。**

| 口径 | 算式 | 结果 |
|---|---|---|
| 你的算式 | core floor **17** + 泉州 **floor 10** | 27（✅ 算术无误，但**泉州取错了**) |
| ⭐ 现行（不含 `MH-ENG-002a`） | core floor **17** + 泉州**完成态下沿 12** | **29** |
| ⭐ **对外（含 `MH-ENG-002a` 0.75）** | 29 + 0.75 ≈ 29.75 | **30** |

> ⭐ **core floor = 17 你没猜错，这点确认无误。要改的是泉州那一侧。**
> 🔴 **这里有两个不同的泉州估值，不可互换**（`location-gameplay-design.md` §4.7.4 已专门标出）：
> - **泉州 floor 10** —— 齐发地板线用。含义是"过 M1–M5 这个船闸的最低限度"。
> - **泉州完成态下沿 12** —— 静默期用。含义是"一个**完整**、能对外试玩的泉州切片"。
>
> **静默期必须用后者**：T0 的节点定义是"首次对外试玩"，而 floor 10 的产品状态是"四个都成立但都不丰满"，**那不是一个能给人玩的东西**。

另：与旧值 27（= core floor 15 + 泉州完成态下沿 12）相比，**29 的增量 +2 全部来自 core 17，估计量未变**，所以这个数可以直接替换。

> ⚠️ 最后再帮后人挡一个坑（与 §9.5.4 同源）：**不要用 core 点估 18 去算这个数**。18 与 floor 17 是两个不同的估计量（点估 vs 地板口径），混用会得到看似更精确的 30/31，实际不成立。**区间四舍五入口径一律：地板配地板，点估配点估。**

---

## 11. ⭐ 补遗 v1.2 · 雾降级的人日影响（**只报数，不改排产**）

> 由 team-lead 指定口径：**只核算、只报数，不修改任何已发布的排产数字。**
> **core 18 / 地板线 74 / 推荐 81 / 满配 81–108 —— 一律维持原样，由 team-lead 统一裁决后再动。**
> 依据：§1.0 的雾降级裁定。

### 11.1 逐项核算

| 项 | v1.1 | ⭐ v1.2 | Δ | 说明 |
|---|---|---|---|---|
| core #12 · 雾接入 | **0.5**（`FOG_MODE_DEPTH` 切换 + 四地四态接入） | **0.2** | **−0.30** | 拆分见 §11.2 |
| core #13 · 夜雾下限 | **0.25** | **0.25** | **0** | 🔴 明确"这条不能省"（§1.0.4 #1）：不修会让夜雾变黑烟、夜间建造不可用 |
| §1.5 的「四地雾值换算填入 + pitch 联动验收截图 0.25」 | 0.25 | （并入 #12） | **0** | ⚠️ **不单独计**：它含在 #12 的 0.5 内，再扣一次就是双重计费（§9.6 禁令一）。其中 pitch 部分作废 |
| **合计** | **0.75** | **0.45** | **−0.30** | |

### 11.2 core #12 的 `0.5 → 0.2` 拆分（可逐条复核）

| 子项 | v1.1 | v1.2 | 理由 |
|---|---|---|---|
| 切换 `fog_mode` + 防 R-ENG-09/10 的顺序处理 | 0.15 | **0** | 不调用即无需防护（R-ENG-09/10 转休眠） |
| 每帧按 pitch 换算 `begin/end`（含 pitch 单一数据源约束） | 0.15 | **0** | 无 `begin/end` 可算；pitch 问题本身也不存在（§1.0.7 收益二） |
| `CAM_ORBIT_RADIUS` / `CAM_ZOOM_MAX` 具名常量拆分 + 断言（R-ENG-13） | 0.05 | **0**（建议做，不计入） | 降级为"建议"（§7.1），成本 5 min |
| `LocationProfile` 2 个标量字段 + `fog_density_for()` 派生 | 0.05 | **0.05** | 保留（写 2 个标量比写 4 态数组更不容易错，见 §1.0.8） |
| `_apply_daylight()` 写入 + 三条断言 | 0.05 | **0.05** | 保留（写入点从 3 个 UBO 值降到 1 个标量） |
| 四地 8 个值填入（工程侧填值，**不含美术调优**） | 0.05 | **0.05** | 保留（不再有换算，纯填值） |
| 冒烟：地点切换 density 不残留（R-ENG-15） | 0 | **0.05** | 🆕 新增 |
| **合计** | **0.5** | **0.2** | **−0.30** |

### 11.3 对四个对外数字的影响 —— ⭐ **全部不变**

按 §9.5 的**端点对端点**传播规则（不得用点估压和区间，见 §9.5.4）：

| 口径 | 现值 | 扣 −0.30 后 | 舍入后 | 结论 |
|---|---|---|---|---|
| core 点估 | **18**（明细 18.25） | 17.95 | 18 | **不变** |
| core 地板分量 | 17（= 18.25 − 1.5 → 进位） | 16.45 → 进位 17 | 17 | **不变** |
| **地板线（含 MH-ENG-002a）** | **74** | 73.45 → 进位 74 | **74** | **不变** |
| **推荐排期（含 MH-ENG-002a）** | **81** | 80.45 → 81 | **81** | **不变** |
| 满配区间 | **81–108** | 80.7–107.7 | 81–108 | **不变** |
| 点估 | 94 | 93.7 | 94 | **不变** |

> ⭐ **我的建议：不要因为 −0.30 下调任何对外数字。** 三条理由：
> ① **0.30 小于任何对外数的舍入粒度（1 人日）**；
> ② 它落在 core 区间 **17–20 内部**，本就不是"确定省下的钱"；
> ③ 留作风险储备比退给排期更划算 —— **而 §11.4 那个新增成本（已批准）会吃掉其中的 0.25，净仍省 0.05。**

### 11.4 ✅ 运行时调参滑块 —— 🟢 **已批准**（Benja 亲自拍板，2026-09-24 · **0.25 人日**）

> 🔄 **本节状态：⚠️ 待裁决 → ✅ 已批准。** 不再需要裁决，实现规格见 **§13.1**（可直接开工）。本节只留**定位与记账**。

降级后 8 个值改为"美术用眼睛调"。**如果每调一轮都要工程侧重导 Web 包配合截图**，成本会滚起来：

- 4 地点 × 2 档 × 平均 2 轮 = **16 次** ×（重导 + 截图）≈ 15 min/次 ≈ **4 小时 ≈ 0.5 人日**。
- 按 §9.3 边界这属**各地点的美术成本**，不计入 core；但**它占用的是工程侧的时间**，且实际执行时一定会来找工程。

**⭐ 定位（写在这里，避免将来有人把它当成"锦上添花"砍掉）**：

1. 🔴 **它是泉州 / Cape Cod 夜档那次 A/B 的执行载体**（§1.0.10d）。那次 A/B 的判据是"灯 : 墙对比 ≥ 5:1"，**不装滑块就得为重导 Web 包排一个专门场次**；装了就是浏览器里拖两下。
2. 🟢 **它是美术调 8 个值时的往返成本对冲** —— 省下的是上面那 0.5–1.0 人日的"改值 → 重导 → 截图"。
3. **净收益 ≈ 支出 0.25 / 省下 0.5–1.0 人日。**

**归属与记账**

- 它是"能力"不是"内容"（§9.3 判别动词）→ **属 core**，新增条目 **#17**。
- 🔴 **不回写 §9.2 表**：该表是 `18.25` 的历史推导 basis，往里加行会破坏"可复核的加法"。新条目在本节单列。

| 口径 | 算式 | 结果 | 对外是否变 |
|---|---|---|---|
| core **明细** | 18.25（v1.1）− 0.30（雾降级）+ 0.25（#17） | **18.20** | 明细数，非对外 |
| core **对外点估** | 18.20 → 舍入 | **18** | 🟢 **不变** |
| core **地板分量** | 18.20 − 测试 1.0 − UI 0.5 = 16.70 → 进位 | **17** | 🟢 **不变** |
| **地板线（含 MH-ENG-002a）** | 17 + 泉州 10 + 圣 20 + 塞 16 + Cape 10 = 73；+0.75 → 73.75 → 进位 | **74** | 🟢 **不变** |
| **推荐排期（含 MH-ENG-002a）** | 73.75 + 7 | **81** | 🟢 **不变** |
| **满配区间** | core **17–20** + 地点 **64–88**（端点对端点） | **81–108**（点估 94） | 🟢 **不变** |
| **首发债务** | 与 core 无关（§9.5.3 注） | **19–33** | 🟢 **不变** |
| **静默期** | core floor **17** + 泉州完成态下沿 12 | **29**（对外 30） | 🟢 **不变** |

> ⭐ **四个对外数字（74 / 81 / 81–108 / 19–33）与静默期 29 —— 全部一个字都不动。** 这条是本节的硬约束，也是它被批准的前提。

> 🔴 **记账口径纠正（必须记一笔，否则后人会被误导）**
> 任务书写的是「core **18 → 18.25**」。**这个写法不成立**：18 是 18.25 的**舍入结果**，拿已舍入的 18 当基数再加 0.25，等于把舍入垫回去了 —— 与 §9.5.4 是同一型错误（"用点估压和区间"的镜像版本：**用舍入值当基数做增量**）。
> **正确明细 = 18.25 − 0.30 + 0.25 = 18.20**，对外仍报 **18**。
> 两种写法**对外结果完全相同**（都是 18，四个对外数都不变），**不影响任何排期**；但文档里请写 **18.20**，不要写 18.25 —— 否则后人一读会以为"雾降级省下的 0.30 被滑块全额吃光了"，而实际只吃回 0.25，**净仍省 0.05**。

### 11.5 一句话给运营 / 主理人

> 雾降级**省 0.30 人日**（core #12：0.5 → 0.2），夜雾下限 0.25 不变；**已批准额外花 0.25 人日**做一个运行时调参滑块（§11.4 / §13.1），用它换掉预计 **0.5–1.0 人日**的"改值 → 重导 → 截图"往返。
> **净：core 明细 18.25 → 18.20（净省 0.05）**，对外 core 点估仍 **18**，**地板线 74 / 推荐 81 / 满配 81–108 / 首发债务 19–33 / 静默期 29 —— 五个对外数一个字都不动。**

---

## 12. 🔴 给 `acceptance-checklist.md` 的 v1.2 改写件（**阻断项** · 需 team-lead 派工给严守真）

> **起因**：art-director 报出 `acceptance-checklist.md` L50–58 与 A-8 把 R-ENG 编号写成了相反口径。我复核后发现 **问题比编号严重得多**：
> **该文件的整个雾验收体系（阶段 A 的 A-2/A-3/A-5/A-6/A-7、阶段 B 的 B-1~B-4）都建立在已作废的 DEPTH 模型与已撤销的判据上。**
> 🔴 **照现状跑验收，四地会在阶段 B 全部阻断；而且它给的"失败时怎么办"会指引验收员去调 `x_begin` / `x_end` 这两个已不存在的参数。**

### 12.1 严重性：这不是编号问题，是「门验证的是错的东西」

**原则沿用 §10.1（既有）**：门的内容不能写成废弃方案，否则验证的是错的东西。这次是同一条原则在验收单上的第二次发作。

**现状推演**（按现行 acceptance-checklist 跑，会发生什么）：

| 条目 | 现状判据 | v1.2 实际 | 结果 |
|---|---|---|---|
| A-2 | 焦点恒等式 `D(0)=48.00`｜🔴 阻断 | 焦点距离仍是 48.00，但**没有换算链要验了** | 🟡 应降级为记录项 |
| A-3 | pitch 1.25 → 25 格应读 22.7%｜🔴 阻断 | 无 `begin/end`；实际随 pitch 只摆 **3.1pp** | 🔴 判据不可执行 |
| A-4 | `fog_disabled` 生效｜🔴 阻断 | ✅ 仍然成立，且**已无退路** | 🟢 保留并升级 |
| A-5 | 环绕抖动（V4） | 无 `begin/end` | 🔴 整条作废 |
| A-6 | 首次切 DEPTH 耗时（V3/R-ENG-09） | 从不切 DEPTH | 🔴 测不到任何东西 |
| A-7 | 先设 `fog_mode` 后设 `fog_density`｜🔴 阻断 | 正解是**一行都不写** | 🔴 **按判据必挂，而挂的恰恰是正确的写法** |
| A-8 | `48.0` 拆具名常量（R-ENG-11）｜🔴 阻断 | 实为 **R-ENG-13**，且已降级为"建议" | 🟡 编号错 + 等级错（不该再是阻断） |
| A-9 | `fog_height_density` 恒为 0｜🔴 阻断 | ✅ 仍成立（与模式无关，§7.1.1） | 🟢 保留，需补一句说明 |
| **B-1** | 昼态 O(8格) ≤ 5%｜🔴 阻断 | 泉州昼 O(8格) = **19.5%** | 🔴 **必挂**（且判据已被用户撤销） |
| **B-2** | 昼态 O(25格) ≤ 25%｜🔴 阻断 | 泉州昼 24.1%（擦边）、Cape Cod 21.9% | 🟡 擦边，判据已撤销 |
| **B-3** | 16 组 `x_begin` 全查｜🔴 阻断 | `x_begin` 参数**不存在** | 🔴 **不可执行** |
| **B-4** | 泉州 昼23.0 / 晨61.9 / 落差 ≥2.0｜🔴 阻断 | 晨 = 昼档；泉州昼 24.1%、"晨"亦 24.1%，落差 0 | 🔴 **必挂** |
| **B-5** | 四地昼态梯度可辨｜🔴 阻断 | 泉州 17.5% vs Cape Cod 15.9% **只差 1.6pp** | 🔴 **会挂**（但这是结构限制，不是缺陷） |

> ### ⭐ 最危险的一条是 **B-4**
> 它写的是「泉州晨 61.9%」——**这正是用户撤销的那组判据之一**（§1.0.3 #5）。
> 验收员照它打勾，会把"雾降级"判为不合格，**而降级本身就是用户拍板要求的**。
> **等于用被撤销的判据，去否决撤销它的那个决定。**
>
> ### ⭐ 第二危险的是 **B-5**
> 它要求"四地昼态梯度可辨"，但泉州 vs Cape Cod 只差 **1.6pp**，肉眼读不出（§1.0.10c）。**这条会挂，而它挂的是一个 EXPONENTIAL 下物理上做不到的事。** 判据必须改（见 §12.2 #16），否则验收员会去拉 density 救它，把泉州推向糊。

### 12.2 逐条替换件（**可直接粘贴，不必再向我确认**）

| # | 位置 | 现文案（作废） | ⭐ 替换为 |
|---|---|---|---|
| 1 | **L4** 回源行 | 回源 `tech-feasibility.md`（v1.1 补遗） | 回源 `tech-feasibility.md`（**v1.2**，**§1.0 为雾的最终口径**）；雾值唯一源 = `water-lighting-params.md` §5.1.1.1 / §7 |
| 2 | **L43 / L91** | V 序列只保留 V2/V3/V4 | **V 序列只剩 V2（`fog_disabled`）**。V3（DEPTH 注入点）、V4（begin/end 每帧换算）均已关闭 |
| 3 | **L50–58** 编号段 | R-ENG-11 = `48.0` 共用；MultiMesh 改号 R-ENG-13 | 🔴 **反了**。以 `tech-feasibility.md` §7 登记表为准：**R-ENG-11 = 运行时改 `MultiMesh.instance_count`（与雾无关）**；**R-ENG-13 = `48.0` 被轨道半径与 zoom 上限共用**。**并删掉"工程侧改完之前本文件仍是消歧的唯一依据"** —— 该前置条件已失效（§7 早已是权威，且已加 §7.1） |
| 4 | **A-2** | 焦点恒等式 ｜🔴 阻断 | 🟡 **降级为 ⚪ 记录项**：不再有换算链要验；保留只为顺手确认相机常量没被误改（R-ENG-13）。**不再是阻断项** |
| 5 | **A-3** | pitch 1.25 → 25 格应读 22.7% ｜🔴 阻断 | 🔴 **整条作废**：无 `begin/end`；且该问题在 EXPONENTIAL 下不存在（摆幅仅 3.1pp） |
| 6 | **A-4** | `fog_disabled` 生效 ｜🔴 阻断 | ✅ **保留，并升级为「唯一必须实机验证项」**。补一句：🔴 **降级后它已无退路** —— EXPONENTIAL 下近场不再恒零（泉州昼焦点 17.5%），旧的"限制在近场绕过"失效。它押三处：泉州微光箭头 / Cape Cod 覆盖热力图 / **夜间光斑辉光** |
| 7 | **A-5** | 环绕抖动（V4） | 🔴 **整条作废** |
| 8 | **A-6** | 首次切 DEPTH 耗时（V3/R-ENG-09） | 🔴 **整条作废**。复活条件：将来任何人重新启用 DEPTH，必须回到这一条 |
| 9 | **A-7** | 先设 `fog_mode` 后设 `fog_density` ｜🔴 阻断 | ⭐ **改为「禁止任何 `fog_mode` 写入」**（一行都不写）。通过判据：① 全仓检索无 `fog_mode` 赋值；② `fog_density == profile.fog_density_for(state)`；③ §1.0.8 三条断言齐备。**⏱ 2 min，仍为阻断**。<br>🔴 **2026-09-24 追加（给严守真）：若要把这条压成"纯 grep"，必须先读 §13.3 —— 有四条漏网，其中第 1 条会让正确的写法被判失败。** |
| 10 | **A-8** | `48.0` 拆具名常量（R-ENG-11）｜🔴 阻断 | 🟡 **改号 R-ENG-13 + 降级为 ⚪ 记录/建议**（**不再是阻断**）：最坏后果已从"雾值全错且不可归因"变为"相机构图变化且立即可见"。建议做，不做也可接受 |
| 11 | **A-9** | `fog_height_density` 恒为 0 ｜🔴 阻断 | ✅ **保留且维持阻断**。补一句：**它在 EXPONENTIAL 下同样成立** —— `max()` 位于 `#ifdef USE_DEPTH_FOG` 分支**之外**，与模式无关（§7.1.1）。反向确认仍须 `fog_height=+100` 与 `fog_height_density=0.5` **一起**改（只改 density 画面不变 → 假阴性） |
| 12 | **B-1** | 昼态 O(8格) ≤5% ｜🔴 阻断 | 🔴 **整条作废**（判据已由用户撤销；且 EXPONENTIAL 下不可达） |
| 13 | **B-2** | 昼态 O(25格) ≤25% ｜🔴 阻断 | 🔴 **整条作废**。替换为 **B-1′：8 个 `fog_density` 与 `water-lighting-params.md` §5.1.1.1 逐位一致，且全部 ≤ 0.006**（回源，本文件不存数值） |
| 14 | **B-3** | 16 组 `x_begin` 全查 ｜🔴 阻断 | 🔴 **整条作废**（`x_begin` 不存在）。替换为 **B-2′：四态派生正确** —— 晨 / 昼 / 日落 三态 `fog_density` **必须全等**（均取 day 档），夜态取 night 档；⛔ 不得出现三个昼档值互不相等 |
| 15 | **B-4** | 泉州 昼23.0 / 晨61.9 / 落差≥2.0 ｜🔴 阻断 | 🔴 **整条作废** —— ⭐ **这三条正是用户撤销的那组判据**。替换为 **B-3′：地点切换密度不残留（R-ENG-15）** —— A→B→A 来回切，`fog_density` 须回到 A 的值 |
| 16 | **B-5** | 四地昼态梯度可辨 ｜🔴 阻断 | ⚠️ **必须改判据，否则会挂**：泉州 17.5% vs Cape Cod 15.9% **只差 1.6pp，肉眼读不出**（EXPONENTIAL 的结构限制，非缺陷）。改为：**四地「雾色 + 天色」的性格差异可辨**；并写明"两个中等浓度地点的 density 差 ≈2pp 属临界不可辨，**不得因此判阻断**"。辅助证据：塞舌尔 4.7% → 圣托里尼 6.9% → Cape Cod 15.9% → 泉州 17.5% 的纵向关系成立 |
| 17 | 阶段 B 触发条件 | 改了 begin/end/curve/density/四态划分后重跑 | 改了 `fog_density_day` / `fog_density_night` / `fog_floor_by_phase` 任一值后，重跑 B-1′ / B-2′ / B-3′ |
| 18 | **L436** M1 | 雾的生效性由 B-1/B-2/B-5 背书 | 雾的生效性由 **B-1′ / B-2′ / B-3′** 背书 |

### 12.3 ⭐ 给严守真的一条元规则（比逐条替换更重要）

> **验收单里的每一条判据，都必须能追溯到"谁提的需求"。**
>
> 这次的失效模式是：B-1 / B-2 / B-4 那三条判据**没有任何外部来源** —— 它们是工程推导过程中自设的中间目标，后来被写进了验收单，于是获得了"看起来权威"的地位，**并反过来否决了撤销它们的那个决定**。
>
> 📌 **此后验收单每加一条数值判据，必须同时写明**：① **来源**（用户 / 设计 / 美术 / **工程自设**）；② 回源文档的具体章节；③ 若是"工程自设"，**在判定阻断前必须回问一次**。
>
> ⭐ **这与 §1.0.2 那条方法论是同一个教训的两次发作**：同一组判据，**先在技术文档里逼出了换渲染模型**（DEPTH），**再在验收单里差点否决掉纠偏本身**（B-4）。
> 教训的完整形态应该是：**自设判据一旦落到任何带"通过/阻断"语义的文件里，就获得了超出其来源的权威。所以判据的"来源标注"必须跟判据一起走，不能只留在推导它的那份文档里。**

### 12.4 派工请求（我不自行改该文件）

`acceptance-checklist.md` 是 quality-lead（严守真）的文件，且它自己的头部写明"任何人都不要在本文件里改数字"。**我不越界改它**，改写件已按 §10 的模式做成可直接粘贴的形式（§12.2 共 18 条）。

**建议派工口径**：本次不是"改几个编号"，是**阶段 A/B 的雾验收体系要按 v1.2 重写一遍**。工作量估计 **0.25–0.5 人日**（改写件已备好，主要是核对与落笔）。🔴 **必须排在泉州接入之前** —— 否则第一次实机验收就会按错号查表、按已撤销的判据判阻断。

---

## 13. 补遗 v1.3 · 四项收尾（2026-09-24）

> 本节只处理 team-lead 交办的四个收尾项。**§1.0 的雾口径已在上一轮核对通过，本节不重新讨论。**
> 🔴 **排期数字：除 §11.4 明确授权的一处（core 新增条目 #17 = 0.25）外，一个字未动**；五个对外数（74 / 81 / 81–108 / 19–33 / 29）全部不变，推导已逐项列在 §11.4。

### 13.1 ✅ 运行时调参滑块 —— 实现规格（已批准 · **0.25 人日** · 可直接开工）

**定位**：见 §11.4。它是泉州 / Cape Cod 夜档 A/B 的执行载体（§1.0.10d），也是美术调 8 个值时的往返成本对冲。

**（a）功能清单（四条，缺一不可）**

| # | 项 | 规格 |
|---|---|---|
| 1 | 隐藏调试键 | `F` 开关面板；`[` / `]` 以 **0.0005** 步长微调 `fog_density` |
| 2 | 屏显当前值 | `ρ` 保留 5 位小数 + **当前档位名**（`day` / `night`）—— 因为晨态与日落态沿用昼档，美术必须知道自己在调哪一档 |
| 3 | 屏显两处遮蔽率 | **焦点（d = 48.00）** 与 **25 格（d = 68.80）**，按 `O = 1 − exp(−ρ·d)` 实算，百分比保留 1 位 |
| 4 | 🔴 gate | `OS.is_debug_build()` + release preset 的 export filter，**双保险** |

**（b）为什么必须钳到 `0.0060`**：§1.0.5 的实用区间上沿；八个已交付值全部 ≤ 0.006（§1.0.10 结论 1）。**不钳住就会有人在浏览器里把雾拖到 0.05，然后报一个"我觉得挺好"的数回来** —— 那不是调参，是换模型。

**（c）代码（可直接落地）**

```gdscript
# scripts/debug/fog_debug_panel.gd   ⚠ 必须放在 scripts/debug/ 下（发布包可整目录排除）
extends Control

const RHO_MIN  := 0.0000
const RHO_MAX  := 0.0060     # §1.0.5 实用区间上沿（钳制理由见上）
const RHO_STEP := 0.0005
const D_FOCUS  := 48.00      # 焦点：与 pitch 无关（R²cos²p + R²sin²p = R²，见 §1.3 L928）
const D_25     := 68.80      # 25 格

var _env   : Environment
var _state : int = 0
var _lbl   : Label

func setup(env: Environment, state: int) -> void:
	_env   = env
	_state = state
	visible = false
	_lbl = Label.new()
	add_child(_lbl)
	_refresh()

func set_state(i: int) -> void:     # 由 _apply_daylight() 回调，见下
	_state = i
	if visible:
		_refresh()

func _unhandled_input(e: InputEvent) -> void:
	if not OS.is_debug_build():      # 🔴 双保险之一
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_BRACKETLEFT:  _nudge(-RHO_STEP)
			KEY_BRACKETRIGHT: _nudge(+RHO_STEP)
			KEY_F:            visible = not visible; _refresh()

func _nudge(d: float) -> void:
	# 🔴 只改 density，绝不碰 fog_mode —— 理由见 §1.0.6 陷阱 1（写一次就把 density 打回 1.0）
	_env.fog_density = clampf(_env.fog_density + d, RHO_MIN, RHO_MAX)
	_refresh()

func _refresh() -> void:
	var rho := _env.fog_density
	var o_f := 1.0 - exp(-rho * D_FOCUS)
	var o_25 := 1.0 - exp(-rho * D_25)
	_lbl.text = "档=%s  ρ=%.5f\n焦点(48.0)=%.1f%%   25格(68.80)=%.1f%%" % [
		("night" if _state == 3 else "day"), rho, o_f * 100.0, o_25 * 100.0
	]
	print("[fog-debug] ", _lbl.text.replace("\n", " | "))   # 便于美术直接抄数
```

```gdscript
# scripts/build_world.gd :: _ready() 末尾（挂接点）
if OS.is_debug_build():
	# 🔴 用 load() 而不是 preload()：preload 在脚本编译期解析路径，
	#    一旦该文件被 release preset 排除，发布包会在加载时直接报错。
	var sc := load("res://scripts/debug/fog_debug_panel.gd")
	if sc:
		var layer := CanvasLayer.new()
		add_child(layer)
		var panel := sc.new()
		layer.add_child(panel)
		panel.setup(environment, state_idx)
		_fog_panel = panel
```

```gdscript
# scripts/build_world.gd :: _apply_daylight(state_idx) 末尾（保持档位同步）
if _fog_panel:                     # release build 里恒为 null，无需再 gate
	_fog_panel.set_state(state_idx)
```

**（d）🔴 发布包门控 —— 两道都要做**

| 道 | 手段 | 防的是 |
|---|---|---|
| 1 | `OS.is_debug_build()` | 面板**不存在、不响应输入**（功能级：付费产品里不会出现调试 UI） |
| 2 | release preset → Resources → **Filters to exclude**: `scripts/debug/*` | 文件**字节级不进包** |

- ⚠️ **只做第 1 道不够**：GDScript 源码仍会被打进 Web 包，白送一份实现给逆向者。第 2 道把整目录排除掉。
- ⚠️ **必须建两条 export preset**：Debug（**不**排除）/ Release（排除）。只有一条 preset 的话，要么调试包缺文件、要么发布包多文件。
- ⚠️ **排除后 `load()` 返回 null** → 上面那段已用 `if sc:` 兜住，且整段在 `OS.is_debug_build()` 内，发布包里永不执行。
- 🟢 **成本不变（仍 0.25 人日）**：第 2 道就是多勾一行 filter，加两条 preset 约 5 分钟。

**（e）为什么它零风险（写给将来想砍它的人）**

`fog_density` 是 `scene_data` 里的**运行时 UBO uniform**，改值即时生效、**不触发 shader 变体重编译** —— 与 `fog_mode`（编译期 `USE_DEPTH_FOG` define，见 R-ENG-09）完全相反。**这是它值得做的技术前提**：如果调参要重编译，这个滑块就不成立。

### 13.2 ✅ R-ENG 编号冲突 —— 已裁决，以本文件为准

见 **§7.1 表头约定**（已写入硬约定）。要点复述：

- **R-ENG-11** = 运行时改 `MultiMesh.instance_count` 触发 GPU 缓冲重分配（**与雾无关**）
- **R-ENG-13** = `48.0` 被「相机轨道半径」与「zoom 上限」共用
- 裁决理由沿用既有原则：**已登记的号不再改号，新风险取新号。**
- `acceptance-checklist.md` 侧由严守真改（替换件见 §12.2 #3 / #10），**我不越界**。

⭐ **今后对外引用 R-ENG 一律写「编号 + 语义标题」**；只写编号的引用视为无效引用。这是同一混淆的第二次发作（连主理人任务书都记错过一次），所以升格为硬约定。

### 13.3 ⚠️ A-7 改成"纯 grep" —— 🔴 **有漏网，四条。不要压成纯 grep。**

**结论**：改成 grep **方向对**（原判据会挂掉正确写法，这一点严守真的判断是对的），但**纯 grep 有四条漏网**，其中第 1 条会让**正确的实现被判失败**、第 2 条会**丢掉真正能拦住故障的那部分**。

| # | 漏网 | 严重性 | 说明 / 处置 |
|---|---|---|---|
| **1** | 🔴 **读 / 写不分 → 正确实现被判失败** | **最高** | §1.0.8 **强制要求**的第三条断言就是 `assert(environment.fog_mode == Environment.FOG_MODE_EXPONENTIAL)`；§1.0.6 / §1.3.3 / §7.1 的说明文字里也满是 `fog_mode`。**grep 必然命中。** 判据必须写成「无**写入**」，并把这两种命中**显式列进白名单**。 |
| **2** | 🔴 **原判据三条被压成一条** | 高 | §12.2 #9 的通过判据是 ①②③。纯 grep 只等价于 ①，**② `fog_density == profile.fog_density_for(state)` 与 ③ 三条断言齐备会被丢掉**。② 拦的是"density 被别处覆盖"，③ 拦的是"断言被删掉" —— **grep 一条都拦不住**。 |
| **3** | 🔴 **`.tres` / `.tscn` 里的 `fog_mode` 不是静态配置，是运行时写入** | 高 | 资源加载走 `set()` → `set_fog_mode()`。按 §1.0.6 陷阱 1 的精确源码，**值 = 0（EXPONENTIAL）同样致命**（走 else 分支 → `fog_density = 1.0`）。→ ⚠️ **"grep 到了但值是默认的，放行"这条宽松解读是错的**：只要出现 `fog_mode` 属性行，一律阻断。 |
| **4** | 🟡 **检索覆盖面没写死会漏** | 中 | 必须覆盖 `.gd` / `.tscn` / `.tres` / **`project.godot`** / `addons/`；二进制 `.res` `.scn` 需 `rg -a`（否则默认被跳过）。另：🚨 **C# 里属性名是 `FogMode`（PascalCase）**，`fog_mode` 检索**会全漏** —— 本项目 Godot 4.4 **Web 导出不支持 C#**，故当前不适用，但要写进控制清单：**一旦引入 C# 或 GDExtension，A-7 必须增加 `FogMode` 模式**。 |

**建议的最终 A-7 判据（≈3 min，仍为阻断，可直接粘贴给严守真）**

```bash
# ① 全仓检索（含资源文件与 project.godot；-a 让二进制 .res/.scn 也进文本检索）
rg -n -i -a --hidden -g '!.git' 'fog_mode|FOG_MODE' .
```

- **白名单（命中也放行，仅此两种）**：
  ① `assert(... fog_mode == Environment.FOG_MODE_EXPONENTIAL)` —— `_apply_daylight()` 内的**读**，§1.0.8 强制要求；
  ② 技术文档 / 代码注释里的说明文字。
- **命中即阻断（四种形态）**：`env.fog_mode = ...`｜`env.set_fog_mode(...)`｜`env.set("fog_mode", ...)`｜`.tres` / `.tscn` 里的 `fog_mode = ...`（**无论值是不是 0**）。
- **②** `_apply_daylight()` 内三条断言齐备（`grep -c assert`，1 min）。
- **③** 运行时 `fog_density == profile.fog_density_for(state)` —— 由 §1.0.9 第 5 项（A→B→A 来回切）或既有 `tests/test_fog_floor.gd` 覆盖，**不需要单独排场次**。

> ⭐ **为什么值得多花这 1 分钟**：`fog_density = 1.0` 的后果是画面 100% 糊成 `fog_light_color`，**而它只要不写 `fog_mode` 就永不发生** —— 这正是一条"必须任何形式都拦"的硬门，不是"大概没有"的软检查。
> 🔴 **这次的失效模式与 B-4 是同一类**：**判据一旦被简化，被简化掉的那部分恰好是唯一能拦住真实故障的部分。**（对照 §12.3 元规则。）

### 13.4 ✅ `ambient_light_color` / `AMBIENT_SOURCE_COLOR` —— **支持**，且本项目现在就在用

> 答复美术侧的圣托里尼日落五手段第 ③ 条（金 × 蓝补色对）。

**✅ 结论：Compatibility（GL / GLES3）下支持，零新增工程量。** 而且它不是"将来要做"，**现有导出产物里已经在用** —— 见 §1.2 从字节码还原的原文（L51–53 / L81–82）：

```gdscript
environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
environment.ambient_light_color  = Color("7395ad") if night else Color("dceae0")
environment.ambient_light_energy = 0.25 if night else 0.3
```

**（a）属性名与设置路径（Godot 4.4 源码核对）**

| 你要的 | 属性名 | setter | 类默认 | 备注 |
|---|---|---|---|---|
| 环境光来源 | `ambient_light_source` | `set_ambient_source` | 🚨 **`AMBIENT_SOURCE_BG`**（枚举 0 = Background） | 枚举提示 `"Background,Disabled,Color,Sky"`；**`AMBIENT_SOURCE_COLOR` = 2** |
| 环境光颜色 | `ambient_light_color` | `set_ambient_light_color` | `Color(1,1,1)` | 🔴 只在 source == COLOR 时生效 |
| 环境光强度 | `ambient_light_energy` | `set_ambient_light_energy` | `1.0`（范围 `0–16`, step `0.01`） | 与 `light_energy` 的比值决定"硬/柔"（`water-lighting-params.md` §2 顺位 2） |

```gdscript
# _build_environment() 里设一次（source 全程不变，见下条约束 2）
environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
# _apply_daylight(state_idx) 内 —— 与 fog_density 同一个唯一写入点
environment.ambient_light_color  = profile.ambient_color_for(state_idx)
environment.ambient_light_energy = profile.ambient_energy_for(state_idx)
```

**（b）Compatibility 下确实生效 —— 源码证据**

`drivers/gles3/shaders/scene.glsl`（Compatibility 唯一走的 scene 着色器）：

```glsl
#ifndef AMBIENT_LIGHT_DISABLED
	if (scene_data.use_ambient_light) {
		ambient_light = scene_data.ambient_light_color_energy.rgb;
		...
	}
	ambient_light *= albedo.rgb;
	ambient_light *= ao;
#endif
...
frag_color.rgb += emission + ambient_light;
```

`ambient_light_color_energy` / `use_ambient_light` 都是 `scene_data` UBO（`ubo:2`）里的**运行时 uniform**，**不是编译期 define**。

**（c）四条执行约束（给美术与工程）**

1. 🔴 **必须显式设 `AMBIENT_SOURCE_COLOR`，且全程不变。** 类默认是 `AMBIENT_SOURCE_BG`（**拿背景色当环境光**）。本项目现有代码已显式设 COLOR，**参数化时别把那行漏掉** —— 一旦退回 BG，`ambient_light_color` 写了**完全不生效、不报错**，日落态会变成"背景色是什么色，背光面就是什么色"（背景色恰好是暖橙 → 金×蓝直接消失，且无法归因）。
2. 🟢 **只改 `color` / `energy` 是零风险的**：两者都是 UBO uniform，改值即时生效、**不触发 shader 变体重编译**，**可以被 core #6 的同一个 Tween 插值**（与"雾跟随同一 Tween、不单独插值"是同一条原则，§1.0.10b）。
   ⚠️ **但禁止在四态之间切 `ambient_light_source`**：COLOR ↔ SKY 会切换 `use_ambient_cubemap` / 是否采样 radiance cubemap，而 `USE_RADIANCE_MAP` 是 **specialization（编译期）**。**source 锁死 COLOR，一行都不切** —— 与 `fog_mode` 完全同一个原则：**不调用即无风险**。
3. ⭐ **"背光面冷蓝紫"机制成立，但要理解它不是方向性的。** `ambient_light = color.rgb`，**与法线无关，是 flat 的**。金×蓝之所以成立，是因为**受光面被 `sun.light_color`（暖橙）主导、背光面只剩 ambient（冷蓝紫）** —— 是"谁占主导"的结果，不是"只作用于背光面"。
   - 推论：`ambient_light_energy` **越低，背光面越纯冷色，但整体越暗**；**越高越洗白、越抹平硬阴影**。圣托里尼 `ambient ÷ light = 0.27`（四地里最硬，见 `water-lighting-params.md` §2），**日落态调 ambient 颜色时不要顺手抬 energy**，否则会亲手抹掉这个 0.27。
4. 🔴 **想要更强的"只有背光面冷" → 用有向补光，不要用 flat ambient。** 补一盏**无阴影** `DirectionalLight3D`，从日落的**反方向**打冷蓝紫、低能量 —— 它只作用于朝向它的面，**正是背光面**，且**不抬受光面、不压对比**。
   - 本项目已有先例：塞舌尔方案 A 的 **0.30 无阴影补光**（§3.3），机制与代码路径现成。
   - ⚠️ 与 MH-ENG-002a 的分工：`真实点光源归零` 指的是 **omni / spot**，**`DirectionalLight3D` 不占 `max_lights_per_object`（见控制清单第 1 条），改造后这条路依然可用**。

**（d）两条配套（防止日落调完被别的东西吃掉）**

- 🔴 调色前把 **`fog_sun_scatter` 置零**（§1.0.6 陷阱 3：它会改 `fog_color`，而日落态是唯一可能想开它的态）；
- 🔴 **先锁 `tonemap_exposure = 1.0` 再调色，最后才动曝光**（§1.5 改动 3）—— 否则暖端与冷端被同一条曲线一起抬，金×蓝会被压平。

**（e）人日**

| 路线 | 人日 | 归属 |
|---|---|---|
| 只改 `ambient_light_color` / `energy`（四态 keyframe 加一个颜色字段） | **0**（已含在 core #3 参数化内） | core |
| 追加一盏无阴影冷色补光（填值 + 一个 keyframe 字段） | **0.05–0.1** | 地点美术/内容，**不进 core** |

🟢 **两条路线都不改变 §9 / §11 的任何排期数字。**

### 13.5 ⭐ v4.1 日落色值的工程侧核对（2026-09-24 · 应 art-fog-cleanup 交叉核对）

> 源：`water-lighting-params.md` §6.2（四地日落补偿色值，**唯一源**）+ §7（`LocationProfile` 骨架 v4.1）。
> 🔴 **本节只记录工程侧核对结论与新增的门。数值我不拍、不改他文件 —— 8 个雾值与日落色值的唯一源仍在美术文档。**

**（a）两个删字段 —— ✅ 工程侧背书，且理由比美术给的更强**

| 字段 | 美术理由 | ⭐ 工程侧补强 |
|---|---|---|
| `reflection_strength` | unshaded 不参与光照反射；且 `BG_COLOR` 无天空可反射 | 🔴 **`MODE_UNSHADED` 分支在 gles3 `scene.glsl` 里是 `frag_color = vec4(albedo, alpha);` 然后直接结束**（§2.1 已引源码）—— **unshaded 连 ambient 与 specular 都不进**。所以反射在 unshaded 水下是**着色器层面不可能**，不是"暂时没实现"。<br>⚠️ 因此美术担心的"v1.1 上 T2 天空时会复活"**低估了**：问题不在有没有天空，在于水的 `render_mode`。**只要水还是 unshaded，上什么天空都不可能反射**；真要做只有 fake Fresnel 一条路（+0.5 人日，§1.2 落差 3，**v1 不做**）。 |
| `sunset_fog_color` | 日落沿用昼档雾色，不存在"日落雾色" | ✅ 与 §1.0.8「存 2 个标量而不是 4 态数组」**完全同构**：多一个日落雾色字段，下一步必然有人问"那日落 density 呢"，2 标量结构当场崩。<br>📌 **给后人的预案（不是现在就改）**：若实机确认"发灰"救不回来，**正确动作是派生，不是新增色值字段** —— 例如 `mix(day_sky_horizon, sunset_sky_horizon, k)`，`k` 是**一个标量**进 `LocationProfile`。它派生、单源、不诱导人工填 4 个色值，因此**不违反"日落没有专属雾值"**。<br>⛔ 但美术给的第一动作（圣托里尼降 `sky_horizon` 的 L 往 `#FF6E30`）**优先于这条**，我的预案只排第二。 |

**（b）日落态的 `ambient ÷ light` 比值 —— ✅ 已结案（含我一次核算错误的更正记录）**

🔴 **先记我的错（2026-09-24，防止后人重犯）**：本节初版我算的是「日落 ambient **沿用昼档**」，得出 +36%/+18%/+27%/**+71%**。**算法与昼档取值逐位正确，但前提错了** —— `water-lighting-params.md` §6 表**早有「环境光（日落）」一行**（现值 0.40 / 0.28 / 0.34 / 0.30），我检索时漏掉了它。
- **漏检的技术原因**：该行中文行名写作「环境光（日落）」，**表格单元格里不含 `ambient` 字样**；我用的检索式是 `ambient.*日落` / `日落.*ambient`，两个都要求同一行内同时出现中英文，**一行都不命中**。
  > 🔴 **全局检索纪律（2026-09-24 立，工程侧与美术侧通用）**
  > **数值表用中文行名，代码字段用英文属性名 —— 检索时要按目标切换，不能只用一个。**
  > | 你要找什么 | 该搜什么 | ⛔ 不要只搜 |
  > |---|---|---|
  > | 某个参数的**值** | 中文行名：`环境光` / `太阳色` / `雾色` / `天空地平线` / `环境光（日落）` | `ambient` / `sun_color` / `fog_light_color` |
  > | 某个**字段 / 属性名** | 英文属性名：`sunset_ambient` / `fog_density_day` | 中文名 |
  > 反例已发生一次：查 `sunset_ambient` 的值只搜英文 → 零命中 → 误判"该值不存在" → 按错误前提算出 +71%。**正解是搜「环境光」。**
  >
  > 🔴 **第二条：认列不认数**（美术侧 2026-09-24 提炼，工程侧镜像采纳）。**单看数字无法判断它是不是现行值 —— 必须看它在哪一行、哪一列。**
  > - **本文件的实例**：L1069「圣托里尼 **0.0050**」是 §1.4 **沿革**里「可用昼态 ρ **上限**」列（按已撤销判据反解），**不是现行取值**；现行昼档是 0.0015（见 §1.0.10 / 美术 §5.1.1.1）。同一个数在两个语义里差 3.3 倍。
  > - **美术文件的同款实例**：`water-lighting-params.md` §5.1.1 沿革段「四地四态最终数值」表里，Cape Cod 日落态 DEPTH `density` 也是 **0.26**，与 `sunset_ambient` 的 0.26 **语义完全无关**。
  > - 📌 **操作化**：搜到数字后，**回看它所在的行名与列名再决定能不能用**。
  >
  > ⭐ **为什么是"默认不可引用"而不是"请谨慎判断"**（2026-09-24 定）：**"谨慎判断"是软约束 —— 它把判断成本留给读者，而读者恰恰是那个不知道自己需要判断的人。**
  > → 🔴 **沿革段与"上限 / 边界"列里的数一律默认不可引用；要引用，必须主动举证它确实是现行值。**
  > 🔴 **这条纪律真正要记住的是它反直觉**：这类坑**不报错，而且被搜到时显得特别可信**（"文档里明明写着"）。**所以它比"搜不到"更危险 —— 搜不到至少会让人去问，搜到错的会让人直接照做。**
  > 📌 这两条已由美术侧同步提炼进 `water-lighting-params.md` §6.2.1，**两侧口径一致**。
- 🟢 **归因是双方各一半**（美术已确认）：我漏查 §6 表；他那边 §7 骨架的 `sunset_ambient` 字段**当时没有任何指向值所在行的注释**，所以"从 §7 看过去像没有值"。**工程侧是照抄骨架的，不是通读文档的** —— 这个失效模式对工程侧有直接后果，已由他在 §7 补上注释（⛔ 不得填昼档 + 填错会 +71% 且静默）。

**按现值重算**（判据仍是美术自己的：`ambient ÷ light` 才是硬/柔的来源，比值越小越硬）：

| 地点 | 昼档 ambient/light | **昼档比值** | 日落 ambient/light（**现值**） | **日落比值** | 变化 |
|---|---|---|---|---|---|
| 泉州 | 0.48 / 0.95 | 0.505 | 0.40 / 0.70 | **0.571** | +13% |
| 圣托里尼 | 0.35 / 1.30 | **0.269**（最硬） | 0.28 / 1.10 | **0.255** | 🟢 **−5%**（比昼档还硬） |
| Cape Cod | 0.45 / 0.95 | 0.474 | 0.34 / 0.75 | **0.453** | −4% |
| 塞舌尔 | 0.40 / 1.45 | **0.276**（次硬） | ~~0.30~~ / 0.85 | ~~0.353~~ → 🔴 **0.306** | ~~+28%~~ → **+11%** |

**⭐ 美术拍板（2026-09-24，`water-lighting-params.md` §6.2.1）**：只改塞舌尔一个 —— `sunset_ambient` = 泉州 **0.40**｜圣托里尼 **0.28**｜Cape Cod **0.34**｜塞舌尔 **0.26**（由 0.30 下调）。⛔ **一律不得填昼档值。**
- ✅ **我背书这个裁决**，两条理由：① 另外三地的现值本来就是按日落调的（圣托里尼 −5% 甚至比昼档更硬，正是 Oia 要的），**动它们才是破坏**；② 塞舌尔是唯一**显著偏离自身性格**的（0.353 已滑向泉州昼档 0.505 那一侧）。
- 🟢 **0.26 优于我原给的 0.23**：0.23 是"完全保住昼档比值"，会把日落做成赤道正午 —— **日落本来就该比昼档柔一点**（掠射下天光占比上升，这是物理）。0.26 → +11%，柔化可控，且 0.306 仍显著低于 Cape Cod 昼档 0.474，**仍读作"硬"**。

**（b2）🔴 抗灰机制的一处精确化（美术"第三重抗灰手段"的提法需要修正半句）**

美术主张：压 `ambient` = 压暗部 = 抬对比，"**顺手把雾抬起来的那部分压回去**"。**前半对，后半不成立**：

```
最终色 = mix(shaded, fog_color, O) = shaded·(1−O) + fog_color·O
  亮部 = [(light·NdotL + ambient)·albedo]·(1−O) + fog_color·O
  暗部 = [ambient·albedo]·(1−O)            + fog_color·O
  ────────────────────────────────────────────────────────
  绝对差 = light·NdotL·albedo·(1−O)         ← ⛔ 与 ambient 完全无关
```

- ✅ **压暗部**：成立。
- ✅ **抬对比**：**只有比值（相对对比）抬，绝对差不变** —— 因为 ambient 是 flat 的，它同时抬亮部与暗部，差值被抵消掉。
- ❌ **"把雾抬起来的那部分压回去"**：**压不回去**。`fog_color·O` 这一项与 ambient 无关，是常量。压低 ambient 后暗部自身更黑，反而使**雾在暗部中的占比上升**（0.040/0.183 → 0.040/0.164）。
- 🟢 **但他的结论方向是对的**：`light_energy`（§6.2 钉死）、`O`（雾降级拍板钉死）、`fog_color`（不改雾色）**三个能抬绝对对比的旋钮全被钉死了**，所以 **ambient 确实是剩下唯一还能动的对比度旋钮** —— 只是它动的是**相对对比**。

→ 📌 **给验收的精确判据**：抗灰**不要看"暗部黑不黑"**（那只是 ambient 的直接效果，会误导成"越黑越抗灰"），要看**亮部 ÷ 暗部的比值**。并且要写明：**绝对对比差已被三个钉死的边界封住，本轮只能调相对对比。**

**（b3）⚠️ 一个美术未计的副作用：压 ambient 会削弱"背光面冷蓝紫"**

ambient 是**背光面唯一的着色来源**。而 §13.4 已确认「金 × 蓝」补色对的实现路径正是 `ambient_light_color` 冷蓝紫：
- 背光面色 ≈ `ambient_color × ambient_energy × albedo` → **energy 从 0.30 降到 0.26（−13%），背光面的冷蓝紫同比变暗**。
- 🔴 风险：背光面可能读成"**死黑**"而不是"**冷蓝紫的暗部**" —— 那金 × 蓝就只剩金，补色对塌掉一半。
- 📌 **判据（日落接入当天，每地 30 秒）**：背光面**必须仍能辨出冷色相**（不是纯黑剪影），且能辨出**轮廓**（不是死黑丢形状）。
  ⚠️ **适用于两个地点，不只是塞舌尔** —— 🟢 **圣托里尼更要紧**：它的招牌是"白墙金光 × 深蓝紫阴影"，**金与蓝两个都在**，背光面色相塌了直接砸招牌；塞舌尔是单侧。
- 🟢 **若不成立，正确动作是抬 `ambient_light_color` 的饱和度而不是抬 `ambient_light_energy`** —— 色相靠 color 承担，能量是对比度旋钮，两者不要混用（与 §13.4 约束 3 同源）。
  - ⭐ **原理**：**色相辨识度靠的是通道之间的比例，不是绝对亮度** —— 抬饱和度能让暗部"更明显是冷色"，同时不抬能量 = 不把刚做的对比修正抹掉。
  - ⛔ **抬 `ambient_light_energy` 会把塞舌尔 0.26 退回 0.30，本轮对比修正全部作废。**
  - 📌 通用纪律：**色相归 `color`，对比归 `energy`，两个旋钮不要混用。**

**（c）措辞澄清（防止验收员拿错基准）**

§6.2 写「日落**不变暗只变色**」，但**四地日落 `light_energy` 实际全部低于昼档**：泉州 −26%｜圣托里尼 −15%｜Cape Cod −21%｜塞舌尔 −41%。
→ 该措辞的正确读法是 **⛔ 禁止再往下调**（L1354 的语境是"加能量只会推向过曝"），**不是"日落亮度应与昼档持平"**。
🔴 **若验收单里出现"日落亮度 ≥ 昼档亮度"这类判据，实测必挂，而挂的是措辞歧义不是实现。**（对照 §12.3 元规则：判据必须标来源；这条要标"美术设定值"，基准是**§6.2 钉死值**而非昼档。）

**（d）过曝的真正上边界是昼档塞舌尔 1.45，不是任何日落值**

`tonemap_mode = TONE_MAPPER_LINEAR` + 锁 `tonemap_exposure = 1.0`（§1.2 L54 / §1.5 改动 3）→ **无高光滚降**，超过 1.0 就是硬 clamp，表现为**色相丢失的死白**而不是柔和过曝。
四地 `light_energy` 峰值 = **塞舌尔昼档 1.45**（日落值最高才 1.10）。
→ 📌 接入当天**塞舌尔昼档**看一眼最亮受光面有无死白（30 秒）。**日落四地都不需要过曝检查**（1.10 < 1.30）。

**（e）🔴 新增的门 · T1 天空盒必须有「四态色值通道」**

§6.2 给的日落 `sky_horizon` 要生效，前提是天空盒能被**四态驱动**；而 `sky_top_color` / `sky_horizon_color` **当前一个都不存在**（§1.2 落差 1），属 core #11（T1 顶点渐变天空盒，0.5 人日）的净新建。
- 🔴 **风险**：core #11 若按最小实现做成「**地点级两个 uniform**」（每地点一套、全天不变），§6.2 的四地日落 `sky_horizon` **一个都填不进去**，且要到日落接入当天才暴露。
- 🟢 **增量成本 ≈ 0**：T1 的色值本来就是 shader uniform，四态切换只是多写一次，**与 `fog_density` 完全同理**。
- 📌 **验收门（写进 core #11）**：`sky_top` / `sky_horizon` 必须能被 `_apply_daylight(state_idx)` 逐态写入；**日落态读 `sunset_sky_top` / `sunset_sky_horizon`**。判据：切到日落态，天色**必须变**（只按地点不变态 = 不通过）。

**（f）⚠️ `fog_light_color` 派生源的写法（这里最容易写错）**

派生规则（美术 §5.1.1 v4.1）：**晨 / 昼 / 日落三态的 `fog_light_color` 一律取自昼档字段 `sky_horizon_color`**，日落态**不得**取 `sunset_sky_horizon`（那是 §6.2 的补偿暖橙，拿它当雾色会把整个日落染成一片橙）。夜态取 `fog_floor_by_phase`。

```gdscript
# ⛔ 会写错的形态：遍历四态取"对应态"的地平线色 → 日落态会取到 sunset_sky_horizon
# ✅ 正解：三态硬指向昼档字段（与 fog_density_for() 同构，查表不用 if/else）
const FOG_SKY_SOURCE := [0, 0, 0, 3]   # [晨, 昼, 日落, 夜] → 0 = 昼档 sky_horizon_color；3 = 夜态下限

func fog_light_color_for(state_idx: int) -> Color:
	var base := profile.sky_horizon_color                       # ⛔ 不是 sunset_sky_horizon
	var floor_c := profile.fog_floor_by_phase[state_idx]
	return base if floor_c.a == 0.0 else base.max(floor_c)      # §5.1.1: max(派生, 夜态下限)
```

> 🔴 **为什么必须写成查表 + 注释**：这是 §1.0.8「存 2 个标量从结构上消灭错误」的同型问题 —— **"日落态"这个名字会诱导实现者去取 `sunset_*` 字段**。写成常量表，后人一眼看到三个 0，就写不错。

**（g）人日：0。** 以上全部是"写对"与"别写错"，不含新增能力；（e）的门落在 core #11 既有范围内。🟢 **不改变 §9 / §11 的任何排期数字。**
