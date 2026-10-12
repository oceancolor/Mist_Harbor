# 本机工具链基线（2026-09-15 建立）

## 2026-10-10 分支整合候选

- 起点：`origin/main` 的 `ac03d3f`；工作分支 `integrate/main-design-20261010`。主线 `strategy/` 文档保持原样，不用试验分支文档覆盖。
- 采用 `ltld` 的 `core/LocationProfile`、唯一地点注册表、多格占位、四态光照、光斑与地点资产；采用 `cursor_work` 的连接签名与生成适配器。没有引入第二套 `locations.json` / `location_profile.gd`。
- 主线 `layer` / `relief` 保留；`lamp` 是 built，`wood` / `brick` 也是 built。地点构件子集限制新建材，完整定义集用于旧档兼容。
- 水面折射的 depth 遮挡保护（2026-10-12）：折射（`screen_tex` + SCREEN_UV）原先无遮挡判断，会把露在水面之上、比水面更近的岛体与建筑当成水底透出来。已加入深度纹理比较（`depth_guard`），并用 `--waterdebug=2/3` 做 A/B 对比。🔴 实测限制：Web（gl_compatibility）下 `hint_depth_texture` 恒为 0，强行开启会把折射整体关掉（画面反而变亮失真），因此 Compatibility 自动关闭保护、桌面后端才启用；桌面效果**尚未实拍验证**，Web 侧 A/B 已确认无回归。
- 日落调参面板（2026-10-11）：`调黄昏` 顶栏按钮（也在作品管理菜单）打开 Townscaper 式色板——阳光/水平线/天顶/环境光四个色块 + 阳光强度/环境光/太阳高度/太阳经度四条拉杆，拖动即时生效；「恢复地点默认」回到 v4.3 定值。默认值唯一来源是 `HarborLocationProfile`（`scripts/sunset_tuning.gd` 只产出/校验数据，不依赖渲染实现，将来换水光栈不用重写）。调参是**作品的一部分**：存进存档槽、随导出 JSON 带走，旧档无该字段按地点默认渲染；置 dirty 提示保存。
- 🔴 Godot 4.7 Web 导出 lambda 坑（本轮踩实）：`_show_dialog` 里对 lambda 形态的任何偏离——multiline lambda 后跟第四个实参、先赋值再传参、捕获函数参数、`.bind()`——都会触发 WASM 层 "function signature mismatch"：按钮无反应且每 0.25s 的 QA 快照冻结，后续所有浏览器断言连锁失败。只有与基线完全相同的形态（multiline、捕获循环局部变量、后面不跟实参）可用；对话框 QA 键因此全部撤除，自动化测试不点对话框（日落走顶栏按钮、地点走 URL 参数、关窗用 Esc）。另外快照若新增日落类字段也会触发同样的桥崩溃——日落状态改走 `window.harborSunset` 独立通道。
- 分支策略（2026-10-11）：`integrate/main-design-20261010` 作为主线推进，`ltld` / `cursor_work` 转为技术验证与设计探索分支。已按能力择取：ltld 的 `core/` 渲染底座与四地系统、cursor_work 的连接签名与生成适配器均已化入主线；两套同名 `HarborLocationProfile` 只保留 ltld 一份，第二份 `locations.json` 不引入。计划中的后续：① 用 cursor_work 的天空/水体/天体整套替换 ltld 的 `daylight.gd`，并把 ltld 水体的折射/岸沫/波光/碎浪效果移植过去；② 将 `world_model` 统一到 ltld 的探索（schema v2 + 地点槽 + 地形路径），并补主线已修的旧档迁移与边界校验；③ ltld 水面折射化入并补 depth 遮挡保护。
- 从 ltld 收进的实验记录：`docs/experiment-notes/ltld-control-manifest.md`（防复发清单，含已知偏离：A-1 族的 `fog_disabled` 当前未满足）、`docs/experiment-notes/ltld-optimization-spec-2026-09-27.md`（渲染演进与踩坑，§3 是采纳 cursor 天体方案的依据）。
- 资产清单回归：模型测试新增「manifest 的 bytes/三角数必须与磁盘 GLB 一致、每条都要有 bounds」（曾出现清单记 15980 字节、实际 240684 字节的失真）。实测当前 44 条全部一致，无需刷新工具。
- 三类构件重构（2026-10-11）：界面分类改由 `layer` 唯一推导——地形=天然岩土与地貌，自然=植物与动物，建筑=一切人造物。木栈道、陶砖、浮标、灯移入「建筑」；原先没有对应分页、玩家选不到的塞舌尔巨石/楔石（核心）、象龟（生物）、Cape Cod 三座灯塔（光源建筑）分别归入地形/自然/建筑。`stone` 是全岛生成的天然基岩，改名为岩石 / 花岗岩礁 / 白浮岩 / 花岗岩基岩 / 冰碛砾石，不再叫读来像人造地基的「石基」；`id` 不变，旧档无需迁移。建材栏按件数自适应宽度（圣托里尼建筑 11 件），只有前 9 件有数字快捷键。主线教程站中涉及旧分类的章节待候选合入后同步。
- 新设计先落泉州地形切片：受限随机生成、内部重试、独立 mudflat 地形件、跨材质顶点交融、平整建造接口、刺桐邻接聚丛。其余三地保留为试验实现，不视为通过主线新地形验收。
- `schema_version=2` 保持三维坐标记录结构，接受旧 v1 文档；只读旧档中保存的实体，不重新生成旧地形。新增 `geo_meta_version` / `generator_version`，旧档默认为 0；三个旧槽只迁移到泉州且不覆盖已有槽。
- 修复了试验分支的相机重复更新、模型/机制引用环、连接方向和自身占位误判、切换地点缩略图串图。地形仍为单 surface，采用块几何缓存和局部失效；道具使用 MultiMesh 合批。
- `tools/sync_location_profiles.py` 检查水光值与主线现行表的一致性；`--write` 同步机器配置。`tools/audit_model_assets.py` 重测 GLB；导入资产许可标记为待来源复核，不能把全库一概视为 CC0。
- `python tools/dev.py test` 包含原模型测试、场景测试、新整合测试、参数源校验与离线 provider 测试。`python project/tests/browser_integration.py` 自带临时 HTTP 服务，验证四地点、四态、建造撤销、浏览器存档恢复；产物在 `.codebuddy/artifacts/integration/`。
- Blender QA：`tools/blender_qa.py` 对隔离 GLB 做世界变换归一、米制缩放、底部居中和显式接触面整平，写平面偏差与几何回执；默认不减面、不覆盖原始模型。已用本机 Blender 对木桶样本验证。平面达标不等于两件任意 AI 形状已能无缝拼合，仍需接口轮廓评审。
- AI 草稿入口：`tools/asset_pipeline.py ai-draft --id <id> --provider tripo --prompt <描述>`，结果只进 `.codebuddy/local/incoming/`。混元适配器仍依赖显式配置的桥接服务，并非已验证的官方 API 接入。本轮未调用付费生成服务。
- 待人工验收：20 种子联系图 `terrain-20-seeds.png` 与统计 JSON。C1–C4 范围仍是工程初值，不能将机器通过冒充 M1 的辨识盲评；当前平均尝试 6.3 次，尚高于设计建议的 5 次。Q-12 真机帧耗时、内存和包体门槛仍需校准。
- 本轮不更新教程站或游戏线上部署；候选代码须经视觉与性能复核再提交/合入远端主线。
- 候选验收实测：原模型 56 项、新整合测试 365 项、场景测试与 16 项 provider 离线测试通过；旧浏览器套件适配后 24/24，通过四地点浏览器集成及保存刷新验证。Web / Windows 导出成功，尚未验收 Windows GUI 或移动真机。
- 补审修复：切地点前可保存/放弃/取消；保存失败或目标坏档不替换当前模型、渲染和数据；坏新槽不回退旧单档，启动坏档明确报错并保留原文件。光斑只缩放局部平面，不再缩放世界中心。新增对应场景回归；无头驱动下测生产变换函数，不用 dummy RenderingServer 的实例回读冒充 GPU 验证。
- AI 下载保护：API/下载只接受 HTTPS，拒绝重定向；Tripo 需事先通过 `TRIPO_DOWNLOAD_HOSTS` 配置已核实的精确 CDN 主机名（逗号分隔、不填 URL、不用通配符），未配置不会发起付费任务。JSON 上限 1 MiB / 草稿传输上限 64 MiB 是工具防护，不是面数预算；限量读取、GLB 容器检查、临时文件完成后原子发布且不覆盖目标。返回摘要，不记录签名下载 URL；下载不携带 Tripo API 密钥。混元仍只有待实接的 HTTPS 桥契约。
- 补审未关闭项：泉州连通链的端点自遮挡及独立关系误算、Cape Cod 熄灯覆盖统计、圣托里尼悬挑锚固追溯尚需正反例和机制修复；四地能加载/存档不等于这些玩法已经验收。现 StandardMaterial3D 光表现也尚未证明满足 A-1 的禁雾要求。继续保持试验状态，不将候选直接发布。
- 固定 QA 种子 240910 的浏览器样本（Chromium 软件渲染，非真机性能承诺）：四地 draw call 为 136 / 142 / 161 / 206；Cape Cod 仍高于建议的 200。冷构建地形约 0.9–1.6 秒；一次保存后的缓存重建约 384 ms（blocks_rebuilt=0，不能当成首次编辑耗时）。几何缓存未替代整岛上传与碰撞重建，仍需继续剖析。
- 资源审计：44 个 GLB，6,195,580 字节、46,520 三角面；Web PCK 约 28.5 MiB，包含地点资源和导入纹理，不能与原九件资产样板体积混比。历史纹理副本及按地点加载仍需整理。
- 本地候选试玩：`http://127.0.0.1:8198/index.html`（仅绑定本机）；固定泉州 QA 入口可加 `?qa=1&nomenu=1&seed=240910`。未提交/未推送本轮代码。

