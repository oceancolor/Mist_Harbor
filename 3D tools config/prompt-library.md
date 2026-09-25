# 雾港 · 文生 3D 提示词库（Prompt Library）

> 版本 **v1.2** ｜ 日期 2026-09-25 ｜ 状态：**管线配置 · 美术侧提示词库** ｜ 作者：林绘澄（art-director）
> 📌 **变更记录（保留，勿删）**：v1.0（2026-09-25 · 初版）→ v1.1（2026-09-25 同日 · Benja 三项拍板同步）→ ⭐ **v1.2（2026-09-25 同日 · 塞舌尔合并清单两件补录 · 现行）**——① SC-11 楔石 / SC-12 象龟入册（**SY-D-3 裁定必留件** · Benja 2026-09-25；面数已由 art doc v1.4 补报（SY-D-9）：楔石 **< 250** / 象龟 **< 300**）；② §7.2 验收表同步 +2 行；③ §7.3 汇总口径 32 → 34 条 / prompt 35 → 37 条
> 📌 **v1.1 变更摘要**：① §7.4 三处色值冲突 ✅ **已裁定（2026-09-25，Benja）：建材色值唯一源 = quanzou-spec §3**，本库取值与原暂取值一致（quanzou-spec），prompt 与验收表无需改值；② 三角梅 / 凤凰木 **已纳入泉州建材名额**（Benja 2026-09-25），回源 quanzou-spec §3（v1.8 增补）；③ 海椰子 **面数已破例 <600**（Benja 2026-09-25）。
> 用途：Tripo / Hyper3D（腾讯混元 3D）/ Meshy 等**文生 3D AI 工具**批量生成低多边形建材与植物资产 → 导入 Godot 4.4（Compatibility 渲染器 · Web 端）。
> ⚠ **AI 产出只是起点不是终点**：面数拓扑不可控，生成后必须**减面 + 手工校色到 spec 色值**。色值 / 造型 / 面数预算一律以 spec 为准，**不以 AI 输出为准**。

## 使用说明（先读这一条，再复制 prompt）

1. **先读源 spec**（本库不自创任何数值，全部回源）：
   - 泉州组 ← `strategy/quanzhou-spec.md` **§3 建材清单**（**v1.8 增补** · 三角梅 / 凤凰木已纳入建材名额，Benja 2026-09-25）
   - Cape Cod 组 ← `strategy/cape-cod-spec.md` **§2 建材清单**（v1.3）
   - 塞舌尔组 ← `strategy/quanzhou-seychelles-art.md` **§7–§9**（**v1.4**，林绘澄；楔石 / 象龟规格见 §9.3 #7 / #8，SY-D-3 必留 · SY-D-9 面数补报）；泉州面数预算 / 植物造型细则亦回源其 §3 / §4.3 / §11.3
2. 每条 prompt = **统一风格前缀 + 主体描述 + 视角**，整段复制粘贴即可，不再需要拼装。
3. 负面提示词**全库统一一条**（见 §2.3），每条生成均填同一段。
4. **逐资产字段**：规格（格数）｜面数预算（生成后减面验收用）｜排期归属｜回源｜特殊约束（MultiMesh 密铺 / 贴片光斑 / 拆分）。
5. 「可延期 / 可选」资产**照常提供 prompt**，但排期归属已标注，勿提前占用生成配额。
6. **四地共用件（§6）只生成一次**，各地不得重复生成。

---

## 2. 通用风格前缀与铁律

### 2.1 风格一致性铁律（本库最重要的一节）

**文生 3D 批量生成的最大风险是风格漂移**：35 条 prompt 分十天生成，如果没有一段完全相同的风格锚，出来的 35 件资产会像 35 个游戏的东西。

因此铁律只有一条：

> **所有资产共用同一段风格前缀，逐资产只替换主体描述。前缀一个词都不许改、不许加、不许删。**

- 前缀负责「这是什么风格的游戏资产」；主体描述只负责「这是什么物体、什么造型、什么色值」。
- 若某资产生成结果风格跑偏，**只调主体描述或重新 roll，不改前缀**——前缀一旦逐条漂移，整库报废。
- 四地点**共享同一段前缀**（低多边形迷你世界风是本体既定风格，quanzhou-seychelles-art §11 同口径）；地点差异由主体描述的色值与造型承担，不由风格承担。

### 2.2 统一风格前缀（STYLE PREFIX，逐条 prompt 已内嵌）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures,
solid flat colors, chunky simplified stylized shapes, miniature diorama style,
single object centered, neutral light grey background, three-quarter view,
soft even studio lighting
```

### 2.3 统一负面提示词（NEGATIVE，全库同一条）

```
no photorealistic textures, no high-poly detail, no PBR roughness maps,
no text, no watermark, no background clutter
```

### 2.4 生成后通用处理（每个资产都要做）

| 步骤 | 要求 | 回源 |
|---|---|---|
| 减面 | 三角数压到该资产面数预算以内（见逐条标注；全库硬顶 ≤ 600，本体上限 560） | art doc §11.3 |
| 校色 | AI 输出颜色一律重刷为 spec 色值（纯色 `StandardMaterial3D`，无贴图；纹理需求用法线 fake 或顶点色） | art doc §11.3 |
| 导出 | 纯几何 GLB，单件 < 30 KB | art doc §11.3 |
| 命名 | `loc_{地点}_{类别}_{名称}.glb`，如 `loc_qz_nat_erythrina.glb`、`loc_sc_ter_granite_lg.glb` | art doc §11.3 |
| 渲染 | 植物一律 `MultiMeshInstance3D`；不做 LOD，低端档降 MultiMesh 密度 | art doc §11.3 |

---

## 3. 泉州组（按 quanzhou-spec §3 顺序）

> 零改动直接复用的 8 件（草地 `8ab18c` / 石基 `b9bcad` / 木栈道 `bb946c` / 陶砖 `c8856b` / 坡屋顶 `c67360` / 桥拱 `d4cfb8` / 海蓝玻璃 `82bcc2` / 暖光灯 `eac989`）**不进本库**——模型已存在，无需 AI 生成。本组只收需要**新建 / 换模 / 改模**的条目。暖光灯与木栈道虽为复用件，但属四地共用核心资产，统一放 §6（四地共用勿重复生成）。

### QZ-01 · 蚵壳厝（Oyster-shell House）

- 规格：2×2×2 ｜ 面数预算 **< 450** ｜ 排期：**必做**（链条第三环，世界罕见建筑）｜ 回源：quanzhou-spec §3.2 #1；面数 art doc §4.3 #1
- 特殊约束：墙面鳞片壳凸起用低面半球或法线 fake（12–20 个/墙），**不加真几何细节**；本体无光效
- ✅ 色值冲突已裁定（2026-09-25，Benja）：**建材色值唯一源 = quanzou-spec §3**。本库暂取值本就取自 quanzou-spec（`#D8D2C4`/`#B5624A`），裁定后**不变**；art doc §4.3 旧值 `#DED9C8`/`#C8856B` 已作废留档（art doc v1.3）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a traditional Minnan oyster-shell house, simple cubic two-story volume, four walls tiled with overlapping scale-like rows of small grey-white oyster-shell half-dome bumps in color #D8D2C4, terracotta red brick edging framing the door and window openings in #B5624A, flat red clay tile cap roof in #C67360, twelve to twenty simplified shell bumps per wall, no light effects
```

### QZ-02 · 红砖古厝（Minnan Red-brick Mansion）

- 规格：3×3×2 ｜ 面数预算 **< 550** ｜ 排期：**必做**（聚落主体；D-3 建议替换海湾小屋退役）｜ 回源：quanzhou-spec §3.2 #2；面数 art doc §4.3 #3
- 特殊约束：**中心天井**（屋顶中部 1 格镂空）必须在几何上成立；含凹寿门廊；本体无光效（夜间灯火为运行时贴片）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a traditional Minnan red-brick mansion, rectangular footprint, red brick walls #C8856B standing on a white granite stone plinth base #B9BCAD, double-pitch red clay tile roof #C67360 with upturned swallowtail ridge ends, a central open-air courtyard skylight hole in the middle of the roof, recessed entrance porch, no light effects
```

