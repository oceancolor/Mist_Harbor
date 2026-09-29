# 控制清单 · Control Manifest（防复发）

> 用途：把几条**错了会静默失效**的引擎约束固化成清单。改相关代码前先读这里。
> 来源：`Dev Driven/tech-feasibility.md` v1.3 · `Dev Driven/godot-web-perf.md` v1.1 · `Dev Driven/water-lighting-params.md` v4.3。

## 1. 禁止真实点光源 / 聚光源

- 本作**禁止** `OmniLight3D` 与 `SpotLight3D`。一切光表现走 **emission + 共享光斑贴片**（`scripts/core/light_patches.gd`）。
- 理由：Compatibility 下 `max_lights_per_object` 为 8 盏，而地形是全岛合并的单 `ArrayMesh` → 8 盏由**全岛共享**；第 9 盏起不渲染，相机移动还会 pop 闪烁。原 `build_world.gd::_add_prop()` 的 OmniLight3D 已按 `MH-ENG-002a` 删除。
- 新增需求提出「加一盏真实灯」→ **一律回退**到 emission + 贴片路线。

## 2. `max_lights_per_object` 默认不动、禁止调高

- 保持引擎默认 8。调高会把首次 shader 编译从秒级推到十几秒，并把丢光 / pop / 重编译三件事一起带回。

## 3. 雾三禁

| 禁 | 说明 |
|---|---|
| ⛔ 写 `fog_mode` | 任何写入（包括"显式设成默认值"）都会走引擎 else 分支把 `fog_density` 静默改成 **1.0**，画面全糊 |
| ⛔ `fog_height_density` 非 0 | `max()` 在 `#ifdef USE_DEPTH_FOG` 之外，指数雾同样会被盖掉，不报错 |
| ⛔ 四态各调一套雾 | 雾只有**昼档 / 夜档**两个标量（+Cape Cod 天气轴第三常量），晨与日落沿用昼档 |

## 4. A-1 材质族三件套：`unshaded` + `fog_disabled` + `blend_mix`

- `unshaded` **不等于**不被雾吃掉；绕雾的是 `fog_disabled` token。
- 混合模式统一 `blend_mix`：密排时 `blend_add` 会 clip 成纯白（泉州灯火与 Cape Cod 光锥都会密排）。
- 服务对象：光斑贴片 · 微光箭头引导 · 光锥 · 覆盖热力图 · 天空盒。

## 5. 昼夜硬等价

- 四地昼夜只有 `_apply_daylight()` / `HarborDaylight.apply_phase()` **一条分支**。任何地点不得另写昼夜插值。
- 天气（Cape Cod 海雾）是**正交 toggle**，不占「晨 / 昼 / 日落 / 夜」状态机位。
- 雾跟随昼夜同一个 Tween，不单独插值（`fog_transition_sec` 已删除）。

## 6. 世界重建

- 昼夜切换**不得**触发 `needs_rebuild`（原 `set_night()` 末行已删除，那会让每次按 N 重建上万个方块）。
- 光斑贴片运行时**只改** `visible_instance_count` 与实例颜色，不改 `instance_count`。
- 灯光节点只建一次，禁止 `add_child / remove_child` 灯光（会引发 shader 重编译）。

## 7. 相机常量

- `CAM_ORBIT_RADIUS = 48.0` 与 `CAM_ZOOM_MAX = 48.0` 必须是**两个具名常量**（`R-ENG-13`：二者曾共用常量池同一条目，改 zoom 上限会静默改掉轨道半径）。

## 8. 死字段（不要复活）

- `reflection_strength`（水是 unshaded，着色器层面不可能反射）
- `sunset_fog_color`（日落沿用昼档雾色）
- `fog_depth_begin / fog_depth_end / fog_depth_curve`
- `fog_density_by_phase`、`fog_transition_sec`
- `fog_aerial_perspective`（Compatibility 下整块被注释掉，调了没反应）

## 9. 构建与颜色四条新增纪律（2026-09-26 验收事故沉淀）