## 版本锁定

| 工具 | 版本 | 路径 | 说明 |
|---|---|---|---|
| Godot | **4.7.stable**（锁定） | `D:\Godot_v4.7\Godot_v4.7-stable_win64_console.exe` | 2026-09-15 从 4.4 升级；`project.godot` 的 `config/features` 已改为 `4.7`，两套测试在 4.7 下全绿 |
| Godot（回滚用） | 4.4.stable | `D:\Godot_v4.4\` | 仅保留二进制以便回滚；4.4 导出模板仍在，但工程已声明 4.7，不要再退回打开 |
| Blender | 4.2.0 | `D:\Blender\blender-4.2.0-windows-x64\blender.exe` | 已安装 MCP 插件：`blender_mcp.py`（`%APPDATA%\Blender Foundation\Blender\4.2\scripts\addons`） |
| Node / npm | 22.17 / 11.6 | — | godot-mcp 要求 ≥18 |
| Python | 3.14.2（`D:\Python314`） | — | `C:\Python311\python.exe` 已损坏，不要用 |

引擎路径记录在 `.codebuddy/local/tools.json`（**被 .gitignore 忽略**），模板见 `tools/tools.example.json`，换机器时复制并改路径。

## 常用命令

```powershell
python tools/dev.py test          # 导入 + 模型单测(42) + 场景冒烟
python tools/dev.py editor        # 打开编辑器
python tools/dev.py export-web    # Web 导出到仓库根 build/（不在 Godot 工程内）
python tools/dev.py export-windows  # Windows 桌面版到 build-win/（单个自包含 exe，pck 已内嵌，可独立启动）
python tools/dev.py preview       # 本地预览 8188
python tools/dev.py package       # 打 source/seed/web 三个 zip
python tools/blender_mcp.py       # 启动 Blender 并自动连上 MCP（需保持窗口）
python tools/fetch_templates.py   # 换机器时下载 Godot 4.7 导出模板（分块续传，反复执行至 complete）
```

三层验收（提交前至少跑前两层）：

```powershell
python tools/dev.py test                 # 模型单测 + 场景冒烟（引擎内）
python tools/dev.py export-web           # Web 导出到仓库根 build/
python -m http.server 8184 --bind 127.0.0.1 --directory build
python project/tests/browser_smoke.py --base http://127.0.0.1:8184/index.html   # 真实浏览器 21 项
```

## MCP

配置文件：`C:\Users\benjamin\.codebuddy\mcp.json`（用户级）。

### 同事封装的远程（streamableHttp）— 2026-09-15 实测可用

| 名称 | 端点 | 服务端 | 工具 |
|---|---|---|---|
| `web-cb-blender-pilot` | `http://21.130.210.97:18765/mcp` | Linux x86_64，**Blender 5.2.1**，cycles-cpu 预览 | `blender_doctor / blender_submit / blender_observe / blender_cancel / blender_artifacts` |
| `godot-mcp` | `http://21.130.210.97:28766/mcp` | Linux x86_64，**Godot 4.7.1**（templates 4.7.1） | `godot_project_info / godot_create_project / godot_apply_files / godot_import / godot_run_scene / godot_export_web / godot_package_source / godot_artifacts` |