### QZ-03 · 燕尾脊（Swallowtail Roof Ridge）

- 规格：1 格（置于坡屋顶之上）｜ 面数预算 **< 200** ｜ 排期：**必做**（性价比最高：零新色值 + 闽南天际线签名）｜ 回源：quanzhou-spec §3.2 #3；art doc §4.3 #2
- 特殊约束：独立可放置的屋脊附件，两端**高高翘起分叉如燕尾**；色 `#C67360` 与现有坡屋顶同色；可叠加在现有坡屋顶模型上

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a standalone traditional Chinese roof ridge ornament, slender horizontal ridge beam with both ends rising high and forking into two upturned prongs like a swallow's spread tail, red clay tile color #C67360, smooth chunky low-poly curves, no roof attached underneath
```

### QZ-04 · 刺桐树（Coral Tree / Erythrina）

- 规格：2 格 ｜ 面数预算 **< 400** ｜ 排期：**必做**（灵魂植物，链条终局「刺桐花开」）｜ 回源：quanzhou-spec §3.2 #4；造型细则 art doc §3 #1
- 特殊约束：**先花后叶**——满树红花无叶是辨识度全部来源；花簇用 8–12 个低面球或十字面片，**不用粒子**；渲染走 MultiMesh；若做季节切换需「花期版 / 绿叶版」两版（art doc §3.1 原则 1，排期待拍板）
- ✅ 色值冲突已裁定（2026-09-25，Benja）：**建材色值唯一源 = quanzou-spec §3**。本库取值本就为 quanzou-spec 的花 `#C8434A`，裁定后**不变**；art doc §2.3 旧值 `#D4553F` 已作废留档（art doc v1.3）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a coral tree (Erythrina variegata) in full scarlet bloom with no leaves, straight columnar trunk, three to four near-horizontal branches arranged in widely spaced layers, branch tips covered with dense round clusters of scarlet red flowers #C8434A, each flower cluster a simplified low-poly sphere blob, bare dark branches clearly visible, zero foliage
```

### QZ-05 · 垂榕 / 榕树（Banyan / Ficus microcarpa）

- 规格：3 格 ｜ 面数预算 **< 500** ｜ 排期：**必做**（村口风水树；海岛树 `#73A38B` 调深改造项）｜ 回源：quanzhou-spec §3.2 #5；造型细则 art doc §3 #2
- 特殊约束：冠幅要**宽**（约主干高的 1.5 倍）；**气根 6–10 条细长面片**从分枝垂下、深褐 `#6A5540`、emission 关——**没有气根的榕树就只是普通圆冠树，别省**（art doc §3.1 原则 2）；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a large banyan tree (Ficus microcarpa), very wide rounded canopy about one and a half times wider than the trunk is tall, deep muted green foliage #5F8F74, six to ten thin hanging aerial root strands dropping from the branches in dark brown #6A5540, massive short twisted trunk
```

### QZ-06 · 石构航标塔（姑嫂塔式八角石塔）

- 规格：高 3 格（与现有灯塔同高 → **直接换灯塔占位 / 碰撞 / 放置逻辑，改模不改代码**）｜ 面数预算 **< 400** ｜ 排期：**待 D-1 拍板**（建议 A：石构航标塔）｜ 回源：quanzhou-spec §3.4 / §10 D-1；art doc §4.3 #4
- 特殊约束：**八角五层楼阁式石塔，逐层收分，顶层略窄**；无灯室、无光效本体——夜间航标光为运行时贴片（半径 2.75 格，回源 art doc §5.1.1）；解决三塔撞车（本体 / Cape Cod / 泉州）
- ✅ 色值冲突已裁定（2026-09-25，Benja）：**建材色值唯一源 = quanzou-spec §3**。本条取 quanzou-spec D-1 建议值（石基 `b9bcad` + 陶砖 `c8856b`），裁定后**不变**；art doc §4.3 旧值 `#A8A898` 已作废留档（art doc v1.3）。塔的**形制归属（D-1 本身）仍待拍板**，与本次色值裁定无关

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: an ancient Chinese octagonal five-story stone pagoda tower, three units tall, eight-sided body tapering slightly story by story, small window openings on each level, short upturned curved eaves at the top of each story, weathered light granite stone body #B9BCAD with subtle terracotta accents #C8856B, no lantern room, no light effects
```

### QZ-07 · 素馨花丛 / 花担（Jasmine Flower Cluster）— 可选

- 规格：1 格 ｜ 面数预算 **< 150** ｜ 排期：**可选**（quanzhou-spec §3.3 #6；§11.2 建议提为必做——蟳埔簪花围是国内顶流 IP，成本极低）｜ 回源：quanzhou-spec §3.3 #6；art doc §3 #6
- 特殊约束：花坛 `d9aeae` 的改模替换项；白花串 `#F0ECD8`（quanzhou-spec），花心暖橙 `#E8A860`（art doc §2.3）；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a small jasmine flower shrub on a tiny carrying pole, clusters of tiny white five-petal flowers #F0ECD8 hanging in drooping strings, small warm orange flower centers #E8A860, sparse dark green stems
```

### QZ-08 · 红树林 / 秋茄（Mangrove / Kandelia obovata）— 可选

- 规格：1–2 格 ｜ 面数预算 **< 300** ｜ 排期：**可选**（quanzhou-spec §3.3 #7；滩涂限定，仅可种于潮间带浅水）｜ 回源：quanzhou-spec §3.3 #7；art doc §3 #5
- 特殊约束：⭐ **可种植在水面上**——直接复用「水面可打地基」系统，零新机制；支柱根呈放射状撑开；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a small mangrove tree (Kandelia obovata), short crooked trunk with thin stilt roots radiating outward and down at the waterline, rounded deep dark green crown #4F7F62, growing on a shallow water base
```

