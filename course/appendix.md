# 附录 · 术语 / FAQ / 坑索引 / 命令速查 / 素材索引

这一页是把 36 章里**可查的事实**抽出来的速查表。写章时随时回来对照，别凭记忆写数字。

---

## A. 术语表

| 术语 | 含义 | 首次出现 |
|---|---|---|
| **G‑V‑C 循环** | Goal 目标 → Verify 验证 → Correct 修正，与 Agent 协作的基本节奏 | 第 03 章 |
| **L1 / L2 / L3** | 三层测试：模型层（56 项）/ 场景层（12 项）/ 浏览器层（23 项） | 第 29 章 |
| **QA 快照** | `window.harborState`，游戏自己导出的内部状态 JSON | 第 11 章 |
| **cells / occupancy** | 双字典：逻辑格（原点）与物理格（每一格）的映射 | 第 19 章 |
| **footprint / owner** | 多格模型占用的格集合，及其原点格（`owner_at`） | 第 06 / 19 章 |
| **原点格（origin）** | 一件建材的记录位置；点击任意部分都反查到它 | 第 10 / 19 章 |
| **可见面（visible_faces）** | 剔除被遮挡面后真正渲染的面数，可被断言 | 第 10 章 |
| **导入（import）** | 原始资产 → Godot 运行时资源；`.import` 是决策，`.godot/` 是结果 | 第 09 章 |
| **provenance** | 溯源记录：哪个脚本、哪个任务、什么摘要、什么时间产出的二进制 | 第 16 章 |
| **manifest** | 资产体检报告：bytes / triangles / bounds | 第 16 / 17 章 |
| **atomic write** | 先写 `.tmp` 再 rename，崩溃不毁原文件 | 第 21 章 |
| **快照式撤销** | 记录 before / after，撤销 = 写回旧值（非"逆操作"） | 第 20 章 |
| **约束写死，统计推导** | 断言设计原则：规则常量可写死，数量从数据源推导 | 第 31 章 |
| **W 档（Won't）** | MoSCoW 里"本次坚决不做"，必须写下来并给理由 | 第 33 章 |
| **pilot** | 同事封装的远程 MCP 服务（Blender 侧），异步作业模型 | 第 15 章 |

---

## B. 关键常量速查

| 常量 | 值 | 出处 |
|---|---|---|
| `MAX_CELLS` | 12,000 | `world_model.gd` |
| `EDGE` / `MIN_Y` / `MAX_Y` | 25 / −4 / 20 | 同上 |
| `MAX_HISTORY` | 160 | 同上 |
| `SLOT_COUNT` | 3 | 同上 |
| `SAVE_VERSION` | 1 | 同上 |
| 世界种子 `seed` | 240910 | manifest / `village.reset` |
| 相机 yaw / pitch | 0.72 / 0.72（等距） | `main.gd` / 缩略图同参数 |
| 建材数 / GLB 数 | 14 项 / 9 件 | `palette.json` / `manifest.json` |
| 资产总量 | 2,722 三角面 · 约 282 KB | manifest |
| Web 产物 | wasm 37.68 MB · pck 0.40 MB · js 0.27 MB | 第 25 章 |
| 字体子集 | 299 KB | `harbor-sc.ttf` |
| 引擎 | Godot 4.7.stable（本地）/ Blender 5.2.1（远程 pilot） | TOOLCHAIN.md |

---

## C. 命令速查

```powershell
# 引擎内（提交前必跑）
python tools/dev.py test                 # L1(56) + L2(12)，秒级，退出码表达成败
python tools/dev.py import               # 重新导入（改了 GLB / .import / 换引擎后）

# 发行
python tools/dev.py export-web           # → build/
python tools/dev.py export-windows       # → build-win/mist-harbor.exe（单文件）
python tools/dev.py preview              # 起本地预览（注意：不压缩，别拿它测体积）
python tools/dev.py package              # 打 source/seed/web 三个 zip

# 浏览器验收（需先导出）
python -m http.server 8184 --bind 127.0.0.1 --directory build
python project/tests/browser_smoke.py --base http://127.0.0.1:8184/index.html   # 23 项

# 资产管线
python tools/asset_pipeline.py list
python tools/asset_pipeline.py build --id barrel --name 木桶 --category 建筑 --color b07d4f
python tools/fetch_templates.py          # 换机器装导出模板（分块续传，反复执行至 complete）
E:/Mist_Harbor/.venv-mcp/Scripts/python.exe tools/build_font_corpus.py   # 字体增量子集

# 教程站点
python tools/course_capture.py --chapter 03     # 拍该章配图
python tools/course_check.py                    # 校验配图引用
python tools/course_build.py                    # 重建站点
```

---

## D. 游戏内快捷键（**以代码为准**）

| 键 | 作用 |
|---|---|
| 左键 / 拖动 | 放置 / 连续绘制 |
| 右键拖动 / 中键拖动 | 旋转视角 / 平移 |
| 滚轮 | 缩放（14–64） |
| WASD / 方向键、Q / E | 平移、左右转 |
| **B** | 拆除模式 |
| **R** | 旋转待放置道具 |
| **Ctrl+Z / Ctrl+Y** | 撤销 / 重做 |
| **Ctrl+S** | 保存作品 |
| **N** | 昼夜切换 |
| **F** | 回到岛屿中心 |
| **P** | 隐藏 / 显示 HUD（构图用） |
| **C** | 保存截图 |
| **H** | 帮助　**Esc** 关闭弹窗 |

