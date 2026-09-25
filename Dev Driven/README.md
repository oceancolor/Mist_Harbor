# 《雾港造物记 / Mist Harbor》· Dev Driven 开发驱动文档集

> 组装日期 2026-09-25 ｜ 组装人：游承峰（主理人）｜ 用途：**下一轮真正写代码的开发工作输入**
> 上游目录：`../strategy/`（文档正源，仍在维护）｜ 本目录是**快照副本**——开发期间若上游升版，须同步刷新本目录

## ⭐ 先读我：文档地图与读序

| 读序 | 文档 | 版本 | 角色 | 什么时候读 |
|---|---|---|---|---|
| 1 | `location-gameplay-design.md` | v2.5 | **总设计（GDD 层）**：玩法链、排产口径、M1–M6 里程碑、A-1 材质族口径、真实点光源禁令 | 最先读，全局认知 |
| 2 | `water-lighting-params.md` | **v4.2** | **环境数值唯一源**：水体 §3、昼 §4 / 晨 §4.2 / 夜 §4.3、雾 §5.1、日落 §6、`LocationProfile` 字段定义 §7 | 写任何环境参数前；**填 profile 只准抄这里** |
| 3 | `tech-feasibility.md` | v1.3 | **工程口径**：7 项阻塞答复、core 底座重构 13–16 人日、`_apply_daylight(phase)` 参数化、资产加载方案（不做 .pck） | 动代码前，尤其 §2 暖光灯与 §5 core 重构 |
| 4 | `godot-web-perf.md` | v1.1 线 | Web 端性能预算与三级降级：Compatibility 能力边界、`max_lights_per_object` 8 盏共享、包体优化 | 涉及渲染/性能决策时 |
| 5 | `quanzhou-spec.md` | v1.8 | **第一地点完整规格**（地基款）：建材 §3（含三角梅/凤凰木 v1.8 增补、名额口径 §3.5/D-4）、玩法链 §6、环境态全回源 | 做泉州前通读 |
| 6 | `cape-cod-spec.md` | v1.3 | 第三地点规格：建材 §2（含灯塔光效硬结论 §2.4）、同心圆玩法链 §3 | 做 Cape Cod 前 |
| 7 | `santorini-spec.md` | v1.2 | 验证款规格（较薄，日落补偿色值定稿为主） | 做圣托里尼前 |
| 8 | `quanzhou-seychelles-art.md` | v1.3 | **塞舌尔唯一美术规格**（第二部分 §6 起）+ 泉州美术细节（建材色值唯一源已归 quanzou-spec §3，本档三处旧值已作废回源） | 做塞舌尔 / 泉州美术资产前 |
| 9 | `acceptance-checklist.md` | v1.2.4 | **验收判据**：31 条（阻断 19 / 记录 12）+ A-11 天空盒通道 + B-11 背光面冷色相 | 每个里程碑自验；判阻断前**必须回源** |
| 10 | `localization-glossary.md` | v1.0 线 | 术语中英对照 + UI 文案：建材名 36 条、机制术语 30 条、新手目标文案 24 条 | 写任何 UI 文本 / 存档键前 |

## 🔴 开发纪律五条（全部文档共用，违反即返工）

1. **唯一源**：环境数值（水/光/雾/天/日落）只认 `water-lighting-params.md` v4.2，各地 spec 的数值行都是回源指路——抄值只去唯一源
2. **认列不认数**：引用数值先确认它在现行列而非沿革/作废段（作废内容全部标「已作废 · 勿用 · 勿删」留档，**禁止照抄沿革段的数**）
3. **检索双语**：查表里的数搜中文行名，查代码字段搜英文属性名
4. **零真实点光源**：一切光表现走贴片（`unshaded` + `fog_disabled` + `blend_mix` 三件套，缺一不可）；`max_lights_per_object` 禁止调高
5. **排期数字冻结**：core 18 / 地板线 74 / 推荐 ~81（改前须 Benja 拍板）；不要拿舍入后的 18 当基数做增量

## ✅ 收录标准与冲突自查（2026-09-25 主理人核查）

本目录收录 = 充分（开发可独立进行）∧ 必要（删了开发会卡）∧ 无内在冲突。已核查并闭环的三处历史冲突：
- ~~A-10 编号撞号~~ → 验收单侧已改号 **A-11**（v1.2.4），reskin 侧 A-10 保留
- ~~光锥混合模式分歧~~ → 统一 `blend_mix`（lgd v2.5 §2.3 + cape-cod-spec §2.4）
- ~~泉州水色/光线旧值与唯一源冲突~~ → v1.5/v1.6/v1.7 三轮回源，数值副本清零

## 🚫 未收录文档与原因（在 `../strategy/` 与其他目录）

| 文档 | 排除原因 |
|---|---|
| `strategy/reskin-matrix-assessment.md` v2.0 | **发行策略评估**（产品形态/定价/DLC/NO-GO 门控），属发布域不属开发驱动；其 §8 的 A-10 决策项已结案迁移至 location-gameplay-design §1.6；命名空间前缀规则（T0–T4 / MH-ENG / T1–T2）已在 lgd §4.3.1 被依赖方引用 |
| `strategy/concept-art/`（PNG） | 视觉参考素材非文档；生成模型资产时参考，路径不变 |
| `marketing/`、`mist_harbor_home.html` | 运营/营销域 |
| `_probe/` | demo 逆向工程的分析脚本与产物（历史调查工具，不进开发输入） |

## ⚠️ 开发启动前的已知缺口（不阻塞启动，按序补）

1. **塞舌尔无玩法链 spec**：美术规格齐备，但「绕/分」玩法链没有与泉州 §6 / CC §3 同构的章节——做塞舌尔玩法前需补（设计侧任务）
2. **圣托里尼 spec 较薄**（12KB）：日落补偿已定稿，建材/玩法链细节待扩
3. **v4.2 待定标**：晨列三地 + 四地晨 ambient、夜列（除泉州迁入 2 项）——美术侧实机定标，头部 🎨 清单
4. **D-CC-2**：Cape Cod 雾天档 ρ 无值（正交字段，⛔ 不可做成 by_phase）
5. **代码库**：后续开发在 CodeBuddy 进行，需提供 Godot 工程目录 / GitHub 地址后工程侧才能出 patch（demo 仅供参照，不受其实现限制——Benja 2026-09-25 原话见 cape-cod-spec 头部声明）

## 版本快照（2026-09-25，第二刷）

`water-lighting-params v4.2` ｜ `location-gameplay-design v2.5` ｜ `quanzhou-spec v1.8` ｜ `cape-cod-spec v1.3` ｜ `santorini-spec v1.2` ｜ `acceptance-checklist v1.2.4` ｜ `quanzhou-seychelles-art v1.3` ｜ `tech-feasibility v1.3` ｜ 其余为现行线版本

> 本目录副本随正源 `../strategy/` 升级同步刷新（第一刷 11:49，第二刷补 quanzou-spec v1.8 / art doc v1.3 建材色值裁定）。配套资产管线见 `../3D tools config/`（prompt-library v1.1 + tool-connections）。