### QZ-09 · 三角梅（Bougainvillea）

- 规格：1–2 格 ｜ 面数预算 **< 250** ｜ 排期：**已纳入泉州建材名额**（Benja 2026-09-25；quanzou-spec §3 v1.8 增补）｜ 回源：quanzou-spec §3（v1.8 增补）；造型细则 art doc §3 #3
- 特殊约束：攀附型——**建议贴墙生长**（shader 生长遮罩，参考 godot-web-perf §3 爬山虎方案，**不要每帧生成实例**）；洋红苞片色值回源 quanzou-spec §3（v1.8 增补）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a climbing bougainvillea plant, flat clusters of magenta-pink flower bracts #C0507E against a simple plain wall panel, sparse woody vines reaching up the wall, low flat growth habit
```

### QZ-10 · 凤凰木（Royal Poinciana / Delonix regia）

- 规格：2–3 格 ｜ 面数预算 **< 450** ｜ 排期：**已纳入泉州建材名额**（Benja 2026-09-25；quanzou-spec §3 v1.8 增补）｜ 回源：quanzou-spec §3（v1.8 增补）；造型细则 art doc §3 #4
- 特殊约束：与刺桐的区分——**凤凰木冠是伞形且扁，刺桐是层状且高**；花橙红放开饱和度、树冠保持低饱和深绿 `#5F8F74`（art doc §3.1 原则 3）；花色值回源 quanzou-spec §3（v1.8 增补）；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a royal poinciana tree (Delonix regia), wide flat umbrella-shaped canopy spreading horizontally, slender pale trunk, muted deep green foliage #5F8F74 dotted with clusters of orange-red flowers #E0603C at the canopy surface
```

---

## 4. Cape Cod 组（按 cape-cod-spec §2 顺序）

> 复用项说明：风车屋**保留身份**（Eastham Windmill 式海岸风车，零新建，不生成）；木栈道 → 渔栈码头为**改色不改模**（风化银灰，引擎端换色，不生成）；草地 / 石基为地形与既有资产。暖光灯为四地共用件（§6）。本组 spec 未给单件面数预算，**统一按 art doc §11.3 通用上限 ≤ 600 验收**（本体上限 560）。

### CC-01a · 高地灯塔 · 塔身（Highland Light · Tower Body）— 拆分件 1/2

- 规格：占地 1×1，塔高 5 格（含灯室，四地里最高构筑物）｜ 面数预算 ≤ 600（通用上限）｜ 排期：**必做**（光网主力节点，链条第一环，R=18）｜ 回源：cape-cod-spec §2.1 #1 / §2.2
- 特殊约束：⭐ **拆分生成**——塔身与灯室分两条 prompt、两个 mesh，运行时组装（拆分标注见 §7）；**本体不含光效**——光锥 / 灯室光点 / 地面覆盖全部为运行时贴片（`blend_mix` + `fog_disabled`，cape-cod-spec §2.4）；占位 / 碰撞 / 放置逻辑复用现有灯塔多格构件机制

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a tall classic lighthouse tower body only, Highland Light style, slender tapered cylinder shaft five units tall, plain matte white paint #EDEDE8, simple gallery deck ring near the top, flat top surface ready to receive a separate lantern room, no lantern room, no light beam, no glow
```

### CC-01b · 高地灯塔 · 灯室（Highland Light · Lantern Room）— 拆分件 2/2

- 规格：1×1 顶置件 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**必做**（与 CC-01a 同任务）｜ 回源：cape-cod-spec §2.1 #1
- 特殊约束：**黑色灯室画廊 + 灯室暖白光点**——光点为运行时贴片（本体不做发光材质，**prompt 里明确 no glow**）；与塔身独立 mesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a small lighthouse lantern room topper, black steel gallery ring with railing, dark glass window panes, simple warm-white painted lamp core inside, black dome cap, flat solid colors, no light beam, no glow, unlit prop only
```

### CC-02 · 复刻小灯塔（Nauset Light）

- 规格：占地 1×1，塔高 3 格 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**必做**（链条辅助环，R=8）｜ 回源：cape-cod-spec §2.1 #2
- 特殊约束：**红白横条纹（上红下白）**、锥形塔身——条纹是缩略图尺度最强辨识物；本体不含光效

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a small lighthouse tower, Nauset Light style, three units tall, conical tapered body painted with bold horizontal stripes, red upper band over white lower band, small black lantern cap on top, no light beam, no glow
```

### CC-03 · 雾号站（Fog Station）— 可延期

- 规格：1×1×1 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**可延期**（先由小灯塔兼任其角色，cape-cod-spec §2.1 #3 / §4.7.2；但首发债务清单内，1.1 前须偿付）｜ 回源：cape-cod-spec §2.1 #3
- 特殊约束：小型锥顶木屋 + 短号角；银灰木瓦与 CC-04 同色 `#A8A8A4`；R=6，雾天光晕加倍（运行时）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a small fog signal station hut, one cube unit, wooden cabin walls clad in weathered silver-grey shingles #A8A8A4, steep cone-shaped shingle roof, one short black horn trumpet mounted on the roof, tiny door
```

### CC-04 · 灰木瓦小屋（Gray-shingle Cottage）

- 规格：2×2×2 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**必做**（⭐ 链条第二环「守望屋」与渔村聚落主体；海湾小屋换模改色）｜ 回源：cape-cod-spec §2.1 #4 / §2.2
- 特殊约束：**中央大烟囱**是 Cape Cod Cottage 签名形制，不可省；窗灯 / 炊烟为运行时效果（光斑贴片 + 粒子，本体不含）；灰木瓦 + 白窗框是缩略图辨识度主力（四色之一：米白灰）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a Cape Cod cottage, two-by-two footprint, walls clad in weathered silver-grey cedar shingles #A8A8A4, white window frames and white door frame #F4F4F0, steep shingled gable roof, one large brick chimney rising from the roof ridge center, no light effects
```

