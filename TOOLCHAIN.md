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
python tools/dev.py export-web    # Web 导出到 project/build
python tools/dev.py preview       # 本地预览 8188
python tools/dev.py package       # 打 source/seed/web 三个 zip
python tools/blender_mcp.py       # 启动 Blender 并自动连上 MCP（需保持窗口）
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

- **4.7 导出模板未安装**：`%APPDATA%\Godot\export_templates` 目前只有 `4.4.stable`。
  升级后 `python tools/dev.py export-web` 会因缺少 4.7 模板失败；
  需下载 `Godot_v4.7-stable_export_templates.tpz`（约 1.2 GB）并解包到
  `%APPDATA%\Godot\export_templates\4.7.stable\`。
- **uv 在本机不可用**：`uvx` / `uv venv` 创建 Windows trampoline 时被拦截（拒绝访问）。blender-mcp 改用标准库 `python -m venv .venv-mcp` + pip 安装。
- **Blender 不能后台跑 MCP**：插件明确拒绝 `blender -b`（主循环定时器不执行，命令会挂），必须 GUI，见 `tools/blender_mcp_autostart.py`。
- **Blender 遥测**：已通过 `BLENDER_MCP_DISABLE_TELEMETRY=true` 关闭（MCP 条目里设置）。
- 旧路径 `f:/web-cb/...`（原 web-cb 工具链）已不再依赖。

## 尚未完成（商业化路线）

1. ~~版本控制~~ 已完成：`c461437` 起，分支 `main`，远端 `origin = https://github.com/oceancolor/Mist_Harbor`（尚未 push）。
2. ~~资产管线~~ 已完成：`tools/asset_pipeline.py`（远程 Blender pilot → GLB / manifest / Godot 导入 / palette 注册），首件资产 `barrel` 已进游戏。
3. 导出预设只有 Web：需补 Windows Desktop、Android（JDK17 + Android SDK + 构建模板），iOS 需 macOS。
4. Web 产物 43.6MB wasm，需体积优化/加载进度。
5. 存量 8 件资产仍是 Blender 4.2 脚本 `art/generate_harbor.py` 整体重建式产出，可逐步迁到 `tools/art/<id>.py` 逐个走管线。

## 版本控制约定

- 提交前跑 `python tools/dev.py test`（模型单测 42 + 场景冒烟）。
- 不入库：`.codebuddy/`（本机工具路径与产物）、`logs/`、`**/build/`、`**/.godot/`、`.venv-mcp/`。
- 换机器时复制 `tools/tools.example.json` 为 `.codebuddy/local/tools.json` 并改路径。
- 二进制资产（GLB / TTF / .blend）按 `.gitattributes` 以 binary 处理，不做行尾转换。
