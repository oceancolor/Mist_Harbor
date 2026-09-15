# 雾港造物记 · Mist Harbor

原创的单人 3D 海岛自由建造样板，用 Godot 4.7 与 Blender 4.2 制作。借鉴体素拼搭与微缩聚落的玩法类型，不使用或复制商业游戏资产。目标是可玩、可拆解、可验证的课程样板，而非完整沙盒大作。

## 交付结构

- `project/`：完整 Godot 工程，打开 `project.godot` 即可编辑运行。
- `project/art/mist-harbor-kit.blend`：可编辑的 Blender 模块资产工作室。
- `project/art/generate_harbor.py`：确定性建模与 glTF 导出脚本。
- `project/assets/models/`：八种 GLB 和真实生成清单 `manifest.json`。
- `project/scripts/`：世界模型、网格/拾取、界面/输入、建材图标、微缩地图。
- `project/data/`：13 种建材与六个自练目标。
- `project/tests/`：Godot 模型行为测试与场景冒烟。
- `project/docs/`：需求与逐课指南。
- `tutorial.yaml`：14 步 Tutorial Runtime 任务图。
- `learning_tasks.json`：10 项分层学习任务（9 项必修 + 1 项选修），含交付证据与验收标准。
- `package_sample.py`：可重复生成成品/源码/课程种子 ZIP 与 SHA256 清单，Python 3.11+，仅标准库。
- `course_requests.http`：当前单人开发实例的课程 API 请求示例，逐条执行，不代做人工任务。

统一课时：必修任务 305 分钟 + 环境准备 25 分钟 + 演示评审 30 分钟 = 360 分钟；分块世界挑战另加 90 分钟。

## 玩法与操作

左键点击/拖动建造，B 拆除，R 旋转建材，1—9 切换当前分类材料；右键拖动环绕，WASD/中键平移，滚轮缩放，F 回中心；Ctrl+Z/Y 撤销重做；Ctrl+S 保存；N 昼夜；P 拍照；Esc 返回。

完整功能：堆叠、挖取地形、三格灯塔占位、支持判定、160 次撤销历史、确定性海岛、存档校验、JSON 导入导出、昼夜灯光、地图与六个本地自练挑战。预置建筑不计入学习者新增成果。

主要适配桌面浏览器和横屏平板。没有联机、战斗、资源采集、无限地形流送或第一人称角色控制。游戏内挑战不是教师评分器。

## 本地运行与资源再生成

1. 安装 Godot 4.7；浏览器导出需要同版本 Web 模板。
2. Godot 导入 `project/project.godot`，等待 GLB/字体导入后运行。
3. 修改模型时，使用 Blender 4.2+ 打开 `.blend` 副本；运行游戏本身不需要 Blender。

重建资产（已有资产可以直接运行，不必重建）：

```sh
blender --background --factory-startup --python project/art/generate_harbor.py -- --output project/assets/models --source project/art/mist-harbor-kit.blend
```

脚本不下载素材，不访问服务，不读取密钥；它重建八种模块并覆盖明确指定的输出文件。要保护手工修改，先复制源文件或换输出目录。

详细测试、导出与学习步骤见 `project/docs/learning-guide.md`。远程 Web 试玩必须使用 **HTTPS**；仅 `localhost`/回环地址可用 HTTP。不能使用 `file://`。

## 交付一：作为可玩成品

成品只需要 Godot 导出的静态文件，不依赖 BFF、Tutorial Runtime、Blender 或模型服务在线运行。

1. 用 Godot 4.7 打开 `project/project.godot`，安装同版本 Web 模板，选择已有 `Web` 预设，导出到 `project/build/index.html`；首次导出先创建 `build/` 目录。
2. 在仓库根运行下列打包命令。脚本也随源码 ZIP 分发，解压后可直接用样板目录下的 `package_sample.py`；路径相应改成本机路径。

```sh
python server/tutorial_catalog/mist-harbor/package_sample.py --output .codebuddy/releases/mist-harbor --web-dir server/tutorial_catalog/mist-harbor/project/build
```

输出为：

| 包 | 内容 | 用途 |
| --- | --- | --- |
| `mist-harbor-web.zip` | 根目录即 index.html/js/wasm/pck 等静态产物 | 可玩成品，上传到支持 HTTPS 的静态服务 |
| `mist-harbor-source.zip` | `mist-harbor/` 下的完整 Godot/Blender 源工程与课程 | 开发、复现、离线学习 |
| `mist-harbor-seed.zip` | 根目录即 project.godot，与个人提交物隔离 | 新学习者会话的起始工程 |
| `release.json` | 源文件和三个包的大小、SHA256 | 核验部署内容，不是虚构的测试结果 |