### CC-05 · 海滩草丛（Beachgrass）

- 规格：1 格 ｜ 面数预算 ≤ 600（通用上限；单株应远低于此，密度靠实例数）｜ 排期：**必做**（M3 验收四件新建材之一）｜ 回源：cape-cod-spec §2.1 #5
- 特殊约束：⭐ **MultiMesh 密铺型地被**——单株极简、成片种植给「锚住沙丘」观感（纯景观无判定）；**仅可种于沙地**；色春夏灰绿 `#A8B088`、秋季枯黄 `#C8B080`（意向，美术侧终定，可引擎换色不做两版）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a single beachgrass clump, one grid tile, sparse bundle of tall thin grass blades all leaning in the same sea-wind direction, muted grey-green #A8B088, very few blade polygons, minimal single-plant geometry for dense instancing
```

### CC-06 · 龙虾陷阱浮标（Lobster Buoy）— 可延期

- 规格：1 格海面点缀 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**可延期**（cape-cod-spec §2.1 #6 / §4.7.2；首发债务内）｜ 回源：cape-cod-spec §2.1 #6
- 特殊约束：⭐ **生成一次、引擎端实例换色出三变体**——橙 `#E8944A` / 明黄 `#E8C84A` / 湖绿 `#7AB8A0`（真实传统：每位渔民靠颜色认领陷阱）；浮沉动画 + 扫光「应答」明灭为运行时（自发光微光贴片，本体不发光）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a floating lobster trap buoy, one grid tile, bright painted foam float sphere in vivid orange #E8944A with a short wooden stick and small flag on top, tiny rope loop, no glow, unlit prop only
```

### CC-07 · 蔓越莓沼泽块（Cranberry Bog）— 可延期

- 规格：1 格 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**可延期**（R4 季节彩蛋，cape-cod-spec §2.1 #7 / §4.7.2；首发债务内）｜ 回源：cape-cod-spec §2.1 #7
- 特殊约束：**仅可置于低洼 / 浅水**；平时深绿水面、秋季血红 `#A02A34`——**一版 mesh 两态换色**（引擎端，不生成两版）；秋季「水收」是全产品最强季节爆点

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a cranberry bog block, one grid tile, low rectangular shallow water pool with tiny cranberry vine mounds floating on deep green still water, low trailing green vines, flat sunken water surface
```

### CC-08 · 海滩玫瑰丛（Rosa rugosa）

- 规格：1 格 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**必做**（花坛 `d9aeae` 改模项，沙地限定）｜ 回源：cape-cod-spec §2.2
- 特殊约束：与海滩草构成「草 + 花」双层沙丘肌理；粉白花（spec 未给 hex，以描述性「soft pink-white」出图、验收由美术侧终定）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a low rosa rugosa beach rose shrub, one grid tile, dense small rounded bush, soft pink-white five-petal flowers dotting the foliage, tiny red rose hips, muted green leaves, small sandy base patch
```

### CC-09 · 鲸鱼观景台（Whale-watching Platform）— 可延期（建筑本体）

- 规格：2×2×1 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**观景台建筑本体可延期**（D-CC-4 拍板 2026-09-25：**鲸背动画不可延期**——但动画是运行时远景效果，不是本库资产）｜ 回源：cape-cod-spec §2.3 #8 / §6.2 D-CC-4
- 特殊约束：**仅装饰**、无判定；🚫 帆船明确不做（cape-cod-spec §2.3 末注）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a small wooden whale-watching observation platform, two-by-two footprint, low square deck standing on short wooden pilings, simple open railing on all four sides, weathered grey-brown wood, small stair notch on one side
```

### CC-10 · 盐沼草块（Salt Marsh Grass）— 可选

- 规格：1 格 ｜ 面数预算 ≤ 600（通用上限；单株极简）｜ 排期：**可选**（cape-cod-spec §2.3 #9）｜ 回源：cape-cod-spec §2.3 #9
- 特殊约束：**MultiMesh 密铺型地被**（同 CC-05 口径）；潮间带沼泽洼地的地面肌理，非建筑；灰绿（spec 未给 hex，描述性出图）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a salt marsh grass patch, one grid tile, very low sparse clumps of grey-green marsh grass on damp mud, extremely flat and low profile, minimal single-plant geometry for dense instancing
```

---

## 5. 塞舌尔组（quanzhou-seychelles-art §7–§9）

> 复用件不进本库：木栈道（§6 共用件）、海蓝玻璃、暖光灯（§6 共用件）。灯塔在塞舌尔**建议隐藏**（去重，留给 Cape Cod 独占）。海椰子树 / 椰子树在 art doc §9.3 建材表与 §8 植物表为同一资产，**只生成一次**（见 SC-01 / SC-02）。

### SC-01 · 海椰子（Coco de Mer / Lodoicea maldivica）

- 规格：2–3 格 ｜ 面数预算 **< 600**（✅ **面数已破例 <600 · Benja 2026-09-25**；art doc §13.1 决策 5 已拍板结案）｜ 排期：**必做**（塞舌尔的全部辨识度，⭐⭐ 全系列辨识度最高单株植物）｜ 回源：art doc §8 #1 / §9.3 #3
- 特殊约束：**4–6 片巨大扇形叶、叶缘 V 形缺刻**（区分于普通椰子树的关键）；雌株挂**双裂巨大坚果** `#7A5A3E`；**扇叶不要做成平面**——每片沿中脉折起 15–25° V 形截面（art doc §8.1 原则 3）；单片叶接近 2–3 格宽（「少而大的叶 > 多而小的叶」）；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a Coco de Mer palm (Lodoicea maldivica), thick straight stout trunk in #8A7A70, only four to six enormous fan-shaped leaves each nearly three units wide with V-shaped notches along the edges, leaves held on long arching stalks forming a giant crown in saturated deep tropical green #2E7A4E, each fan leaf folded along its midrib like a shallow V, one large double-lobed brown seed nut hanging below the crown #7A5A3E
```

### SC-02 · 椰子树（Coconut Palm / Cocos nucifera）

- 规格：2–3 格 ｜ 面数预算 **< 450** ｜ 排期：**必做** ｜ 回源：art doc §8 #2 / §9.3 #4
- 特殊约束：与海椰子**一眼分开**——干**细且弯**、叶**羽状下垂**（轻盈摇曳 vs 海椰子的厚重 monumental，art doc §8.1 原则 2）；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a coconut palm (Cocos nucifera), slender ringed trunk curving gently to one side in #A08A6A, crown of six to eight long pinnate drooping fronds in light yellow-green #7FB454, small coconut cluster at the crown base, graceful leaning silhouette
```