**远程 Blender 工作流（异步作业）**：`blender_doctor` 取 `authoring.template.script` → 按模板写 bpy 脚本（米制/Z-up/只建几何与材质，导出与贴图由执行器负责）→ `blender_submit`（request: `task_id`(1..64 唯一) / `asset_id` / `script_path='script.py'` / `timeout_seconds`，脚本内联 ≤256KiB）→ 轮询 `blender_observe` → `blender_artifacts` 拿 GLB + 实际回导预览 PNG + receipt（下载需带同一 Authorization，落地后核对 sha256）。

实测（`tools/art/barrel.py`，任务 `mist-harbor-barrel-v1`）：632 三角面 / 2 材质 / 4 mesh / GLB 44,580B / 预览 PNG 正常，产物 sha256 全部校验通过。

**远程 Godot 的硬限制（当前无法构建本项目）**：
1. 服务端是 **4.7.1**，本地已升到 **4.7.stable**（仍差一个补丁版本，`godot_project_info` 是做 4.7.1 fail-closed 诊断）。
2. `godot_apply_files` **只接受 UTF-8 文本文件**、只允许相对路径 → 本项目的 8 个 GLB、`harbor-sc.ttf`、`icon.svg` 等二进制资产传不上去。
3. 它操作的是**服务器上自带的工程根目录**（当前有同事的样例工程与 build 产物），不是本地 `E:\Mist_Harbor`。

