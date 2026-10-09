# 分支缝合关系验证报告

> 版本 **v0.1**（2026-10-09）｜ 执行：工程侧 ｜ 起因：Benja 要求验证 main / cursor_work / ltld 三个分支的代码缝合关系
> 仓库：`Mist_Harbor`（远端 origin，SSH 通道）｜ 验证时 HEAD：`main@41787f1`

## 0. 一句话结论

**这三个分支不是"同一条线的三个阶段"，而是三条各自独立演进的线**——其中 cursor_work 与 ltld 在**四地点**和**天海渲染**上是两套并行实现。Git 报的冲突只有 9 个文件，但**真实的缝合成本远高于 9**，因为最贵的那一类冲突 Git 报不出来（见 §5）。

---

## 1. 拓扑（实测）

```
96bc098  ← 三分支公共祖先
│
├── 662904f  ← main 与 cursor_work 的最后一个共享提交
│   ├── 682ee19 → 41787f1        (main，2 提交：strategy 归档 + 立方体形制化)
│   └── 1fb544f → 34acede → 7f6e1bd   (cursor_work，3 提交：四地点体验 / 天空海面+轨道相机 / 日落闪辉+Perlin 海浪)
│
└── 4a25083 → 1854529 → 108c635  (ltld，3 提交：渲染大改+圣托里尼重建+AI 资产管线+四相天空 / 水面折射+岸边泡沫 / 水下断面修正)
```

**合并基点（实测）**

| 分支对 | merge-base |
|---|---|
| main ↔ cursor_work | `662904f` |
| main ↔ ltld | `96bc098` |
| cursor_work ↔ ltld | `96bc098` |

⚠️ 注意这个不对称：**main 与 cursor_work 共享 662904f，但与 ltld 只共享 96bc098**。ltld 从更早的点分出去，走得也更远。

**独有提交**

| 分支 | 相对另两方独有的提交 |
|---|---|
| main | `682ee19`（strategy 归档）、`41787f1`（形制化）— 另加 ltld 侧看来的 `662904f` |
| cursor_work | `1fb544f`、`34acede`、`7f6e1bd` |
| ltld | `4a25083`、`1854529`、`108c635` |

---

## 2. 规模对照（实测）

| 指标 | main | cursor_work | ltld |
|---|---|---|---|
| `project/` 文件数 | 89 | 111 | **336** |
| GLB 资产数 | 9 | 17 | **50** |
| `.uid` 文件数 | 9 | 11 | 26 |
| `build_world.gd` 行数 | 341 | **974** | 611 |
| `main.gd` 行数 | 845 | 982 | **1092** |
| `world_model.gd` 行数 | 369 | 536 | 455 |
| main.gd 中四地点关键词命中 | **0** | 3 | 7 |

> 📌 `main.gd` 四地点关键词：main 是 **0** —— main 上完全没有四地点代码。三条线的功能覆盖面本身就不同。

---

## 3. 真实冲突实测（`git merge-tree --write-tree`）

不是"看起来会撞"，是**跑了三向合并试算、数出冲突块**。

| 合并对 | 冲突文件数 | 冲突块总数 | 明细 |
|---|---|---|---|
| main + cursor_work | **2** | 6 | `palette.json` (4) / `build_world.gd` (2) |
| main + ltld | **1** | 4 | `build_world.gd` (4) |
| **cursor_work + ltld** | **9** | **53** | `build_world.gd` (14) / `main.gd` (14) / `world_model.gd` (15) / `smoke_scene.gd` (3) / `browser_smoke.py` (2) / `test_world.gd` (2) / `asset_pipeline.py` (2) / `README.md` (1) / `harbor-sc.ttf`（**二进制，无法自动合并**） |

🔴 **读数说明**：`build_world.gd` 14 个冲突块、`world_model.gd` 15 个 —— 这不是"局部小撞"，是**重写级正面撞车**。两个分支各自把这三个核心脚本重写了一遍。

---

## 4. 静默缝合区（自动合并成功，但两侧都改过）