### SC-03 · 旅人蕉（Traveller's Tree / Ravenala）

- 规格：2 格 ｜ 面数预算 **< 400** ｜ 排期：**高** ｜ 回源：art doc §8 #3
- 特殊约束：叶片**严格扇状平面排列**（像一把展开的折扇）+ 长叶柄——这是它区别于芭蕉的全部造型特征；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a traveller's tree (Ravenala madagascariensis), long banana-like leaves arranged strictly in one flat fan plane like an unfolded folding fan, long pale leaf stalks radiating from a short trunk, fan-shaped green #3E8A5A, two units tall
```

### SC-04 · 红树（Red Mangrove / Rhizophora）

- 规格：1–2 格 ｜ 面数预算 **< 300** ｜ 排期：**中** ｜ 回源：art doc §8 #4
- 特殊约束：**支柱根呈拱形撑开**、种在水面（复用现有水面地基系统）；造型与泉州秋茄（QZ-08）同构、色系不同——两件分开生成、不共用模型（色值回源各自条目）；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a red mangrove (Rhizophora), compact tree with thick arching stilt roots splaying from the trunk down into the water, rounded crown of saturated tropical green #2E7A4E, standing on a shallow water base disc
```

### SC-05 · 鸡蛋花（Frangipani / Plumeria）

- 规格：1–2 格 ｜ 面数预算 **< 250** ｜ 排期：**高** ｜ 回源：art doc §8 #5
- 特殊约束：花坛 `d9aeae` 的替换项；五瓣白花 `#FBF0D8` + 暖黄花心 `#F0C040`；枝干**粗短分叉**；渲染走 MultiMesh

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a frangipani tree (Plumeria), short thick pale forked branches, clusters of five-petal white flowers #FBF0D8 with warm yellow centers #F0C040 at the branch tips, sparse small green leaves, stubby sculptural trunk
```

### SC-06 · 蕨类（Fern）⭐ MultiMesh 密铺

- 规格：1 格 ｜ 面数预算 **< 200** ｜ 排期：**中**；art doc §9.4 建议做成 **MultiMesh 地被而非可放置建材**（为塞舌尔 ≤20 建材上限腾名额）｜ 回源：art doc §8 #6 / §9.4
- 特殊约束：⭐ **MultiMesh 密铺型地被的样板件**——林下暗绿 `#1E5A3A`，单株几何压到最简，成景全靠实例密度

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a single low tropical fern plant, one grid tile, a few arching cut-leaf fronds, dark understory green #1E5A3A, extremely minimal single-plant geometry designed for dense ground-cover instancing
```

### SC-07 · 花岗岩巨石（Seychelles Granite Boulder）— 3 种规格

- 规格：高 1–3 格（三种尺寸共用一套材质）｜ 面数预算 **< 350**（单规格）｜ 排期：**必做**（⭐ 塞舌尔地质签名；3 规格 ≈ 1 规格面数 ×1.4，巨石堆是最出片构图元素，值得）｜ 回源：art doc §9.3 #1
- 特殊约束：**球形风化**——不规则球状、表面圆润无棱角；三色：本体 `#B8A092` / 暗部 `#8A7A70` / 受光面 `#D8C4B4`；**同一段 prompt 跑三次，只改尺寸词**（small / medium / large）

SC-07a（小 · 1 格）：
```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a small Seychelles granite boulder, one grid unit, irregular rounded spherical weathered rock with smooth bulges and no sharp edges, pinkish-grey stone body #B8A092 with darker shadow side #8A7A70 and lighter sun-lit top #D8C4B4
```

SC-07b（中 · 2 格）：
```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a medium Seychelles granite boulder, two grid units tall, irregular rounded spherical weathered rock with smooth bulges and no sharp edges, pinkish-grey stone body #B8A092 with darker shadow side #8A7A70 and lighter sun-lit top #D8C4B4
```

SC-07c（大 · 3 格）：
```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a large Seychelles granite boulder, three grid units tall, massive irregular rounded spherical weathered rock with smooth bulges and no sharp edges, pinkish-grey stone body #B8A092 with darker shadow side #8A7A70 and lighter sun-lit top #D8C4B4
```

### SC-08 · 白沙滩块（White Sand Beach Tile）