### 当前取舍：Godot 用本地，Blender 用远程（2026-09-15）

- **`godot`（本地 stdio，启用）**：`npx -y @coding-solo/godot-mcp`，`GODOT_PATH=D:/Godot_v4.7/Godot_v4.7-stable_win64_console.exe`，`cwd=project`。
  14 个工具（`launch_editor, run_project, get_debug_output, stop_project, get_godot_version, list_projects, get_project_info, create_scene, add_node, load_sprite, export_mesh_library, save_scene, get_uid, update_project_uids`）。
- **`godot-mcp`（远程，停用）**：服务端锁 4.7.1，且 `godot_apply_files` 只能写 UTF-8 文本 → 传不了 GLB / 字体 / 图标，构建不了本项目。等支持二进制上传再启用。
- **`web-cb-blender-pilot`（远程，启用）**：所有新资产都走它，见「资产管线」。
- 本地 `blender` stdio 条目已移除，`tools/blender_mcp.py` 保留备用（需同时加回 `blender` 条目）。

调试脚本（均在 `.codebuddy/local/`，不入库）：`probe-http-mcp.mjs`（列工具/出 schema）、`call-http-mcp.mjs`（调单个工具）、`blender_pilot_run.mjs`（提交→轮询→下载产物）。

## 资产管线（`tools/asset_pipeline.py`）

一条命令完成"造资产 → 进工程"：

```powershell
python tools/asset_pipeline.py list                       # 资产清单 + 是否已注册
python tools/asset_pipeline.py build --id barrel --name 木桶 --category 建筑 \
       --color b07d4f --tip "码头边的橡木桶，可以一只只堆起来。"
```

流程：`tools/art/<id>.py`（受版本控制的 bpy 脚本）→ 远程 `web-cb-blender-pilot` → 产物落盘
`project/assets/models/<id>.glb`（sha256 校验）、`project/art/previews/<id>.png`、
`project/art/provenance/<id>.json`（任务 id/脚本摘要/三角面）→ 更新
`assets/models/manifest.json`（bounds/triangles/bytes）→ 本地 Godot（tools.json 锁定版本）headless 导入生成
`.import` → 写入 `data/palette.json` 成为可放置建材（`--no-register` 可只出资产不注册）。

