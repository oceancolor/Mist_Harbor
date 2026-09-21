# 任务清单 T01–T48

使用方式：按顺序做；每条任务都包含 **目标 / 时长 / Agent 提示词 / 验证 / 产出 / 坑**。
"验证"不过就不要往下走——本书所有任务都建立在上一层验证通过之上。

> 约定：`🤖` = 贴给 Agent 的提示词；`✅` = 验证命令；`📦` = 应出现的文件变更。

---

## 阶段一 · 起步（T01–T06）

### T01 克隆并跑通基线 · 20 min
- 目标：在本机跑通工程并通过全部自动化测试。
- 🤖 `帮我检查本机是否具备运行条件：Godot 4.7 在 D:\Godot_v4.7、Python 3.11+、Node 18+；然后执行 python tools/dev.py test 并把结果贴给我。`
- ✅ `python tools/dev.py test` → `WORLD_TEST_RESULT passed=NN failed=0` 且 `SCENE_SMOKE_RESULT failed=0`
- 📦 无（只生成 `logs/`）
- 坑：`.codebuddy/local/tools.json` 是本机路径、被 git 忽略，换机器必须重建。

### T02 配置两台 MCP（Blender 远程 / Godot 本地）· 25 min
- 目标：让 Agent 能驱动远程 Blender 建模与本地 Godot 导入。
- 🤖 `把这两个 MCP 服务写进 C:\Users\<你>\.codebuddy\mcp.json：web-cb-blender-pilot（streamableHttp）与 godot（本地 npx @coding-solo/godot-mcp，GODOT_PATH 指向 4.7 console 版）。写完后用探针列出两边工具。`
- ✅ 两边 `tools/list` 分别返回 5 个与 14 个工具
- 📦 用户级 `mcp.json`（不入仓库）
- 坑：远程 Godot pilot 只能写 UTF-8 文本，传不了 GLB → Godot 侧必须用**本地** MCP。

### T03 启动游戏并确认可玩 · 10 min
- 🤖 `启动游戏（python tools/dev.py run），并告诉我窗口里应该看到什么。`
- ✅ 窗口出现岛屿；左键能放置建材；`R` 旋转、`B` 拆除、`N` 昼夜可用
- 📦 无
- 坑：Godot 可能把导出目录当资源扫描 → 导出目录必须在工程之外（T33 解决）。

### T04 读懂工程骨架 · 30 min
- 目标：能说出 `project/` 下每类文件的作用。
- 🤖 `给我画一张工程结构图：project/ 下哪些是源码、资源、数据、教学文档、测试；哪些会被打进导出包（看 export_presets.cfg 的 include/exclude 过滤）。`
- ✅ 能回答"为什么 `art/` 不会进包"
- 📦 笔记（你的 `docs/play-observations.md` 或课程笔记）

### T05 第一次改代码并提交 · 25 min
- 目标：建立"小步提交 + 每次跑测试"的肌肉记忆。
- 🤖 `把 project/data/palette.json 里某条 tip 改成你自己的话，然后跑 python tools/dev.py test，通过后用一句中文提交。`
- ✅ `git log -1` 有记录；测试仍全绿
- 📦 `project/data/palette.json`
- 坑：改中文文案后字体可能缺字 → 跑 `python tools/build_font_corpus.py`（T31 详述）。

### T06 建立你的验收习惯 · 20 min
- 目标：写一条属于你自己的验收断言。
- 🤖 `在 project/tests/test_world.gd 里新增一条断言：验证"水面可以直接打地基"；跑测试确认它通过。`
- ✅ 测试数 +1 且全绿
- 📦 `project/tests/test_world.gd`

---

## 阶段二 · 资产（T07–T15）

### T07 认识程序化建模脚本 · 30 min
- 🤖 `讲解 project/art/generate_harbor.py 的结构：材质、box/cylinder/prism/ico 四种构造器、为什么用 sRGB→线性 转换。`
- ✅ 能独立写出一个"立方体 + 材质"的 bpy 脚本

### T08 远程 Blender pilot 的契约 · 25 min
- 🤖 `调用 blender_doctor，把返回的模板脚本存到 .codebuddy/local/，并总结它对脚本的四条硬约束。`
- ✅ 能复述：单文件内联、米制 Z-up、只建几何与材质、导出由执行器负责