- 规格：1 格 ｜ 面数预算 **< 200** ｜ 排期：**必做**（替代草地成为地表主色）｜ 回源：art doc §9.3 #2
- 特殊约束：平坦略起伏；`#F0E4CC`（钙质白砂，世界级白沙滩）；地表 tile，无装饰件

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a flat white coral sand terrain tile, one grid unit square, gently undulating smooth sand surface, warm off-white #F0E4CC, empty top with no objects
```

### SC-09 · 椰叶茅草顶（Palm-thatch Roof）

- 规格：建筑附件（替换坡屋顶）｜ 面数预算 **< 250** ｜ 排期：**高** ｜ 回源：art doc §9.3 #5
- 特殊约束：编织质感用**法线纹理 fake、不加几何**（art doc §9.3 明注）；`#C8A46A`；与 SC-10 珊瑚石屋组合成克里奥尔屋顶

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a standalone tropical thatched roof piece woven from palm leaves, gentle steep pitch form, warm straw tan #C8A46A, subtle coarse woven strand ridges, plain geometric base with no walls
```

### SC-10 · 珊瑚石屋（Coral Stone Creole Cottage）

- 规格：高 2 格 ｜ 面数预算 **< 500** ｜ 排期：**高** ｜ 回源：art doc §9.3 #6
- 特殊约束：克里奥尔风格——**陡坡茅草顶 + 宽廊 + 木格栅**；珊瑚石 `#E0D4C0` + 木构 `#BB946C`（后者与共用木栈道同色）；本体无光效（夜间灯窗为运行时贴片）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a Creole coral stone cottage, two units tall, pale coral limestone block walls #E0D4C0, dark timber posts and lintels #BB946C, steep thatched grass roof, wide open veranda with simple wooden lattice railing, no light effects
```

### SC-11 · 楔石（Calage / Wedge Stone）

- 规格：1×1×1 ｜ 面数预算 **< 250** ｜ 排期：**必做**（⭐ 动词「垫」的第二主力，M3 与巨石并列；SY-D-3 裁定必留件 · Benja 2026-09-25）｜ 回源：art doc §9.3 #7（v1.4 · SY-D-9 面数补报）
- 特殊约束：**扁平不规则垫石**——不规则六面坯 + 不平整顶面 + 边缘倒角，四向旋转放置时轮廓各不同（每块 +1 格接触面，回源 LGD §2.4）；花岗岩灰粉系 `#B8A092` / 暗面 `#8A7A70` / 受光 `#D8C4B4`——**与花岗岩巨石（SC-07）共用一套材质族观感**（SY-D-1 裁定口径下花岗岩色系唯一源 = art doc；LGD 旧值 `#A89889` 不另立、随裁定作废）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a flat irregular wedge stone block, one grid unit cube, rough irregular hexahedral block with an uneven slightly tilted top surface and chamfered rounded edges, pinkish-grey granite body #B8A092 with darker shadow side #8A7A70 and lighter sun-lit top #D8C4B4, same granite material family as weathered boulders, low chunky leveling-stone profile
```

### SC-12 · 象龟（Giant Tortoise / Aldabra）

- 规格：1 格 ｜ 面数预算 **< 300** ｜ 排期：**可延期（必留名额）**（SY-D-3 裁定必留；先做静态装饰、不做 AI 路径——首发债务件，⚠ 可延期 ≠ 可砍）｜ 回源：art doc §9.3 #8（v1.4 · SY-D-9 面数补报）
- 特殊约束：**静态生物装饰件，无动画无骨骼**——「稳」的石堆旁解锁的生命信标；低分段球冠甲壳（约 12 段 × 6 环，接住顶光读出圆润感——art doc §8.1 原则 3 同款诉求）+ 块状头颈四足；甲壳 `#7A6254`（深灰褐风化龟甲）/ 头足 `#C8B49A`（浅暖灰，与甲壳拉开明暗——与石堆同画面时靠明度差与轮廓区分）；若后续启用 0.2 格/秒移动（回源 LGD §2.4），走 Transform / 骨骼、不增面数

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a giant Aldabra tortoise, one grid unit, high domed carapace as a low-segment spherical cap in weathered dark grey-brown #7A6254, massive blocky scaled legs and thick stubby head and neck in pale warm grey #C8B49A, calm slow posture standing on flat ground, static decorative creature prop, no animation extremes
```

---

## 6. 通用环境件（四地共用 · 只生成一次 · 勿重复生成）

> 性质：现有 13 建材中的两件跨地点复用件。**整库唯一允许「生成一次、四地共用」的资产**。各地语义由引擎端换色 / 放置承担，不再生成第二版。

### CM-01 · 暖光灯（Warm Lamp / Lantern）⭐ 贴片光斑标注

- 规格：高 2 格 ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**必做**（⭐ 「灯火次第亮起」核心资产，四地完整保留）｜ 回源：quanzhou-spec §3.1 / §3.4；cape-cod-spec §2.2；art doc §4.1 #12
- 特殊约束：⭐ **本体不含光效**——灯体自发光 `#EAC989`（emission，MH-ENG-002a）与**投射光斑 `#FFBD70`**（半径 1.5 格，MultiMesh 贴片，`blend_mix` + `fog_disabled`，MH-ENG-002b）**全部运行时加**，生成时明确 no glow / unlit prop。泉州「厝墙灯笼成排」、Cape Cod 窗灯 / 栈桥灯笼、塞舌尔夜间灯窗全靠它——**这是四地点共用件里最重要的一件**

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a hanging lantern street lamp, two units tall, simple dark post arm with one round paper lantern, lantern body in plain solid warm cream #EAC989, smooth unadorned lantern surface, no light beam, no glow, unlit prop only
```

### CM-02 · 木栈道（Wooden Boardwalk）

- 规格：1 格铺装 tile ｜ 面数预算 ≤ 600（通用上限）｜ 排期：**必做**（四地语义：泉州码头栈道 / 塞舌尔椰木栈道 / Cape Cod 渔栈码头）｜ 回源：quanzhou-spec §3.1 / §3.4；cape-cod-spec §2.2；art doc §7.2 / §9.1
- 特殊约束：⭐ **生成一次、引擎换色**——本体色 `#BB946C`（泉州 / 塞舌尔直用）；Cape Cod 渔栈码头**改色为风化银灰、不改模**（cape-cod-spec §2.2 明注，勿再生成第二版）

```
Low-poly 3D game asset, flat matte shading, clean faceted geometry, no textures, solid flat colors, chunky simplified stylized shapes, miniature diorama style, single object centered, neutral light grey background, three-quarter view, soft even studio lighting: a wooden boardwalk pier tile, one grid unit square, flat plank deck section standing on four short round wooden pilings, plain planks in warm brown wood #BB946C, flat usable top surface
```

### 6.x 明确不在本库范围内的项（运行时 / 引擎侧，非 AI 资产）

| 项 | 归属 |
|---|---|
| 灯火光斑贴片（quad + `blend_mix` + `fog_disabled`）、Cape Cod 旋转光锥、灯塔地面覆盖 | `MH-ENG-002b`，引擎侧 ShaderMaterial，非生成资产 |
| 微光箭头引导（泉州）、暗角提示 / 覆盖热力图（Cape Cod） | A-1 材质族，引擎侧 |
| 渔船归港（泉州）、鲸背 + 水柱（Cape Cod）、炊烟 / 晾晒动态装饰 | 运行时动画资产，属后续动态装饰排期，不在建材清单内 |
| 种蛎固基蚝壳纹理（洛阳桥 shader 遮罩） | shader 效果，非独立 mesh |

---

## 7. 验收对照表（生成后逐项对照 spec）

### 7.1 全库通用检查（每件必过）