已有导出目录也可直接用 `--web-dir` 指向它，无需再次运行引擎。省略此选项只打源码/种子包，不伪造成品。打包器排除 `.godot/`、`.codebuddy/`、`.weaver/`、个人提交、构建缓存及私钥；保留 `.import`/`.gd.uid` 这些 Godot 源配置。

本机可解压成品后运行 `python -m http.server 8184 --bind 127.0.0.1 --directory <成品目录>`，访问 `http://127.0.0.1:8184/index.html`。复用当前 devcloud 时，把成品解压到**新**会话的 `workspaces/<sid>/build/`，使用 `/preview/<sid>/build/index.html`；不要覆盖其他会话、不要为静态游戏重启 8080/8090。

### EdgeOne Makers 成品部署（2026-09-11 已实测）

- 正式试玩：`https://mist-harbor-3d.app.bootcamp.qq.com`。
- 项目：`makers-rjlcd2n1hdgs`；成功部署：`dp9dq7tom5fb`，Production 环境。
- 公网 HTTPS 的 HTML/WASM/PCK 均 200；WASM 和 PCK 的实际响应内容与原始导出逐字节一致；浏览器交互 21/21 通过。
- 本次只发布独立游戏静态产物；BFF、课程计划、AI Agent 后台和开发机配置没有上传到此站点。

首次发布被平台的单文件 **25 MiB** 限制拒绝：Godot `index.wasm` 为 43,682,606 字节。现在在独立发布目录预压缩为 9,400,544 字节，并生成 `edgeone.json` 的 `Content-Type: application/wasm`、`Content-Encoding: gzip` 规则；解压一致性在准备阶段检查，真实客户端响应另行验证。不删减引擎功能，也不修改原始导出。

```sh
python server/tutorial_catalog/mist-harbor/package_sample.py --output .codebuddy/releases/mist-harbor --web-dir server/tutorial_catalog/mist-harbor/project/build --edgeone-dir .codebuddy/releases/mist-harbor/edgeone-web
```

`--edgeone-dir` 必须是新的独立目录；该目录需要一并上传 `edgeone.json`，**不能**当作普通未压缩文件目录直接用 `python -m http.server` 预览。官方 CLI 非交互部署使用 `edgeone makers deploy <该目录> -n <项目名> -t <安全注入的Token> --json`。不要把真实 Token 放进仓库、配置示例或部署文件；CLI 返回成功后仍应对公开 URL 运行浏览器测试。

## 交付二：作为课程接入 Tutorial Runtime

**现有平台的教程实例化不复制种子工程。** 请先由教师/运维将本教程的 `project/` 内容复制到学习者自己的新会话目录，排除 `.godot/`、`build/`、旧存档与身份信息；再导入 `tutorial.yaml`、发布版本并实例化到该会话。

只使用现有的 Godot 导入、冒烟、Web 导出与白名单文件/JSON/预览验证器；不添加任意命令执行端点。Blender 建模与自定义测试由开发者离线运行，不伪装成现有后端 Blender MCP 能力。

课程的服务端流程与成品分开：

1. 部署**包含本教程目录**的 BFF。仅 Git push 不会更新运行中的服务或目录；`--godot` 也不会自动启用教程功能。
2. 在实例配置中显式开启 `TUTORIAL_ENABLE=1`、`DOCS_INGEST_ENABLE=1`、`COURSE_ENABLE=1`、`GODOT_ENABLE=1`、`SESSIONS_ENABLE=1`，确认 `/health` 与 `/api/tutorials/builtin` 的真实响应。本课程不需要生图、EdgeOne 或自动执行 Blender。
3. 管理员初始化 `harbor-build3d` 课程的教师关系，再由教师加入学习者。不要给匿名默认账户开放真实班级的管理员权限。
4. 解压 `mist-harbor-seed.zip` 到新会话的根目录。也可用同一打包器的 `--seed-dir <新的独立目录>` 直接准备种子；目标已存在时会拒绝，不覆盖既有作品。
5. 教师导入 `tutorial.yaml` 并发布版本，学习者对自己的会话实例化计划。请求形状见 `course_requests.http`；已有教程版本优先复用，重复导入会产生新修订号。
6. 新计划可先只推进 `max_steps=2`，检查种子文件与 Godot 导入。预期两步成功，下一步为 `explore`；不要为截图自动批准后续人工任务。
7. 学习者使用 `docs/learning-guide.md` 完成作业，在 `/api/plans/<plan_id>` 看进度、在 `/runs` 看过程，教师在 `/api/courses/harbor-build3d/plans` 看本课计划。

