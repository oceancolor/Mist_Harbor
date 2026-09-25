# 《雾港造物记 / Mist Harbor》· 3D 生成管线配置

> 版本 v1.1 ｜ 日期 2026-09-25 ｜ 组装人：游承峰（主理人）｜ 用途：**下一轮制作的资产生成管线搭建**
> 📌 **变更记录**：v1.0（2026-09-25 · 初版）→ **v1.1（2026-09-25 · Benja 拍板增补可选 Blender headless 批量/QA 阶段：③B 段 + 工具表 + tool-connections §4）**
> 配套文档集：`../Dev Driven/`（开发驱动文档）——本管线的验收标准全部来自那里

## 文件夹内容

| 文件 | 内容 | 作者 |
|---|---|---|
| `README.md`（本文件） | 管线总览：工具选型、流程、Godot 端约定 | 主理人 |
| `tool-connections.md` | Tripo / Hyper3D / Meshy 的 MCP 与 API 接入配置（key 占位待填） | 主理人 |
| `prompt-library.md` | 逐资产文生 3D 提示词库（造型/色值/面数全部回源自三份 spec） | 美术侧（林绘澄） |

## 工具选型结论（2026-09-25 查证）

| 工具 | 接入方式 | 结论 | 理由 |
|---|---|---|---|
| **Meshy** | 官方 MCP：`@meshy-ai/meshy-mcp-server`（npx） | ✅ **首选** | 官方维护、20 工具全链路（text/image→3D、refine、remesh、retexture）、GLB 导出、有 Godot 原生插件（Meshy Bridge）；API 需 Pro 档 |
| **Tripo** | 社区 MCP：`tripo-ai-mcp-server`（npx，活跃 2026-04） | 🟡 对照/备选 | 官方 MCP 绑 Blender 且 2025-04 起停更（alpha）；社区版支持 `face_limit` 参数与 GLTF 转换，与本管线「面数预算」验收天然契合 |
| **Hyper3D（腾讯混元 3D）** | HTTP API 直连 | 🟡 待账号 | 无成熟 MCP server；配置骨架已给，key 到位后补全 |
| **Blender（headless）** | 本机 `bpy` Python 脚本（无 MCP） | 🔵 **可选 · 批量/QA 阶段** | 批量减面、面数预算自动校验、法线/轴心修复、批量导出 GLB、LOD/碰撞网格；**不在关键路径上**，资产量上来后启用（详见下节） |

**建议主路线：Meshy 生成 + Tripo `face_limit` 对照压面数**；同一资产双工具各出一次、按面数与色值择优——两工具输出都是 GLB，Godot 4.4 直接导入。**Blender headless 作为可选的批量/QA 段**插在压面数与导出之间（见下节），不作为每资产强制步骤。

## 管线流程（每个资产六步 + 可选 Blender 批量段）

```
① 取提示词（prompt-library.md 对应条目，风格前缀原样带）
   → ② 生成（MCP 工具调用；概念图可作 image-to-3D 输入提升造型还原度）
   → ③ 压面数（Meshy remesh / Tripo face_limit；对照 spec 面数预算，如蕨类 < 200、海椰子 < 600）
   → ③B（可选·整批统一做）Blender headless 批量 QA：批量减面到预算线 + 面数自动校验
        + 法线/流形/轴心修复 + 批量导出 GLB（见下节；单件试产时跳过）
   → ④ 色值校验（对照 spec hex 表；AI 贴图色偏则用 retexture 修，仍偏则改用顶点色/材质球在 Godot 端覆写）
   → ⑤ 导出 GLB → Godot 导入（场景约定见下）
   → ⑥ 对照验收表（prompt-library.md 末节）打勾归档
```

## 可选 · Blender headless 批量/QA 阶段（非关键路径，2026-09-25 Benja 拍板增补）