这类 Git **不报错**，直接产出一份两边各掺一半的文件，是最容易蒙混过关的地方。

| 合并对 | 静默缝合的文件 |
|---|---|
| main + cursor_work | `3D tools config/README.md` |
| main + ltld | `.gitignore` |
| cursor_work + ltld | `TOOLCHAIN.md`、`project/assets/models/manifest.json` |

⚠️ 尤其 `manifest.json` 和 `TOOLCHAIN.md`：两侧改动被自动拼在一起，语法合法，但**语义是否成立没人验过**。合并后必须逐个人工过。

---

## 5. 语义双轨（🔴 本次验证最重要的发现，merge-tree 完全检测不到）

以下冲突**不产生任何合并冲突标记**，因为两侧动了**不同的文件名**。合并能"成功"，但项目里会同时存在两套系统。

### 5.1 四地点：两套独立实现

| | cursor_work | ltld |
|---|---|---|
| 数据 | `project/data/locations.json`（单一）+ `location_objectives.json` | `project/data/locations/{cape-cod,quanzhou,santorini,seychelles}.json`（按地点分文件） |
| 脚本 | `project/scripts/location_profile.gd`（顶层） | `project/scripts/core/location_profile.gd` + `core/location_mechanic.gd` + `scripts/locations/*.gd`（4 个） |
| 文档 | `project/docs/four-location-implementation.md` | — |

**已实测验证**（对合并结果 tree `f693a6f` 直接列文件）：合并后以下**同时在场**：

```
project/data/locations.json                 ← cursor_work
project/data/locations/cape-cod.json        ← ltld
project/data/locations/{4 × }.json + {4 × }/palette.json
project/scripts/location_profile.gd         ← cursor_work
project/scripts/core/location_profile.gd    ← ltld   ← 同名不同路径，两份都在
project/scripts/locations/{4 × }.gd
```

> 🔴 **两个 `location_profile.gd` 并存，Git 一声不吭。** 这是本次验证最该记住的一条。

### 5.2 palette 数据架构分歧

| 分支 | palette 形态 |
|---|---|
| main / cursor_work | **单一** `project/data/palette.json` |
| ltld | **按地点拆分**：`project/data/locations/<地点>/palette.json` × 4 |

连带后果（实测）：main 本轮新增的 `relief` 字段与 Q-1 结案的 `layer` 字段，**只存在于 main 的单一 palette.json**；`git grep` 在 cursor_work、ltld 上**零命中**。

> 🔴 也就是说：**`layer` / `relief` 在 ltld 的按地点 palette 架构里没有落点**。Q-1 结案与 Q-7 决策的落地位置，取决于先定哪条分支当主干——这是**决策点之间的耦合**，不是纯技术问题。

### 5.3 天海渲染：两套实现，都塞在被重写的核心脚本里

- cursor_work：沉浸式天空海面 + 轨道相机 + 日落闪辉 + Perlin 海浪
- ltld：四相天空 + 水面折射（screen texture）+ 水下 tint + 岸边泡沫 + 水下断面

实测：用 `sky|sea|water|wave|ocean|foam|refract|sunset` 正则扫两侧新增文件，**零命中**——两边都没有把这些功能独立成文件，全写进了 `build_world.gd` / `main.gd`。这正是这两个文件冲突块高达 14 的原因。

---

## 6. 好消息（实测）

- ✅ **`project/project.godot` 三边完全一致**（29 行，零差异）→ 三个分支确实是**同一个 Godot 项目**，项目配置层没有分叉
- ✅ main 是三边中**最轻**的一侧：与 ltld 只撞 1 个文件、与 cursor_work 只撞 2 个 → main 的形制化成果移植成本最低
- ✅ 两侧新增文件**零重名**（`comm -12` 为空）→ 不存在"同名文件互相覆盖"型损失；代价是 §5 的双轨并存

---

## 7. 缝合路径

🔴 **以下为工程侧自设判断，未拍板。**