约定：脚本按 pilot 模板写（米制 / Z-up / 只建几何与材质，导出与预览由执行器负责）；
任务 id = `mist-harbor-<id>-v<n>-<script sha256 前 8 位>`（远端拒绝重复 id）。
凭据在 `.codebuddy/local/pilot.json`（不入库），模板 `tools/pilot.example.json`。
两个数量断言（材质数、GLB 数）已改为从 `palette.json` 推导，新增资产无需改测试。

## 给同事 pilot 的反馈（2026-09-15）

1. **二进制资产上传**（Godot pilot）：`godot_apply_files` 仅 UTF-8 文本 → GLB / TTF / SVG 传不上去。
   *当前绕过*：Godot 侧改回本地 MCP；pilot 端待支持后再切回。
2. **引擎版本**（Godot pilot）：服务端 4.7.1，本地已升到 4.7.stable，仍差一个补丁版本；
   建议服务端同时提供 4.7.stable，或允许客户端指定版本。
3. **产物 `role` 字段**（Blender pilot）：**已采纳**。清单每项建议带
   `role ∈ {model/asset, preview, receipt/inspect, log}`；本仓库管线已按 role 优先、
   缺失时回退后缀的方式实现（`tools/asset_pipeline.py` 的 `pick_artifact`）。

## 已知坑

- ~~**4.7 导出模板未安装**~~ 已解决：模板已装到 `%APPDATA%\Godot\export_templates\4.7.stable`
  （`python tools/fetch_templates.py` 分块续传下载 tpz，再解包 `templates/` 到版本目录）。
  换机器时重复该流程，或直接用 Godot 编辑器自带的模板下载。
- **uv 在本机不可用**：`uvx` / `uv venv` 创建 Windows trampoline 时被拦截（拒绝访问）。blender-mcp 改用标准库 `python -m venv .venv-mcp` + pip 安装。
- **Blender 不能后台跑 MCP**：插件明确拒绝 `blender -b`（主循环定时器不执行，命令会挂），必须 GUI，见 `tools/blender_mcp_autostart.py`。
- **Blender 遥测**：已通过 `BLENDER_MCP_DISABLE_TELEMETRY=true` 关闭（MCP 条目里设置）。
- 旧路径 `f:/web-cb/...`（原 web-cb 工具链）已不再依赖。

## 尚未完成（商业化路线）

1. ~~版本控制~~ 已完成：`c461437` 起，分支 `main`，远端 `origin = https://github.com/oceancolor/Mist_Harbor`（尚未 push）。
2. ~~资产管线~~ 已完成：`tools/asset_pipeline.py`（远程 Blender pilot → GLB / manifest / Godot 导入 / palette 注册），首件资产 `barrel` 已进游戏。
3. ~~存量资产迁移~~ 已完成：9 件资产全部在 `tools/art/<id>.py`，`art/generate_harbor.py` 仅作历史参考。

## 暂缓（后续专项，不阻塞特性开发）

- Web 体积优化（37.7MB wasm、加载进度页）
- Android / iOS 导出预设（Windows 桌面预设已完成；Android 还需要 JDK17 + Android SDK + 构建模板，iOS 需要 macOS）
- 中文文案变更后的字体：`tools/build_font_corpus.py` 保证**基准字形不变**、只补缺字

**当前优先级：游戏特性与内容量产。** 上述两项留给专项优化阶段。

## 版本控制约定

- 提交前跑 `python tools/dev.py test`（模型单测 42 + 场景冒烟）。
- 不入库：`.codebuddy/`（本机工具路径与产物）、`logs/`、`**/build/`、`**/.godot/`、`.venv-mcp/`。
- 换机器时复制 `tools/tools.example.json` 为 `.codebuddy/local/tools.json` 并改路径。
- 二进制资产（GLB / TTF / .blend）按 `.gitattributes` 以 binary 处理，不做行尾转换。