| # | 检查点 | 判据 | 回源 |
|---|---|---|---|
| 1 | **风格一致性** | 与库内其他资产并排放，读作同一个游戏——跑偏即重 roll，**不改前缀** | 本库 §2.1 |
| 2 | **面数** | 减面后三角数 ≤ 该资产面数预算；全库硬顶 ≤ 600（本体 560；海椰子✅ 已破例 600 · Benja 2026-09-25） | art doc §11.3 |
| 3 | **色值** | AI 输出颜色重刷为 spec hex（见 7.2 逐资产锚点列）——**色值以 spec 为准，不以 AI 输出为准** | 三份 spec |
| 4 | **材质** | 纯色 `StandardMaterial3D`、无贴图；纹理需求法线 fake / 顶点色 | art doc §11.3 |
| 5 | **格式 / 大小 / 命名** | 纯几何 GLB、单件 < 30 KB、`loc_{地点}_{类别}_{名称}.glb` | art doc §11.3 |
| 6 | **无光效** | 所有带「贴片光斑」标注的资产，本体 mesh 不含发光材质与光束 | 本库特殊约束列 |
| 7 | **单体成件** | 单物体、无底座 debris、无背景残留几何（负面提示词防线） | 本库 §2.3 |

### 7.2 逐资产验收锚点

| ID | 资产 | spec 源 | 色值锚点 | 造型检查点 | 面数 | 特殊约束 |
|---|---|---|---|---|---|---|
| QZ-01 | 蚵壳厝 | qz-spec §3.2 #1 | `#D8D2C4`/`#B5624A`/`#C67360`（✅ 冲突已裁定 2026-09-25 Benja：唯一源 = quanzou-spec §3；art doc 旧值已作废） | 鳞片壳凸起、红砖镶边、红瓦压顶 | < 450 | — |
| QZ-02 | 红砖古厝 | qz-spec §3.2 #2 | `#C8856B`/`#B9BCAD`/`#C67360` | 天井镂空、燕尾脊、白石基 | < 550 | 本体无光效 |
| QZ-03 | 燕尾脊 | qz-spec §3.2 #3 | `#C67360` | 两端高翘分叉如燕尾 | < 200 | 可叠坡屋顶 |
| QZ-04 | 刺桐 | qz-spec §3.2 #4 | 花 `#C8434A`（✅ 冲突已裁定 2026-09-25 Benja：唯一源 = quanzou-spec §3；art doc 旧值已作废） | 先花后叶、层状分枝、花簇低面球 | < 400 | MultiMesh 渲染 |
| QZ-05 | 垂榕 | qz-spec §3.2 #5 | 冠 `#5F8F74`、气根 `#6A5540` | 冠幅 ≥ 干高 1.5×、气根 6–10 条 | < 500 | MultiMesh 渲染 |
| QZ-06 | 石构航标塔 | qz-spec §10 D-1 / §3.4 | `#B9BCAD`+`#C8856B`（✅ 冲突已裁定 2026-09-25 Benja：唯一源 = quanzou-spec §3 / D-1 口径；art doc 旧值已作废） | 八角五层、逐层收分、高 3 格直换灯塔占位 | < 400 | 形制 D-1 仍待拍板；运行时光斑 2.75 格 |
| QZ-07 | 素馨花丛 | qz-spec §3.3 #6 | `#F0ECD8` + 花心 `#E8A860` | 白花串、花担 | < 150 | 可选；MultiMesh |
| QZ-08 | 红树林 | qz-spec §3.3 #7 | `#4F7F62` | 放射支柱根、水面可种 | < 300 | 可选；MultiMesh |
| QZ-09 | 三角梅 | qz-spec §3（v1.8 增补） | 洋红（回源 quanzou-spec §3 v1.8） | 贴墙攀附、苞片簇 | < 250 | 已纳入泉州建材名额（Benja 2026-09-25） |
| QZ-10 | 凤凰木 | qz-spec §3（v1.8 增补） | 花橙红（回源 quanzou-spec §3 v1.8）、冠 `#5F8F74` | 伞形扁冠（vs 刺桐层状高冠） | < 450 | 已纳入泉州建材名额（Benja 2026-09-25） |
| CC-01a/b | 高地灯塔 | cc-spec §2.1 #1 | 塔 `#EDEDE8`、灯室黑+暖白 | 塔高 5 格含灯室、素白塔身 | ≤ 600 | ⭐ 拆分 2 mesh；光效运行时贴片 |
| CC-02 | 小灯塔 | cc-spec §2.1 #2 | 红白条纹（上红下白） | 锥形塔身、塔高 3 格 | ≤ 600 | 本体无光效 |
| CC-03 | 雾号站 | cc-spec §2.1 #3 | 木瓦 `#A8A8A4` | 锥顶小屋 + 短号角 | ≤ 600 | 可延期（首发债务内） |
| CC-04 | 灰木瓦小屋 | cc-spec §2.1 #4 | `#A8A8A4` + 框 `#F4F4F0` | 中央大烟囱、白窗框白门框 | ≤ 600 | 窗灯运行时贴片 |
| CC-05 | 海滩草 | cc-spec §2.1 #5 | `#A8B088`（秋 `#C8B080`） | 风吹同向草束、仅沙地 | ≤ 600 | ⭐ MultiMesh 密铺 |
| CC-06 | 龙虾浮标 | cc-spec §2.1 #6 | 三色 `#E8944A`/`#E8C84A`/`#7AB8A0` | 彩色浮球 + 旗杆 | ≤ 600 | 生成 1 次引擎换色出 3 变体；可延期 |
| CC-07 | 蔓越莓沼泽 | cc-spec §2.1 #7 | 秋 `#A02A34` | 浅水洼 + 藤蔓 | ≤ 600 | 一版两态换色；可延期 |
| CC-08 | 海滩玫瑰 | cc-spec §2.2 | 粉白花（描述性，美术终定） | 低矮密丛 + 蔷薇果 | ≤ 600 | 沙地限定 |
| CC-09 | 观景台 | cc-spec §2.3 #8 | 木构（描述性） | 2×2×1 平台 + 栏杆 | ≤ 600 | 建筑本体可延期（D-CC-4） |
| CC-10 | 盐沼草 | cc-spec §2.3 #9 | 灰绿（描述性） | 极低洼地草簇 | ≤ 600 | ⭐ MultiMesh 密铺；可选 |
| SC-01 | 海椰子 | art doc §8 #1 | 叶 `#2E7A4E`/干 `#8A7A70`/果 `#7A5A3E` | 4–6 巨扇叶 V 缺刻、双裂果、叶折 V 形 | < 600（✅ 已破例） | 面数已破例 <600（Benja 2026-09-25）；MultiMesh |
| SC-02 | 椰子树 | art doc §8 #2 | 叶 `#7FB454`/干 `#A08A6A` | 细弯干 + 羽状下垂叶（与海椰子一眼分开） | < 450 | MultiMesh |
| SC-03 | 旅人蕉 | art doc §8 #3 | `#3E8A5A` | 严格单面折扇排列 | < 400 | MultiMesh |
| SC-04 | 红树 | art doc §8 #4 | `#2E7A4E` | 拱形支柱根、水面可种 | < 300 | MultiMesh；与 QZ-08 分开生成 |
| SC-05 | 鸡蛋花 | art doc §8 #5 | 白 `#FBF0D8` + 心 `#F0C040` | 五瓣 + 粗短分叉枝 | < 250 | MultiMesh |
| SC-06 | 蕨类 | art doc §8 #6 | `#1E5A3A` | 极简地被单株 | < 200 | ⭐ MultiMesh 密铺样板 |
| SC-07a/b/c | 花岗岩巨石 ×3 | art doc §9.3 #1 | `#B8A092`/`#8A7A70`/`#D8C4B4` | 球形风化无棱角、三规格 | < 350/规格 | 共用一套材质 |
| SC-08 | 白沙滩块 | art doc §9.3 #2 | `#F0E4CC` | 平坦略起伏、无装饰 | < 200 | — |
| SC-09 | 茅草顶 | art doc §9.3 #5 | `#C8A46A` | 编织纹法线 fake 不加几何 | < 250 | — |
| SC-10 | 珊瑚石屋 | art doc §9.3 #6 | `#E0D4C0` + `#BB946C` | 陡坡茅草顶 + 宽廊 + 木格栅 | < 500 | 本体无光效 |
| SC-11 | 楔石 | art doc §9.3 #7 | `#B8A092`/`#8A7A70`/`#D8C4B4`（与巨石共用材质族；LGD 旧值 `#A89889` 作废） | 六面坯 + 不平顶 + 倒角、四向旋转轮廓各不同 | < 250 | 必做（SY-D-3 必留；SY-D-9 面数补报） |
| SC-12 | 象龟 | art doc §9.3 #8 | 甲壳 `#7A6254` / 头足 `#C8B49A` | 低分段球冠甲壳 + 块状四肢、静态 | < 300 | 可延期（必留名额，SY-D-3）；无动画无骨骼；移动走 Transform 不增面 |
| CM-01 | 暖光灯 | qz §3.1 / cc §2.2 / art §4.1 | 灯体 `#EAC989`；光斑 `#FFBD70` 运行时 | 圆灯笼 + 灯柱 | ≤ 600 | ⭐ 四地共用；光效运行时贴片 |
| CM-02 | 木栈道 | qz §3.4 / cc §2.2 / art §9.1 | `#BB946C`；Cape Cod 运行时改银灰 | 板面 + 短桩 | ≤ 600 | ⭐ 四地共用生成 1 次 |