当前课程可通过**文档 + API**使用，尚无完整课程播放器或 Studio V2 任务面板接入。本目录不把“成品可玩”伪装成“课程 UI 已完成”。`course_requests.http` 的 `X-Weaver-User` 仅适用于当前隔离的单人演示实例；正式课堂必须使用已验证身份，不能信任学习者自报请求头。

开始教程后：种子检查和 Godot 导入可自动执行；接下来的观察、建模、测试与反思需要学员自己的提交物，教师/learner 确认点不会自动代批。课堂演示中显示待完成是正确状态。

Fork/Remix：优先复制到新工程和新存档；平台的跨用户样板领取与种子自动分发尚未实现，不能宣称点击教程即已安全 Fork 全部资源。已发布任务图不可静默修改，新版教材应发布新版本。

## 许可证与素材来源

八种模块、建模脚本产出的几何和项目图标均为本任务原创；模型以 CC0-1.0 提供。Godot 游戏脚本作为当前仓库样板源代码交付。中文字体为 Noto Sans SC 的子集，采用 SIL Open Font License，完整声明见 `project/assets/fonts-OFL.txt`。未使用外部 CDN、商业游戏贴图或网络模型链接。

## 本次样板验收（2026-09-10）

- 试玩：`https://benjamin-any5.devcloud.woa.com:8090/preview/mist-harbor-3d/build/index.html`。
- 教学源码包：同一目录下的 `mist-harbor-source.zip`，含 Godot、Blender 源文件和课程。
- 当前项目中心名称：`雾港造物记 · 3D 自由建造样板`，独立会话 `mist-harbor-3d`。
- 已导入 Tutorial Runtime，关联计划 `plan-195a5fc55030459badbb`；仅种子检查与导入两个技术前置步骤通过，其余 12 步作业未代做。
- 42 项游戏模型检查、12 项真实场景检查通过；本地与域名试玩各通过 21 项浏览器交互检查，无浏览器/Godot 脚本错误。
- 平台全量回归 705 项通过。八种 Blender 模型总计 2090 个三角形，GLB 合计约 232 KiB，实际统计见 manifest。
- 浏览器脚本已保留在 `project/tests/browser_smoke.py`，默认检查本地 8184 端口；具体复跑方式见下节。
- 教程 API 已接入；Studio V2 的任务活动 UI 尚未接入这套计划，不应将其概念入口当作已完成页面。

### 提交前复核（2026-09-11）

- 全量平台回归 **711 passed**；Godot 模型 **42/42**、场景 **12/12**；现有本地试玩的浏览器交互 **21/21**。
- 已从当前源工程重新导出 Web，并用交付脚本实际生成分离的源码、课程种子和成品包。
- 增补的六项交付回归覆盖课时、URL 参数、产物目录、可重复打包、个人数据排除和拒绝覆盖。
- 此记录不代表新提交已替换线上成品；实际发布后仍需核对对应产物哈希与体验入口。

## 复跑浏览器验收

先按上面的成品流程启动静态服务。以下命令从样板目录（`package_sample.py` 所在目录）执行，Python 3.11+：

```sh
python -m pip install -r project/tests/requirements.txt
python -m playwright install chromium
python project/tests/browser_smoke.py --base http://127.0.0.1:8184/index.html
```

Linux 若缺 Chromium 系统依赖，按 Playwright 提示由运维安装依赖；不要在受限生产机上自动提权安装。

- 自签证书开发实例需显式加 `--insecure`，仅影响该次测试，不修改系统信任库；正常 HTTPS 不应加。
- 可用 `--base` 或 `HARBOR_PREVIEW` 指向远端 URL；已有查询参数会保留，并合并 `qa=1`。
- 截图/JSON 默认写到 `project/.codebuddy/artifacts/browser/`，不随工作目录漂移；可用 `--artifacts` 或 `HARBOR_ARTIFACTS` 另选目录。
- 每次测试使用全新浏览器上下文，仅检查当前浏览器内存/本地存档，不提交课程或改变服务端世界。

## 验收边界

- Godot 能启动不等于建造操作正确；需执行模型测试、场景测试和浏览器交互测试。
- 构建产物和静态源码分离；`.godot/`、`build/` 不应纳入 Git 或课程种子包。
- 存档属于当前浏览器/设备；跨设备需 JSON 备份，清理浏览器数据会影响本地保存。
- 内网 Web 预览与 EdgeOne 公网成品是独立部署；本次已验证公网成品，但课程/BFF 并未迁移到 EdgeOne。
- 性能有界：最多 12000 个建材原点；样板采用清晰的合并外露面实现，不承诺无限世界或所有设备 60 FPS。