### T09 提交第一个远程建模任务 · 30 min
- 🤖 `用 tools/asset_pipeline.py build --id barrel 走完整流程，把每一步输出解释给我听。`
- ✅ `project/assets/models/barrel.glb` 出现且 sha256 校验通过
- 坑：任务 id 重复会被拒 → 脚本改了会生成新 id；失败用 `--retry`

### T10 资产管线解剖 · 40 min
- 🤖 `逐行讲解 tools/asset_pipeline.py：提交→轮询→下载→写 manifest→Godot 导入→注册建材表。`
- ✅ 能说出 manifest 里 `godot_size` 三个数字分别是什么

### T11 迁移 lamp 与 tree · 35 min
- 🤖 `把 generate_harbor.py 里的 lamp 与 tree 移植成 tools/art/ 下的独立脚本，并跑管线。`
- ✅ 面数/高度与原件一致（lamp 134/1.25m，tree 72/1.80m）

### T12 复杂结构：roof 与 arch · 45 min
- 🤖 `移植 roof（棱柱+檐口）与 arch（9 段拱券手工网格），跑管线。`
- 坑：`dimensions` 赋值后 `matrix_world` 要等依赖图刷新 → 断言前 `view_layer.update()`

### T13 最复杂三件：cottage / windmill / flower · 60 min
- 🤖 `移植 cottage（门窗+棱柱屋顶）、windmill（4 片旋转叶片）、flower（9 组花叶）。`
- ✅ 三件全部与原件面数一致（272 / 276 / 560）

### T14 beacon 与全部资产复核 · 30 min
- 🤖 `移植 beacon，然后运行 python tools/asset_pipeline.py list 复核 9 件资产。`
- ✅ 9 件全部有 `(tools/art)` 标记

### T15 建立资产规范 · 25 min
- 目标：写下你自己的"新资产规范"（命名、原点、占格、面数上限、材质数）。
- 📦 `course/notes/asset-spec.md`（你的笔记）

---

## 阶段三 · 玩法系统（T16–T27）

### T16 放置规则与碰撞 · 35 min
- 🤖 `讲解 world_model.gd 的 can_place：边界、高度、重叠、支撑四组规则，并为"空中不能悬空放置"加一条测试。`

### T17 撤销栈与命令模式 · 40 min
- 🤖 `讲解 _record/undo/redo，为什么新操作会清空重做分支；加一条断言验证这个行为。`

### T18 存档格式与原子写入 · 35 min
- 🤖 `讲解 to_document/load_document：为什么先写 .tmp 再 rename；验证"失败的加载不破坏当前世界"。`

### T19 三存档槽 · 45 min
- 🤖 `为 world_model 增加 slot_path/save_slot/load_slot/delete_slot/slot_info（3 个槽），并让旧的单存档自动迁移到槽 1。`
- ✅ 8 条槽位断言通过
- 坑：测试要用独立 model 实例，否则会污染主 model 的撤销栈

### T20 存档槽 UI · 40 min
- 🤖 `在"作品管理"里加存档槽面板：显示件数/SEED/时间，支持保存/读取/清空，并标注当前槽。`

### T21 章节化引导 · 40 min
- 🤖 `把 data/objectives.json 升级为三章结构，新增第三章目标（材料架/海岸线/留住夜色），面板只显示当前章节。`
- ✅ 面板显示"第一章 · 落脚 0/2"这类进度

### T22 成就系统 · 45 min
- 🤖 `新增 data/achievements.json 与 scripts/achievements.gd（玩家级持久化），解锁时弹出提示。`
- 坑：**Web 端 IndexedDB 上，成就文件在存档之后写会丢存档** → 只能在存档前/退出时落盘

### T23 目标与成就总览面板 · 30 min
- 🤖 `新增"目标与成就"面板，列出三章目标完成度与 8 项成就进度；在浏览器验收里加一条"面板能打开"的断言。`
- ✅ 浏览器验收 21 → 23 条

### T24 截图与分享 · 35 min
- 🤖 `实现 C 键截图：隐藏 HUD、抓帧、存 user://photos/，Web 端触发下载；夜拍计入统计。`

### T25 拍照模式与快捷键体系 · 20 min
- 目标：整理并记忆全部快捷键，写一份速查卡。

### T26 数值与平衡（初步）· 30 min
- 🤖 `分析 12000 上限、160 步撤销、14 种建材这些数值是否合理，给出压力测试方案。`

### T27 玩法系统的可测性 · 25 min
- 目标：为你的每个玩法特性写至少一条断言。

---

## 阶段四 · 观感（T28–T32）

