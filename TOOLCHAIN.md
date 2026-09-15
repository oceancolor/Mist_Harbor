# 本机工具链基线（2026-09-15 建立）

## 版本锁定

| 工具 | 版本 | 路径 | 说明 |
|---|---|---|---|
| Godot | **4.4.stable**（锁定） | `D:\Godot_v4.4\Godot_v4.4-stable_win64_console.exe` | 与 `project/project.godot` 的 `config/features=4.4` 一致，导出模板已装 4.4.stable |
| Godot（勿用） | 4.7.stable | `D:\Godot_v4.7\` | 打开即升级工程（回不去 4.4），且本机无 4.7 导出模板 |
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
1. 服务端是 **4.7.1**，与本地锁定版本 4.4 冲突（`godot_project_info` 是做 4.7.1 fail-closed 诊断）。
2. `godot_apply_files` **只接受 UTF-8 文本文件**、只允许相对路径 → 本项目的 8 个 GLB、`harbor-sc.ttf`、`icon.svg` 等二进制资产传不上去。
3. 它操作的是**服务器上自带的工程根目录**（当前有同事的样例工程与 build 产物），不是本地 `E:\Mist_Harbor`。

### 本机（stdio）

- **godot**：`npx -y @coding-solo/godot-mcp`，`GODOT_PATH` 指向 4.4 console 版，`cwd=project`。
  已验证 14 个工具（`launch_editor, run_project, get_debug_output, stop_project, get_godot_version, list_projects, get_project_info, create_scene, add_node, load_sprite, export_mesh_library, save_scene, get_uid, update_project_uids`），实测 `get_godot_version` → `4.4.stable.official.4c311cbee`。
- **blender**（本地版，因远程 pilot 已接管而设为 `disabled`）：`E:\Mist_Harbor\.venv-mcp\Scripts\blender-mcp.exe`（v1.9.1，28 工具），连 `localhost:9876`，实测 `get_scene_info` → 110 对象。需要时改回 `"disabled": false`，并先 `python tools/blender_mcp.py` 起 GUI Blender。

调试脚本（均在 `.codebuddy/local/`，不入库）：`probe-http-mcp.mjs`（列工具/出 schema）、`call-http-mcp.mjs`（调单个工具）、`blender_pilot_run.mjs`（提交→轮询→下载产物）。

## 已知坑

- **uv 在本机不可用**：`uvx` / `uv venv` 创建 Windows trampoline 时被拦截（拒绝访问）。blender-mcp 改用标准库 `python -m venv .venv-mcp` + pip 安装。
- **Blender 不能后台跑 MCP**：插件明确拒绝 `blender -b`（主循环定时器不执行，命令会挂），必须 GUI，见 `tools/blender_mcp_autostart.py`。
- **Blender 遥测**：已通过 `BLENDER_MCP_DISABLE_TELEMETRY=true` 关闭（MCP 条目里设置）。
- 旧路径 `f:/web-cb/...`（原 web-cb 工具链）已不再依赖。

## 尚未完成（商业化路线）

1. ~~`git init` + 首次提交~~ 已完成：`c461437`（分支 `main`，66 个文件，工作区干净）。
   **尚未设置远端仓库**，需要时执行 `git remote add origin <URL>` + `git push -u origin main`。
2. 导出预设只有 Web：需补 Windows Desktop、Android（JDK17 + Android SDK + 构建模板），iOS 需 macOS。
3. Web 产物 43.6MB wasm，需体积优化/加载进度。
4. 资产管线：Blender → GLB → `assets/models/manifest.json` → `build_world.gd` 建材表，目前只有整体重建式 `art/generate_harbor.py`。

## 版本控制约定

- 提交前跑 `python tools/dev.py test`（模型单测 42 + 场景冒烟）。
- 不入库：`.codebuddy/`（本机工具路径与产物）、`logs/`、`**/build/`、`**/.godot/`、`.venv-mcp/`。
- 换机器时复制 `tools/tools.example.json` 为 `.codebuddy/local/tools.json` 并改路径。
- 二进制资产（GLB / TTF / .blend）按 `.gitattributes` 以 binary 处理，不做行尾转换。
