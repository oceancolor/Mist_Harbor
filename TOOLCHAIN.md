# 本机工具链基线（2026-09-15 建立）

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

## Tripo（AI 3D 生成 API）— 2026-09-26 首次接入

- 凭据：`3D tools config/3Denv.txt`（**已在 .gitignore 中忽略，勿提交**）；`--save` 后另存 `.codebuddy/local/tripo.json`（不入库）。
- 生效版本：**v3**，`base_url = https://openapi.tripo3d.ai/v3`，鉴权 `Authorization: Bearer {api_key}`。
  v2（`api.tripo3d.ai/v2/openapi`）对该 key 不可用（路径 404）。
- 实测可达端点：`GET /v3/account/balance`（OK）、`POST /v3/tasks/list`（body `taskIds: [...]`）、`GET /v3/tasks/{task_id}`（id 为 UUID）。
- 待用（文档登记，未实测）：`POST /v3/files` 上传、`POST /v3/generation/text-to-model`、
  `POST /v3/generation/image-to-model`、`POST /v3/models/convert`（转 glb）。
- 自检：`py tools/tripo_check.py [--save]`；打样：`py tools/tripo_gen.py --name <id> [--task-id ...] [--wait N]`。
- **站点不互通**：国际站 `openapi.tripo3d.ai` 与国内站 `openapi.tripo3d.com` 账号/key 各自独立
  （本机 key 在国际站有效，在国内站返回 `Invalid API key`）。换站写 `.codebuddy/local/tripo.json` 的
  `base_url` 或设 `TRIPO_BASE_URL`。
- **积分体系**：网页版会员积分（`www.tripo3d.ai`）与 API credits（`platform.tripo3d.ai`）**不互通**，
  两者余额需分别充值。API 侧 `balance=1000`（2026-09-26 充值）。
- **v2 已退役公告**：2026-11-01 起 v2 端点停用，本项目全走 v3，无需改动。

### 首次打样（2026-09-26，成功）

```powershell
py tools/tripo_gen.py --name buoy --wait 20      # 提交（先短等，拿 task_id）
py tools/tripo_gen.py --name buoy --wait 120     # 续轮询 + 下载产物（可省 --task-id，meta 里有）
```

打样台账（均为 `P1-20260311` / texture+pbr / `auto_size=true`，**单价 40 credits/次**，每件约 80–150 秒）：

| 名称 | face_limit | 三角面 | 顶点 | GLB 体积 | 贴图 | task_id |
|---|---:|---:|---:|---:|---:|---|
| `buoy` | 3000 | 2767 | 2265 | 2,890,056 B | 3 | `d99a33f6-…` |
| `buoy_low` | 800 | **736** | 717 | 2,365,724 B | 3 | `df824254-…` |
| `lighthouse` | 3000 | 2741 | 4136 | 1,800,052 B | 3 | `bdf2f8a8-…` |
| `buoy_s42b` | 3000, seed=42 | 2492 | 2210 | 2,239,888 B | 3 | `ef692fcf-…` |
| `buoy_s42b_low` | 800, seed=42 | **722** | 849 | 1,907,820 B | 3 | `113aa564-…` |

结论：
1. `face_limit` 对面数**线性有效**（同 seed 下 3000→800：2492→722，且**轮廓/贴图保持一致**，仅细节简化）。
2. 但 GLB **体积主要由 3 张 PBR 贴图决定**：面数 -71% 体积只降 15%（2.24→1.91 MB）。压体积必须动贴图
   （降 `texture_quality` / 关 `pbr` 只留 base_color / 转换时缩贴图）。
3. **seed 教训**：要可复现/同形减面，必须同时固定 `image_seed`（内部 text2image 参考图）+ `model_seed`
   + `texture_seed`。只固定后两者时参考图每次随机，几何完全不同（`buoy_s42`/`buoy_s42_low` 即废案）。
   `tripo_gen.py --seed` 现已同时设三个 seed。

产物在 `.codebuddy/local/tripo/samples/<name>/`（镜像到 `tripo_samples/`，已 gitignore）。

产物分三个 role 落盘：`*_model.glb`、`*_preview.webp`（渲染预览，注意是 webp 不是 png）、
`*_reference.jpeg`（text2image 参考图）。对比现有手工资产 `barrel`（632 面），Tripo 件面数与体积都偏大，
进工程前建议先跑 `/v3/mesh/decimate` 减面或用 `--face-limit` 调小。

### Tripo 进度状态（跨会话以本节为准，改完请就地更新）