### 7.3 汇总口径（给主理人汇报用）

- **资产条目总数：34 条**（泉州 10 · Cape Cod 10 · 塞舌尔 12 · 四地共用 2）
- **prompt 总数：37 条**（高地灯塔拆塔身 / 灯室 2 条；花岗岩巨石 3 规格 3 条；其余一资产一条）
- **MultiMesh 密铺标注：4 件**（蕨类 SC-06 / 海滩草 CC-05 / 盐沼草 CC-10 / 素馨 QZ-07；全部植物另按 art doc §11.3 走 MultiMesh 渲染）
- **贴片光斑标注（本体不含光效）：7 件**（暖光灯 CM-01 / 高地灯塔 CC-01a·b / 小灯塔 CC-02 / 姑嫂塔 QZ-06 / 灰木瓦小屋 CC-04 / 珊瑚石屋 SC-10 / 红砖古厝 QZ-02）
- **拆分生成：1 件**（高地灯塔 = 塔身 + 灯室）
- **可延期 / 可选 / 待拍板排期归属**：可延期 4（雾号站 / 浮标 / 蔓越莓 / **象龟 SC-12**，均在首发债务内）＋可选 3（素馨 / 红树林 / 盐沼草）＋观景台本体可延期＋待拍板 1（姑嫂塔 D-1 形制，其**色值已裁定**）＋三角梅 / 凤凰木**已纳入泉州建材名额**（Benja 2026-09-25，不再是待排期项）；🆕 v1.2 新增的楔石 SC-11 为**必做**（SY-D-3 必留），不属可延期档

### 7.4 色值冲突清单（✅ 已全部裁定 · 2026-09-25，Benja）

> **裁定结论：建材色值唯一源 = quanzou-spec §3。**
> 三处冲突均以 quanzou-spec 为准，art doc（quanzhou-seychelles-art.md v1.3）旧值已作废留档。
> **本库 v1.0 的暂取值本就取自 quanzou-spec，故裁定后各条 prompt 与验收锚点均无需改值。**

| # | 资产 | 裁定采用值（= quanzou-spec，唯一源） | art doc 旧值（已作废 · 勿用） |
|---|---|---|---|
| 1 | 蚵壳厝墙面 / 镶边 | `#D8D2C4` / `#B5624A` | ~~`#DED9C8` / `#C8856B`~~ |
| 2 | 刺桐花色 | `#C8434A` | ~~`#D4553F`~~ |
| 3 | 姑嫂塔塔身 | 石基 `#B9BCAD` + 陶砖 `#C8856B`（D-1 建议值口径） | ~~风化花岗岩 `#A8A898`~~ |

> 三处原为同一物体在两份 spec 里的并行色值（源文档间未对账，非本库自创），2026-09-25 由 Benja 裁定唯一源后结案；本库 v1.1 已同步（§3 各条目与 §7.2 验收表标记同步更新）。

---

> 本库所有色值 / 造型 / 面数 / 排期口径回源自：`quanzhou-spec.md` v1.8 §3 / §10、`cape-cod-spec.md` v1.3 §2、`quanzhou-seychelles-art.md` v1.4 §3 / §4.3 / §7–§9 / §11.3。环境态参数（水 / 光 / 雾 / 天空）不在本库范围，唯一源为 `water-lighting-params.md` v4.2。冲突以源 spec 为准（2026-09-25 Benja 裁定建材色值唯一源 = quanzou-spec §3）；本库与之冲突时，本库随之作废。