| 编号 | 纪律 | 事故后果 |
|---|---|---|
| **R-ENG-16** | 禁止用 `String.is_valid_hex_number(true)` 校验裸十六进制——`with_prefix=true` 要求 `0x` 前缀，`"9CB4BE"` 会被判非法并**静默回落白色**。颜色解析统一走 `Color.from_string`（`location_profile.gd::hex`） | 全部环境色变白 → 整屏过曝 + 海面隐身 |
| **R-ENG-17** | 线性色调映射（`TONE_MAPPER_LINEAR`）下**必须无削顶**：`max_albedo × (sun_energy×sun_max + ambient×ambient_max) × exposure ≤ 1.0`。测试 `test_world.gd` 已对 4 地点 × 4 态全量断言 | 白沙/白墙直接削成纯白，丧失明暗与色相 |
| **R-ENG-18** | `.godot/exported/` 的脚本编译缓存**不随 .gd 修改失效**；`dev.py` 在导出前强制删除它。**导出后必须核对产物内容/时间戳，不得只看命令退出码** | 连续多次"导出成功"实际打包旧脚本，观感时灵时不灵 |
| **R-ENG-19** | **自定义 shader 输出 ALPHA（透明管线）在 Web 导出（4.7.0/WebGL2/Compatibility）里静默不渲染**，无报错。水体已改不透明（三段色带/泡沫/顶点浪保留）；光斑贴片与光锥改走 `StandardMaterial3D` + `GradientTexture2D`。待 4.7.2 模板就绪后桌面端复测再恢复透明 | 海面（半透明水体）、夜态光斑、光锥全部隐身，且无任何 console 报错 |

## 10. 海面与天空的设计依据（2026-09-26 三轮验收沉淀）

> 🔴 **2026-09-27 起以 `docs/optimization-spec-2026-09-27.md` 为渲染/资产/色彩的最高验收依据**（用户五条要求：
> 摄像机到地平线 / 无限海不穿帮 / Sky shader 日月星+菲涅尔 / Tripo 商业级链路 / 哈萨姆色彩矫正）。
> 下列条目中被标注「部分取代」的，按规格文档执行。