**已完成**
1. key 配置与连通性验证（`tools/tripo_check.py`，v3 生效，国内/国际站点已区分）。
2. 生成脚本 `tools/tripo_gen.py`（提交 / 轮询 / 下载 3 类产物 / GLB 统计 / meta 落盘 / 等额度自动开跑）。
3. 五件打样完成（`buoy` / `buoy_low` / `lighthouse` / `buoy_s42b` / `buoy_s42b_low`），各 40 credits，
   余额 1000 → **720**（其中 `buoy_s42` / `buoy_s42_low` 因未固定 image_seed 为废案，不计入有效对比）。
   产物在 `.codebuddy/local/tripo/samples/<name>/`，镜像 `tripo_samples/`（已 gitignore）。
4. 接入工程（2026-09-26 ~ 27，另一 session 起步 + 本 session 收尾）：泉厦四件
   `loc_qz_bld_mansion` / `loc_qz_bld_oyster` / `loc_qz_nat_banyan` / `loc_qz_nat_zayton`
   （源样 `qz_*_hf`，face_limit 3000）与 `loc_cc_prop_buoy`（源样 `buoy_s42b_low`，--flat 纯色）
   均已落 GLB + palette 注册 + Godot 导入。
5. **统一入口**（2026-09-27）：`asset_pipeline.py` 新增两个子命令——
   - `build-tripo --location L --kind K --sample S --name N [--flat] [--footprint W,D] [--no-apply] [--no-import]`
     一条龙：art_from_tripo（qa_batch 减面/归一/剥 PBR）→ manifest 条目 → palette mesh → Godot 导入。
   - `sync-manifest [--task id=uuid] [--source id=path]`：为绕过 build 流程落盘的 GLB 回填 manifest
     （`model_thumbnail.gd` 靠 `bounds.godot_size` 给建材坞图标取景，缺条目会按 1×1×1 兜底）。
   `art_from_tripo.py` 保留可单跑，但新资产一律走 `build-tripo`。
6. **面数/体积治理**（2026-09-27）：
   - ⭐ **裁定（2026-09-27 用户）：600 面/件硬顶已解除**，为先保表现力，当前口径 **2000 面/件**。
     `qa_batch.py` / `art_from_tripo.py` / `build-tripo` 的 `--faces` 默认值已同步改 2000。
     后续 session **不得**再以"超 600 面、无豁免记录"为由擅自减面（本 session 曾误判一次并回滚，
     四件 qz 资产维持 **1900 面**）。美术档（泉州植物 ≤500 等）为美术侧定标口径，与工具硬预算分离，
     是否回收该口径由用户裁定。
   - 已删除 16 个无引用的旁挂贴图孤儿（`*_Color_<uuid>.jpg(+.import)`，共 4.85MB，
     Godot 导入的 .scn 内嵌贴图自包含，已验证零引用）。此清理与面数裁定无关，保留有效。
7. 验收：`py tools/dev.py test` 全绿（model 159 / scene 0）。

**遗留（不阻塞）**
- [ ] `loc_cc_prop_buoy` 的源样假设为 `buoy_s42b_low`（task `113aa564…`，--flat 后贴图已剥，无直接物证），
      若有出入改 manifest 的 task_id / source 两字段即可。
- [ ] 面数最终口径（当前 2000）若日后因 Web 端性能回收，由用户裁定后改三处默认值并逐件重build。

**约定**：Tripo 相关状态只写本节，不要分散到对话里；换 session 时先读本节。

**坑**：替换/删除 `project/assets/models/` 下的 GLB 或贴图后，`.godot` 旧缓存会让下次 headless 导入
直接 0xC0000005 崩溃（import.log 无具体错误）——先删 `project/.godot` 再跑 `py tools/dev.py test`。

## 已知坑

- ~~**4.7 导出模板未安装**~~ 已解决：模板已装到 `%APPDATA%\Godot\export_templates\4.7.stable`
  （`python tools/fetch_templates.py` 分块续传下载 tpz，再解包 `templates/` 到版本目录）。
  换机器时重复该流程，或直接用 Godot 编辑器自带的模板下载。
- **uv 在本机不可用**：`uvx` / `uv venv` 创建 Windows trampoline 时被拦截（拒绝访问）。blender-mcp 改用标准库 `python -m venv .venv-mcp` + pip 安装。
- **Blender 不能后台跑 MCP**：插件明确拒绝 `blender -b`（主循环定时器不执行，命令会挂），必须 GUI，见 `tools/blender_mcp_autostart.py`。
- **Blender 遥测**：已通过 `BLENDER_MCP_DISABLE_TELEMETRY=true` 关闭（MCP 条目里设置）。
- **`python` 命令是 Windows Store stub**：PATH 里 `python` 指向 `WindowsApps\python.exe`，调用会**静默无输出退出**（exitCode 0）。所有脚本改用 `py`（3.14.4）。
- **git 命令行不在 PATH**：PowerShell 里 `git` 不可用（`where git` 空），版本控制操作需先修 PATH 或用其他端。
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