**定位**：本管线是「AI 直出 GLB → Godot」的轻管线，**Blender 不做每资产强制步骤**；但当批量规模上来或 AI 导出质量不稳时，用一个 headless Blender（`bpy`）批处理脚本做整批 QA，效率远高于在 AI 工具 UI 里逐件手动处理。

**触发条件（满足其一即启用）**：
1. 单批待处理资产 **> 10 件**（如泉州组首批 18 件）；
2. AI 导出出现**坏网格**（反面法线、非流形、原点/朝向不对、比例失真）；
3. 需要 **LOD 或碰撞网格**（本体重构等英雄资产）；
4. 需要输出**面数校验报告**作为验收证据（对应验收表"面数预算"列）。

**批处理脚本职责（QA 四件事）**：
| 职责 | 做法 | 验收口径 |
|---|---|---|
| 批量减面 | `bpy` decimate modifier 逐件压到该资产面数预算（预算表从 spec 导出成 JSON 供脚本读取） | spec 面数预算列（硬顶 ≤ 600） |
| 面数自动校验 | 逐件统计三角数，超预算的**拒收并记日志**，不进下一环节 | 同上 |
| 网格修复 | 法线重算（`normals_make_consistent`）、非流形修复、原点移到底面中心、Y-up 校正 | Godot 导入零修正 |
| 批量导出 | 统一命名 `loc_{地点}_{类别}_{名称}.glb`、纯几何单件 < 30 KB | art doc §11.3 |

**调用方式（无 MCP，走命令行）**：
```
blender --background --python qa_batch.py -- <输入目录> <输出目录> <面数预算表.json>
```

**与六步的关系**：③B 是整批统一做的段（不是每件资产生成后立刻过），插在 ③ 与 ④ 之间；单件试产、小批量、AI 直出质量稳定时可整段跳过。**Blender 里不做的事**：雕刻、重拓扑、UV 展开、烘焙、绑定——本项目资产画像（低多边形/纯色/无贴图/无骨骼）刻意避开这些，不要回潮。

## Godot 4.4 端约定（来自 `Dev Driven/tech-feasibility.md` 与 `godot-web-perf.md`，此处只列管线相关）

- **Web 端 Compatibility 渲染器**：不要 PBR roughness/metallic 贴图依赖——材质在 Godot 端统一改写为 `flat shading` + 顶点色/单色 albedo；生成时用负面提示词压掉写实贴图（prompt-library 已含）
- **MultiMesh 密铺件**（蕨类/海滩草丛/微光箭头等）：单独 GLB，单实例几何尽量 < 300 面
- **光效不进模型**：暖光灯、灯塔本体**不含任何光效几何/发光材质**——光斑贴片在运行时加（A-1 材质族：`unshaded` + `fog_disabled` + `blend_mix`）
- **坐标**：导出 GLB 保持 Y-up；单资产原点在底面中心（摆放系统 `_add_prop()` 的约定）
- **单资产面数红线**：以 spec 各清单的面数预算列为验收硬口径；超标的先进 remesh，压不到的回炉重生成，不进 Godot

## 与 Dev Driven 的验收关系

| 管线产物 | 验收依据（Dev Driven 内） |
|---|---|
| 建材/植物几何与色值 | `quanzhou-spec.md` §3、`cape-cod-spec.md` §2、`quanzhou-seychelles-art.md` §7–§8 |
| 风格一致性 | `prompt-library.md` 风格前缀铁律 + 四地概念图（`strategy/concept-art/v2-locations/`，已齐四地） |
| 性能 | `godot-web-perf.md` §2 性能预算硬上限 |

## 待 Benja 补充

1. Meshy API key（Pro 档）与 Tripo API key → 填入 `tool-connections.md` 占位处
2. 决定是否开通 Hyper3D（混元 3D）账号作为第三对照
3. 生成积分预算：Meshy 按积分计费，四地建材+植物约 40+ 资产，建议先跑泉州组（13 复用改造 + 5 新增）试管线，再批量