| 编号 | 决策 | 依据 |
|---|---|---|
| **R-ENG-20** | **波纹 = 破波带行波模型**，不是等距条纹。深水：长波涌浪明暗起伏 + 双涌浪相乘的稀疏 whitecap 尖点（初代 `lines = smoothstep(0.97,1,w*w2)*0.11` 的回归）；浅水：波高向破碎点增幅、破碎后回落；破碎线深度随岸形噪声蜿蜒、白线沿岸断裂不连续；最靠岸一圈是 swash 泡沫残留。全部只在 `shore_d < breaker_dist` 邻域渲染，深海无白线 | 物理观察（用户四条）+ 初代参照。四地参数化：圣托里尼 0.07（地中海平静）/ 泉州 0.55 / CC 0.9（浪更大） |
| **R-ENG-21** | **岸线距离场**是水体与地形共用的唯一岸线数据源（R8 贴图喂 shader + `ring` 字典喂网格器）。水深色带按离岸距离混合（多岛各有浅水环，弃用中心距离）；滩涂压低逐环插值 | 中心距离在多岛地形下必然错误 |
| **R-ENG-22** | **相机俯仰下限与缩放联动，必须允许接近海平面**（🔴 用户 2026-09-26 明确要求，勿改回保守值）。公式：`p ≥ atan2(zoom/2, R) + asin((−4 − focus.y)/√(R²+(zoom/2)²))`——允许下缘光线入水 4 格（`WATER_TOLERANCE`），低角度画面下缘由不透明水盒（R-ENG-23）与地形裙边（R-ENG-24）兜底。效果：zoom 10 → pitch 0°（海平线居中的海平面视角）；zoom 20 → ~6°；zoom 48 → ~21°。要贴海平面就滚轮拉近，拉远自动抬角。**（部分取代 → 规格文档 §1：zoom 48 → 17° 仍到不了侧视全景，须按 §2 无限海前提重写下限）** | 旧的"下缘必须在水面上方"约束（≥ −0.1）导致 zoom 10 时最低只能 4.6°，永远到不了海平面视角；入水兜底由水盒保证后该约束过于保守 |
| **R-ENG-23** | 水体是**有体积的水盒**（240×8×240，顶面 -0.23），不是平面；天空球**下半球渲染成无限远海面**（`far_sea_color` 渐变）。低角度掠视时两者共同兜底，海天线由此分明 | 低角度验收截图：平面水体挡不住水下视线，露天空球下半球成灰带 |
| **R-ENG-24** | 地形列侧面顶点向下延伸 **-6 裙边**（视觉层，不占格）：崖体/岛体低角度掠视时没入水与雾，不露底 | 同上 |
| **R-ENG-25** | 天空层贴图**只存形状**（R=云 G=远景剪影 B=夜星），颜色全部由四态 tint uniforms 提供——日落云染金、雾天剪影融雾，无需按时段出图 | 一张贴图服务 4 地点 × 4 态 |
| **R-ENG-26** | **日/月/星天体与海面光带**（2026-09-27 四轮实测定稿）。天体 = **海平线锚定的屏幕空间公告板**：正交投影里"无限远方向"没有唯一屏幕位置（物理穹顶 R≈195 时 2° 仰角太阳的偏移 17 单位 > 画面半高 10，dot 积盘永远出画），因此按美术映射：太阳纵向 = 地平线屏幕位置 + (仰角/6°)·(画面顶边−地平线)，横向 ±40° 方位角映射到画面边缘；`cam_pos/cam_axis/cam_half` 由 `_process` 每帧回写。**海面光带**：`reflect(cam_dir, up)·(-sun_dir)` 140 次幂 + vnoise 鳞光，日落金光大道 / 夜月光带（世界空间计算，与天体方向一致）。**四条血泪教训**：① `sky_tex` 必须在 `setup()` 里构建（曾只在 `set_profile`——首进场景走 setup → uniform 未绑定 → Compatibility 采样**默认白贴图** → 云/星全开 → 夜空整片饱和纯白）；② 月牙咬口圆半径必须 **小于** 其偏移（旧值 0.66-0.80R > 0.62R 偏移 → 月心被吞，整月只剩光晕）；③ 圣托里尼太阳方位**正西**（`sun_rotation_y=-90`）：南侧/北侧被月牙崖挡死（崖顶遮挡仰角 14°），唯正西是全开阔海；④ 天体核心体色+光晕叠加会**饱和成纯白**（R≈B），验收探针按"低饱和亮白块"检测而非冷色。（🔴 **方案整体被取代 → 规格文档 §3**：屏幕空间公告板是妥协，天体须迁 WorldEnvironment 自定义 Sky shader 按 `EYEDIR` 方向渲染，任意机位正确 + 海面菲涅尔；但 ① 的贴图构建时机、③ 的太阳方位约束仍然有效） | 单方向数据（太阳直射 forward）服务太阳/月亮/海面反光三层；任意 zoom/pitch 下太阳稳定贴在海平线上方 |
| **R-ENG-27** | **qa 机位参数**（`main.gd` `_ready`）：`location` / `pitch`（0-100→弧度，受俯仰下限约束）/ `yaw`（0-100→弧度）/ `zoom`（世界单位，**必须先于 pitch 设置**——俯仰下限依赖 zoom）/ `phase`（0-3，`set_phase(..., animate=false)` 直接跳变，避开 tween 被无头节流卡在中间态）/ `nomenu`（跳过地点选择菜单，录帧/截图用）/ `noshadow`（`shadow_opacity=0`，**必须在 phase 之后设置**否则被 `_apply_state` 覆盖）。Web 走 URL 参数，桌面走 `HARBOR_QA="k=v;k=v"` 环境变量。曾因 zoom 未实现导致所有"低角度"截图实际是 zoom 38 默认机位（俯角被下限钳到 11.8°，画面里根本没有天空） | 验收截图与像素统计探针的机位必须显式受控；诊断输出 `render.json` 含 cam_axis/cam_half/sun_dir/贴图采样点回读 |
| **R-ENG-28** | **海面掠射视角（水线）**：`WATER_SHADER` 菲涅尔项 `pow(1-|cam_dir.y|,4)` 在掠射时把水色混向天空反射色（`sky_refl_color`=该态地平线色），远海带（shore_d>40）混向 `far_sea_color`（与天空球海平线同值同公式）→ 水盒外缘与海平线无缝衔接。**禁止**用 `deep_color*0.75` 之类手动压暗做远海带——低机位下会呈现"浑浊水下"观感（2026-09-27 用户反馈） | 海平面机位（zoom 10-14 + pitch 下限）下半屏必须是映着天色的亮反射水面（lum>110），不是暗带 |
| **R-ENG-29** | **AI 网格三角破洞**：AI 生成网格常有局部翻转面，背面剔除下呈三角窟窿。`qa_batch.py` 导出前对全部材质设 `use_backface_culling=False`（glTF `doubleSided=true` → Godot 导入即 cull_disabled），两面都画；低模场景的过量绘制可忽略。QA 重跑免积分（样品 GLB 落盘 `.codebuddy/local/tripo/samples/`） | 泉州组用户实测"屋顶和墙壁有三角形的窟窿"（2026-09-27） |
| **R-ENG-30** | **阴影参数三件套**（泉州/CC 曾"影子看不见"）：`shadow_blur` ≤0.65 / `shadow_opacity` ≥0.8 / `ambient` ≤0.38（昼档）。三者耦合：blur 1.5 把影子糊没、opacity 0.5 太淡、ambient 0.48 用环境光把影子里也照亮——任一项超标视觉上即"无影"。另两条实测教训：① **WebGL 运行时切 `shadow_enabled` 会触发 shader variant 重编译导致光照丢失**（画面反常变暗 35），对照实验必须用 `shadow_opacity=0`；② 像素统计探针用 160×90 缩略图会把 ~1% 面积的影子稀释到测不出（全分辨率 1280×720 才测得 0.22% 压暗，桌面 1.06%）——**低面积效应必须全分辨率测量** | 桌面 4.7.2 全屏截屏 diff = 阴影渲染的铁证基准 |
| **R-ENG-31** | **AI 面数预算上调至 2000**（用户裁定，2026-09-27）：550 硬顶的 AI 直出细节不足以正确表达建筑/植物，改为 **Tripo face_limit 3000 生成 → QA decimate 到 2000**；未来精修走 Blender MCP（R-ENG-33）。旧 600 上限继续适用于纯色小品/密铺植物；英雄件（建筑/大型植物）一律 2000。GLB 贴图触发 pck 膨胀（0.5→25MB）——批量阶段在 QA 里把贴图降到 512px。（🔴 **管线升级 → 规格文档 §4**：用户有 Tripo 专业版订阅，走用户自己的 Tripo API/官方插件；质量基准升为 Townscaper/Boom Beach 级，调色板归一进 QA 脚本，样板件先行用户验收） | 泉州组用户实测"建筑物和植物都不合格，面数不足以正确表达" |
| **R-ENG-32** | **涟漪自然算法**（WATER_SHADER）：① 顶点/片元共用**域扭曲**（双层 vnoise 流场，坐标摆动 ±2.5 格）打破机械平行；② 涌浪三组不同方向/波长/速度叠加（含斜向短波）；③ 破波带**波群**（两列相位错开 + 慢包络，连涌两三波后歇一阵）；④ 沿岸泡沫链双层噪声相乘（碎段化，非均匀虚线）；⑤ whitecap 改双层流动噪声乘积（无风轴对称，随时间生灭） | 用户反馈"涟漪太呆板、过于平均，考虑引入自然算法"（2026-09-27） |
| **R-ENG-33** | **Blender MCP 已装**（ahujasid/blender-mcp，现为 mcp-for-blender）：addon → `%APPDATA%\Blender Foundation\Blender\5.2\scripts\addons\blender_mcp_addon.py`；server → `uvx mcp-for-blender`（uv 装于 Python314\Scripts）；mcp.json 已配（`~/.codebuddy/mcp.json`）。🔴 **addon 在 `bpy.app.background` 下拒绝启动 server（源码硬编码）**——headless 不可用，正确用法：**开 GUI Blender → N 面板 BlenderMCP → Start MCP Server**（端口 9876），CodeBuddy 重启后即连。用途：AI 高面数模型的交互式精修（R-ENG-31 管线的加工段） | 用户指定方案 github.com/ahujasid/mcp-for-blender（blendermcp.org 同源） |
| **R-ENG-34** | **GLB 批量本地管线**（2026-09-27 第二批 8 件落地）：`tools/art/<id>.py`（自包含：hex 色 → sRGB→linear Principled/rough 0.85，box 用 `primitive_cube_add(size=1.0)+scale`，**视觉原点=足迹中心、基座 z=0**，脚本内直接 `export_scene.gltf(export_yup=True)` 到 `project/assets/models/`）→ `blender --background --factory-startup --python tools/art/_local_run.py -- tools/art/<id>.py` → palette `mesh` 字段直接填 GLB 名（无需动代码，proc 几何保留作后备）。本批：塞舌尔 boulder/tortoise/coco/creole、CC highland/shingle、圣托里尼 bluedome/windmill（84~1040 三角面） | Tripo 通道在本环境不可用（插件 Premium 硬锁、无 API key、Hunyuan 本地服务未跑）；本地脚本产物风格与体素美学一致且零成本。mathutils.Vector 只接受单序列参数 |
| **R-ENG-35** | **字体子集治理为标准流程**：UI 出豆腐块 = `harbor-sc.ttf` 子集缺字。修复走 `tools/build_font_corpus.py`（保基准字形字节级不变 + 只从 Noto Sans SC 补缺字），已验证 `小/屋/灯塔` 等原有字形轮廓 IDENTICAL；🔴 三条铁律：① TEXT_SOURCES 必须 rglob 递归（四地建材在子目录）；② 验收用「gd 双引号字符串 + json 全文扫描 cmap」而非人眼看截图；③ ✗⟺🔴 等符号仅存于注释，无需入字体 | 新增「彩色小屋」文案后 UI 出豆腐块（2026-09-27），补 521 字形（367→418KB）一次修复 |
| **R-ENG-36** | **proc 占位清零**（2026-09-27 批三 17 件，三地 palette 已无 `proc:`）：共享工具库 `tools/art/_kit.py`（hex 材质缓存 / box / cyl / blob / torus / export+断言）+ 每资产一个 ≤30 行脚本。批二 8 件 + 批三 17 件 + 泉州 Tripo 7 件 = **三地全部建材 GLB 化**。命名 `loc_<地>_<类>_<名>`（bld 建筑 / nat 自然 / prop 道具 / shared 共享） | Tripo 通道不可用（Premium 锁）后的本地替代路线；低模（12~1040 三角面）与体素美学一致、零积分成本 |
| **R-ENG-37** | **GLB 内嵌贴图的抽取陷阱**（泉州 mansion 白模）：Godot gltf 导入默认 `embedded_image_handling=extract`——内嵌贴图被抽成 `assets/models/*_Color_*.jpg` 外部文件；若 jpg 被删而 `.godot/imported` 缓存残留旧 uid，导出报 `invalid UID → No loader found for .jpg`，模型丢贴图。修法：删 `*.glb.import` + `.godot/imported/*<名>*` 强制重导入（自动重新抽取 jpg）。副产物：清掉陈旧重复 ctex 后 **pck 25.1→13.8MB** | mansion 白模实测（2026-09-27）；旧缓存里同资产两个 3MB 级 ctex 是膨胀源头 |
| **R-ENG-38** | **同一性是程序生成的最大破绽**（2026-09-27 A1）：白屋三变体（whitehouse 方体 36 面 / _b 拱廊 60 面 / _c 露台 48 面）播种时随机选型（50/30/20）+ 随机朝向 0-3；变体也进建材表供玩家使用。验证方式：截图门向/屋形肉眼可辨差异 | Oia 参考图：真实小镇没有两栋相同的房子、没有排成一列的门 |
| **R-ENG-39** | **象龟漫游 AI**（2026-09-27 B1）：走-歇交替随机漫步（走 4-10s @0.22m/s=真实爬速、歇 3-8s），前方非实地（`top_y < 1` 即水下）或离锚 >5 格即折返 ±0.8rad；贴地按地面种类补偿滩涂压低（sand −0.42 / grass −0.2）；爬行微起伏 sin(t·3.1)·0.008。**常驻 1 只**守草环（世界活着的免费信号）+ 稳石奖励最多 3 只（保留原有奖励设计）。视觉 GLB、proc 回退。验证：6 秒区间像素 diff，单小区 4-7 像素持续移动 = 龟速吻合 | 旧实现是绕圈匀速转（机械感）且会走进泻湖 |
| **R-ENG-40** | **Studio 交接管线**（2026-09-28，Tripo API 积分与 Studio 积分池分离后的方案）：用户在 studio.tripo3d.ai 用定式 prompt 生成 → 下载 GLB 按「清单 id」命名丢进 `tripo_exports/` → `py .codebuddy/local/intake_studio.py`（id→目标/高度/面数映射表驱动，QA v4 全工序 + 原地替换）。验收规则：**AI 件装上后由用户判定去留**（palm 刺球/resort 灰盒被用户要求重出，白屋×3 贴图斑驳回退手模）；🔴 **git checkout HEAD 恢复 ≠ 恢复手模**——AI 件一旦提交过，HEAD 里就是 AI 版，必须回到替换前的具体提交（如 f348d8c）取件 | 用户实测（2026-09-28/29）；palm/resort/白屋三连教训 |
| **R-ENG-41** | **GDScript 负数取模陷阱**（2026-09-29）：`-2 % 4 == -2`（% 保持被除数符号）——朝海朝向 `_shore_rotation` 用 `atan2/（π/2)` 取整出负值，rot=-2 写进存档，`load_document` 校验 0..3 拒载 → "footprints do not overlap" 假象失败。**所有角度→0..3 的映射一律 `posmod(x, 4)`**；凡「生成→to_document→load_document 回读」链路上的枚举字段都要做非负校验 | 圣托里尼白屋朝海改造实测；测试 159/1→160/0 |
| **R-ENG-42** | **水体 screen_texture 折射 + 水下顶点染色**（2026-09-29，§2/§5 方案 B 定稿）：① 水 shader 加 `hint_screen_texture`，近岸（shore_d 5-26 格反门）用波相折射偏移采样屏幕（水下沙底/石基带波幅畸变透出）×泻湖水色滤镜，离岸变深回归水色；② 地形网格水面下顶点（y<-0.2）lerp 深水色 50%——石基/滩涂水下部分呈"浸在水中"观感；③ 中景水面细尺度噪声扰动掠射菲涅尔+明度（消"泳池色块"）；④ 岸线浪花镶边（cursor_work 移植：每条水线边 0.24m 泡沫条 + 8-13Hz 涟漪×闪光 shader）；⑤ 每地主题化远景环（16 件山丘盒沉半截入水，泉州塔/圣白盒/塞塔）。🔴 浪花镶边用 ALPHA（blend_mix）——R-ENG-19 记录 Web 下自定义 shader ALPHA 静默失效，本件 Web 截图未见镶边生效，**待 Web 端专项验证或改纯 ALBEDO 动画回退** | cursor_work 分支最有价值的三件移植（用户点名浪花镶边）+ 用户方案 B（半透明折射代替遮蔽） |