### T28 字体子集治理 · 45 min
- 🤖 `讲清 harbor-sc.ttf 是子集字体，新增中文文案为什么会出豆腐块；用 tools/build_font_corpus.py 修复，并验证原字形不变。`
- ✅ `小/屋/灯/塔` 坐标 IDENTICAL；缺字扫描 0

### T29 图标：手绘 vs GLB 缩略图 · 50 min
- 🤖 `实现运行时 GLB 缩略图（scripts/model_thumbnail.gd），并保留 ModelThumbnails.ENABLED 一键回退。`

### T30 图标打光与场景一致 · 40 min
- 🤖 `把缩略图灯光改成与 build_world.gd 一致（暖阳+冷补光+线性色调映射），相机改成与游戏同角度正交投影。`
- 坑：默认白光 0.9 + 主光 2.6 会过曝发"塑料感"

### T31 面板密度与信息层级 · 30 min
- 🤖 `目标面板从 9 条改为只显示当前章节（2-4 条），完整进度放进总览面板。`

### T32 配色一致性审查 · 30 min
- 目标：整理全项目色值表（INK/MUTED/PAPER/ACCENT + 场景环境色），检查新增 UI 是否越界。

---

## 阶段五 · 发行（T33–T39）

### T33 导出目录移出工程 · 25 min
- 🤖 `把导出目录从 project/build 改到仓库根 build/，并同步 export_presets.cfg 与文档。`
- ✅ Godot 启动日志里不再出现 `index.png` 扫描

### T34 安装 4.7 导出模板 · 30 min
- 🤖 `用 tools/fetch_templates.py 分块续传下载模板包并解包到 %APPDATA%\Godot\export_templates\4.7.stable。`
- 坑：1.2GB 单次下载会超时 → 分块续传

### T35 Web 导出与三层验收 · 35 min
- ✅ 23/23 浏览器断言

### T36 Windows 单文件导出 · 30 min
- 🤖 `新增 Windows Desktop 预设（embed_pck=true）与 dev.py export-windows，产出单个自包含 exe 并验证可独立启动。`

### T37 exe 体积从哪来 · 25 min
- 目标：读懂 104MB 的构成，列出可裁剪项（自定义编译、压缩、裁剪模块）。

### T38 Android / iOS 前景 · 30 min
- 目标：列出前置（JDK17、Android SDK、构建模板、macOS）与风险，形成待办。

### T39 性能基线与预算 · 40 min
- 🤖 `设计一个性能预算表（帧率、Draw Call、内存、包体），并在低端卡（GT 630）上测出基线。`

---

## 阶段六 · 质量与协作（T40–T44）

### T40 三层测试体系 · 40 min
- 目标：说清引擎断言 / 场景冒烟 / 浏览器交互各自负责什么。

### T41 让"数量断言"不再脆 · 30 min
- 🤖 `把写死的"13 种建材""8 个 GLB"改为从 palette.json 推导，并说明为什么这样更好。`

### T42 失败可观测 · 35 min
- 🤖 `给 tools/asset_pipeline.py 增加失败诊断（拉取远端日志打印）与 --retry。`

### T43 Git 工作流 · 30 min
- 目标：分支策略、提交粒度、提交信息模板、改代码前先跑测试。

### T44 文档即契约 · 25 min
- 目标：TOOLCHAIN.md / requirements.md / 本章程 的同步规则。

---

## 阶段七 · 运营（T45–T48）

### T45 写一场直播脚本 · 45 min
- 目标：按 `live/L1.md` 模板写你自己的一场。

### T46 作业与批改 rubric · 40 min
- 目标：为每个阶段设计可机器验证 + 人工评审的双重标准。

### T47 版本发布流程 · 30 min
- 目标：版本号、changelog、发布检查单。

### T48 社区与内容更新 · 30 min
- 目标：把"新加一件建材"做成社区可参与的贡献流程。

---

## 附：任务依赖图（简化）

```
T01 → T02 → T03 → T04 → T05 → T06
                    └→ T07 → T08 → T09 → T10 → T11 → T12 → T13 → T14 → T15
T16 → T17 → T18 → T19 → T20 → T21 → T22 → T23 → T24 → T25 → T26 → T27
T28 → T29 → T30 → T31 → T32
T33 → T34 → T35 → T36 → T37 → T38 → T39
T40 → T41 → T42 → T43 → T44
T45 → T46 → T47 → T48
```
每完成一个阶段，跑一次三层验证并打一个 git tag（例如 `course-stage-1`）。