| 路线 | 做法 | 代价 | 适用前提 |
|---|---|---|---|
| **A（倾向）** | 以 **ltld 为主干** | 把 `layer`/`relief` 移植进 ltld 的按地点 palette 架构（**不是复制，要按新架构重写**）；ltld 的三个核心脚本已是重写版，cw 的天海实现需人工取舍 | 若渲染大改是既定方向 |
| B | 以 **cursor_work 为主干** | ltld 的 50 个 GLB + `core/` 架构需重新接入；天海要二选一 | 若四地点内容优先 |
| C | **不做全量合并** | 只对 main 的文档与形制化做定向 cherry-pick 到目标分支 | 若两条代码线仍在并行探索 |

⚠️ **无论哪条路线，§5 的双轨都必须先处置**：合并后若不手工删掉一套四地点系统，项目会带着两套互相不知情的地点逻辑运行。

**排期影响**：🔴 自设粗估，未动冻结数字。路线 A 的移植工作 **4–8 人日**（palette 架构适配是大头，`layer`/`relief` 要落到 4 个地点的 palette 里）；路线 C 最小，**1–2 人日**。

---

## 8. 待拍板

| # | 问题 | 备注 |
|---|---|---|
| **B-1** | 三分支主干选哪条？（A / B / C） | 🔴 阻塞：`layer`/`relief`、`block_relief.gd`、`palette.json` 的落地位置全部取决于此 |
| **B-2** | 四地点留哪套？（cw 的 `locations.json` 还是 ltld 的 `locations/`） | 合并不会替你选，两套会并存 |
| **B-3** | palette 用单一还是按地点拆分？ | 与 B-1 强耦合；Q-1 的 `layer` 字段落点在此 |
| **B-4** | ltld 的 50 个 GLB 是否全量入库？ | 记忆中面数预算现役 9 件 2722 三角，50 件需重测运行时预算（Q-12） |

---

## 9. 方法论备注

🔴 **`git merge-tree` 只报 content conflict，不报语义冲突。** 本次验证中，真正决定"能不能合"的不是那 9 个冲突文件，而是 §5 里那些**文件名不同、Git 一声不吭**的双轨。

→ **判据**：评估分支能否合并时，除跑合并试算外，必须额外做两件事：
1. 以公共祖先为基准，求**两侧改动文件的交集**（`comm -12`），而不是只看 merge-tree 的输出
2. 对交集外的**新增文件**做语义查重（同功能、不同文件名）

本次若只按 merge-tree 的 9 个文件判断，会得出"cw 与 ltld 缝合成本可控"的错误结论。

---

## 10. 可复跑命令

```bash
# 拓扑
git merge-base origin/main origin/cursor_work      # 662904f
git merge-base origin/main origin/ltld             # 96bc098
git log --oneline --graph --all -25

# 真实冲突试算（--name-only 给出冲突文件与原因）
git merge-tree --write-tree --name-only origin/main origin/cursor_work
git merge-tree --write-tree --name-only origin/main origin/ltld
git merge-tree --write-tree --name-only origin/cursor_work origin/ltld

# 冲突块计数（把上面输出的 tree oid 填进去）
git show <tree_oid>:project/scripts/build_world.gd | grep -c "^<<<<<<<"

# 语义双轨检测：以公共祖先为基准求两侧改动交集
git diff --name-only 96bc098 origin/cursor_work | sort > /tmp/f_cw.txt
git diff --name-only 96bc098 origin/ltld      | sort > /tmp/f_lt.txt
comm -12 /tmp/f_cw.txt /tmp/f_lt.txt

# 双轨实证：看合并结果里两套系统是否并存
git ls-tree -r --name-only <tree_oid> -- project/data | grep -i location
git ls-tree -r --name-only <tree_oid> -- project/scripts | grep -i location
```

## 11. 本轮修订

| # | 内容 |
|---|---|
| 1 | 首版：拓扑 / 规模 / 三对合并实测 / 静默缝合区 / 语义双轨 |
| 2 | §9 立方法论判据：merge-tree 不报语义冲突，须另做交集与查重 |