> ⚠️ 撤销/重做/保存**都带 Ctrl**；`P` 不是拍照（那是 `C`）。第 11 章曾写错过，已按代码修正。

---

## E. 常见坑索引（按主题）

| 主题 | 坑 | 章 |
|---|---|---|
| 断言 | 写死数量（`== 13` / `== 8`）→ 加资产即红 | 31 |
| 断言 | 只判 `failed==0` → 套件没跑也算通过（假绿） | 32 |
| 存档 | 边读边写 → 坏存档把作品改半坏 | 21 |
| 存档 | 直接写目标文件 → 崩溃留下半截 JSON | 21 |
| 成就 | Web 下解锁后立刻写盘 → **毁掉刚写的存档** | 13 / 23 |
| 渲染 | 改场景后立刻取画面 → 截到旧画面（要等两帧） | 24 |
| 缩略图 | 无头环境渲不出 → 必须检查 alpha 并回退手绘 | 13 |
| 资产 | 单位不是米 / 原点没在底面 → 模型错位 | 14 |
| 资产 | 面数低 ≠ 体积小（物体与材质数才是元凶） | 17 |
| 导入 | 换引擎 → 大量 `.import` 同时变红（先查版本） | 09 |
| 导出 | 产物在工程内且没排除 → 包体越导越大 | 25 |
| 体积 | 用 `http.server` 测体积 → 得出错误结论（不压缩） | 28 |
| 远程执行 | 提交返回快 ≠ 完成；失败 id 在服务端仍被占用 | 15 |
| 文档 | 凭印象写快捷键 → 直播翻车 | 36 |

---

## F. FAQ（跨章高频问题）

**Q：加一件新资产要改几处？**
A：理想 0 处代码——写 `tools/art/<id>.py` → `asset_pipeline.py build` → 自动落 GLB/预览/溯源/manifest/`.import`/palette；**测试因从 `palette.json` 推导而自动跟上**（第 16、31 章）。

**Q：测试全绿就没事了吗？**
A：不一定。要防"假绿"：断言数量需 > 0（第 32 章）；浏览器层还要看 `logs`（第 30 章）。

**Q：为什么很多地方强调"从数据源推导"？**
A：因为**数量会自然增长**。写死的数字每增长一次就要改一次测试/文档，最终必然失控。

**Q：37 MB 的 Web 包能上线吗？**
A：能。开 gzip/Brotli 后传输体积大幅下降；再加加载反馈即可（第 28 章）。**先测再判断**。

**Q：换一台机器怎么跑起来？**
A：六步交接清单：装 4.7 → 复制 `tools.example.json` → `fetch_templates.py` → `dev.py test` → `export-web` →（可选）`pilot.example.json`（第 32 章）。

**Q：云端（web-cb）和本地最大的差别？**
A：**平台差异集中在写盘与渲染**：`user://` 在 Web 是异步 IndexedDB（第 13/23 章），渲染走 WebGL（第 29 章）。逻辑层（L1）两边完全一致，所以 CI 放 L1 最划算。

---

## G. 素材与图片索引

| 类型 | 数量 | 位置 |
|---|---|---|
| 示意图（SVG） | 14 | `course/media/diagrams/` |
| 实拍配图（PNG） | 85 | `course/media/shots/<章号>/` |
| 演示视频（webm） | 36 | `course/media/video/<章号>/<章号>-demo.webm` |
| 拍摄脚本 | 36 章 | `course/media/shots.json` |

**视频是脚本自动录制的**：`course_capture.py --video` 会用 Playwright 把每章的
拍摄步骤**重跑一遍并录屏**，产出该章的演示短片（约 10–25 秒，真机 WebGL 运行画面）。

```powershell
python tools/course_capture.py --chapter 03 --video          # 单章
python tools/course_capture.py --chapter 01,02,03 --video   # 多章
python tools/course_build.py                                 # 重建后自动内嵌（首帧用本章首图作封面）
```

> 📌 这些短片是"**本章机制的真实运行演示**"，不是讲课录像；
> 讲课录像按每章的「📹 录屏分镜」人工录制后放到同目录即可替换（文件名任意，取排序第一个）。

**命名规范**：`<章号>-<用途>.png`，例如 `10-night.png`、`31-barrel-in-dock.png`。

| 常用示意图 | 说明 |
|---|---|
| `test-pyramid.svg` | 三层测试 91 项（第 29 章） |
| `pipeline-flow.svg` | 资产管线八步（第 16 章） |
| `bpy-script.svg` | 脚本 vs 执行器分工（第 14 章） |
| `asset-budget.svg` | 面数/体积对照与三种原型（第 17 章） |
| `place-rules.svg` | 四道闸门 + 双字典（第 19 章） |
| `save-flow.svg` | 存档读写安全边界（第 21 章） |
| `web-export.svg` | 产物构成与预设开关（第 25 章） |
| `render-tree.svg` | 节点树与重建流程（第 10 章） |

> 📌 每张图都对应一个**可被验证的事实**（例如"跑完应该有 9 个 GLB"）。
> 改代码后如果图与事实不符，图就是错的——请以事实为准并更新图。
