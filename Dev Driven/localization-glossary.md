# 《雾港造物记》· 四地点术语中英对照与 UI 文案表

> 版本 v1.0 ｜ 日期 2026-09-23 ｜ 撰写：文策渊（设计 / 叙事）
> 用途：① 上线前译名冻结检查清单 ② 本地化执行依据 ③ 商店资产文案取词源
> 关联：`location-gameplay-design.md`（M1–M5 门槛）、`quanzhou-spec.md`（泉州文化内容）

---

## 0. 先读这一节：译名的冻结规则

**⚠️ 译名一旦随商店页上线就改不动了。** 本表不是一个"参考"，是**上线前的检查清单**。

| 位置 | 冻结时点 | 说明 |
|---|---|---|
| **商店页** | **最早冻结** | 商店页一旦公开，术语就面向市场定死了。**所有文化术语必须在商店资产定稿前定完** |
| 建材名（游戏内） | 随 1.0 上线冻结 | 改建材名等于改 UI，成本高于改文案 |
| 目标文案 / 机制提示 | 随 1.0 上线冻结 | 改动成本低，但仍需走一次回归 |

**两条使用规则**：
1. 商店页用词**必须**从本表取，不得由文案方自由发挥（尤其泉州七条）。
2. 塞舌尔 / 圣托里尼的「保留原名项」（§5）**一律不译**，包括商店页。

---

## 1. 地点名与核心动词（8 条）

| # | 中文 | 英文 | 核心动词 EN | 首次出现位置 |
|---|---|---|---|---|
| 1 | 雾港 · 泉州湾 | **Mist Harbor · Quanzhou Bay** | **Connect** | 地点选择页 / 商店页 |
| 2 | 圣托里尼 | **Santorini** | **Cantilever**（v1.0）/ **Carve**（1.1） | 地点选择页 / 商店页 |
| 3 | Cape Cod | **Cape Cod** | **Illuminate** | 地点选择页 / 商店页 |
| 4 | 塞舌尔 | **Seychelles** | **Stack** | 地点选择页 / 商店页 |

> **动词取词说明**：四个动词必须译成四个**不同的英文词**，不能都译成 Build。
> Connect（线）/ Cantilever（向外）/ Illuminate（面）/ Stack（向上）——英文侧的区分度与中文侧一致，这是反"换皮"指控在英文市场的一部分证据。
> `Cantilever` 比 `Overhang` 更准确（后者偏名词/消极），且 `Carve` 留给了 1.1 的凿崖。

---

## 2. 泉州文化术语定名（7 条 + 1 条待定）

> 每条含：英文定名 · **给玩家看的 UI 短说明（英文，≤12 词）** · 首次出现位置 · 定名理由。
> **译名解决"叫对"，短说明解决"看懂"，两者缺一文化溢价都拿不到。**

| # | 中文 | 英文定名 | UI 短说明（英文，给玩家看） | 首次出现位置 | 定名理由 |
|---|---|---|---|---|---|
| 1 | **刺桐** | ⭐ **`Zayton Tree`** | "The tree that gave Zayton its name." | 建材名 · 目标文案 · 商店页 | **Zayton 本就是"刺桐"的音译**（马可·波罗、伊本·白图泰笔下的泉州）。用 Zayton Tree 把「植物锚点」与「城市海外认知锚点」接在一起，是**零成本拿到的宣发资产**。❌ 否掉 `Coral Tree` / `Erythrina`——那两种译法都会切断这个连接 |
| 2 | **蚵壳厝** | **`Oyster-Shell House`** | "Rare walls built entirely from oyster shells." | 建材名 · 商店页 | 直译最准；"Oyster-Shell" 的奇异感本身就是卖点（世界罕见建筑）。❌ 不要用 `Shell House`（会被误读为贝壳装饰屋） |
| 3 | **燕尾脊** | **`Swallowtail Ridge`** | "Ridge ends that curve up like a swallow's tail." | 建材名 · 目标文案 | Swallowtail 是既有建筑/纹章学术语，英文读者能直接成像 |
| 4 | **出砖入石** | **`Brick-in-Stone Wall`** | "Broken brick and stone, walled together after quakes." | 建材说明 · 商店页 | 这是泉州独有的震后砖石混砌工艺，加 "after quakes" 才讲清了它为什么长这样。❌ 不要直译成 `Brick Entering Stone`（会变成笑话） |
| 5 | **蟳埔簪花围** | **`Xunpu Flower Crown`** | "Fresh flowers woven into the hair, Xunpu style." | 建材名（素馨花丛）· 商店页 | 保留地名音译 `Xunpu`（蟳埔）——地名不译是通例，且近年该 IP 在海外已有 Xunpu 的认知 |
| 6 | **南音** | **`Nanyin`**（不译） | "Quanzhou's ancient court music, UNESCO-listed." | 设置页 · 鸣谢页 | 专有名词不译。⚠ 副标**不得**写 "Chinese opera"——南音不是戏曲，写错会得罪懂行的玩家 |
| 7 | **洛阳桥** | **`Luoyang Bridge`** | "A Song stone bridge reinforced by oysters." | 建材名（桥拱）· 机制提示 | 用 "reinforced by oysters" 点出**种蛎固基**——这是它区别于任何一座古桥的唯一特征，也是游戏里真有对应玩法的点 |

| 待定 | 中文 | 英文定名 | 状态 |
|---|---|---|---|
| 8 | **石构航标塔** | **`Stone Beacon Tower`** / UI: "A stone tower that guided ships home." | ⚠ **D-1 未拍板**。若泉州航标改用姑嫂塔式石塔 → 用 `Stone Beacon Tower`；若沿用西式灯塔 → 用 `Lighthouse`（并将 #8 从文化术语降级为普通建材名） |

> **附属音译词（非术语，供文案取用）**：闽南 = **`Minnan`** ｜ 蟳埔 = **`Xunpu`** ｜ 姑嫂塔 = **`Gusao Pagoda`** ｜ 六胜塔 = **`Liusheng Pagoda`** ｜ 安平桥 = **`Anping Bridge`**（副标 "the longest stone beam bridge of ancient China"）

---

## 3. 建材名中英对照（36 条）

### 3.1 泉州（14 条）

| 中文 | 英文 | 备注 |
|---|---|---|
| 石构航标塔 | Stone Beacon Tower | D-1 待定 |
| 码头栈道 | Pier Boardwalk | 复用件 |
| 桥拱（泉州变体） | Stone Beam Bridge | ⭐ 玩法主角，非纯装饰 |
| 蚵壳厝 | Oyster-Shell House | 文化术语 #2 |
| 红砖古厝 | **Minnan Red-Brick Mansion** | ⚠ UI 窄栏用 `Red-Brick Mansion`，`Minnan` 只放 tooltip（见 §8） |
| 燕尾脊 | Swallowtail Ridge | 文化术语 #3 |
| 刺桐树 | Zayton Tree | 文化术语 #1 |
| 垂榕 | Weeping Banyan | — |
| 素馨花丛 / 花担 | Jasmine Cluster | 文化术语 #5 的载体 |
| 红树林 | Mangrove | 滩涂限定 |
| 陶砖 | Terracotta Brick | 复用件 |
| 坡屋顶 | Sloped Roof | 复用件 |
| 石基 | Stone Base | 复用件（含"出砖入石"变体） |
| 暖光灯 | Warm Lantern | ⭐ 灯火次第亮起的主角 |

### 3.2 圣托里尼（8 条）

| 中文 | 英文 | 备注 |
|---|---|---|
| 凝灰岩块 | Tuff Block | 崖体主体 |
| 白墙屋 | Whitewashed House | v1.0 主力 |
| 蓝顶 | Blue Dome | 视觉符号 |
| 三角梅 | Bougainvillea | 花色统一紫红 |
| 葡萄藤篮 | **Kouloura** | §5 保留原名。UI 副标 "a ground-hugging basket of vines" |
| 洞穴屋（1.1） | **Yposkafa** | §5 保留原名。UI 副标 "a cave house carved into the cliff" |
| 扶壁柱 | Buttress | 复用桥拱翻转 |
| Skala 阶梯 | Skala Steps | 垂直交通 |

### 3.3 Cape Cod（7 条）

| 中文 | 英文 | 备注 |
|---|---|---|
| 高地灯塔 | Highland Light | R=18，主力补光 |
| 复刻小灯塔 | Nauset Light | R=8，红白条纹 |
| 雾号站 | Fog Station | R=6，雾天加倍 |
| 银灰木瓦小屋 | Gray Shingle Cottage | — |
| 蔓越莓沼泽块 | Cranberry Bog | 秋季变血红 |
| 龙虾笼与浮标 | Lobster Trap & Buoy | 可选建材 |
| 沙丘草 | Beach Grass | 装饰 |

### 3.4 塞舌尔（7 条）

| 中文 | 英文 | 备注 |
|---|---|---|
| 花岗岩巨石（大） | Granite Boulder (Large) | 3×3×2 |
| 花岗岩巨石（中） | Granite Boulder (Medium) | 2×2×2 |
| 楔石 | **Wedge Stone** | ⭐ 原拟 `Calage`（法语）太生僻，改用英文 |
| 海椰子树 | **Coco de Mer** | §5 保留原名 |
| Takamaka 大树 | **Takamaka** | §5 保留原名 |
| 象龟 | Giant Tortoise | — |
| 浅礁珊瑚块 | Reef Coral | 水下限定，可选 |

---

## 4. 机制与状态术语（30 条）

### 4.1 泉州 · 连

| 中文 | 英文 | 首次出现位置 |
|---|---|---|
| 连通链 | Chain | 机制提示 |
| 航标 | Beacon | 建材名 |
| 渔船归港 | Boats Coming Home | 机制提示 |
| 灯火次第亮起 | ⭐ **Lights, One by One** | 目标文案 · 商店页 |
| 种蛎固基 | Oyster-Reinforced Foundation | 建材说明 |
| 晨雾态 | Morning Mist | 环境态切换（N 键） |

### 4.2 圣托里尼 · 悬挑 / 凿

| 中文 | 英文 | 首次出现位置 |
|---|---|---|
| 悬挑 | Cantilever | 机制提示 |
| 凿崖 | Carving | 机制提示（1.1） |
| 锚固 | Anchor | 机制提示 |
| 观景位 | Caldera View | 机制提示 |
| 崖体 | Cliff Face | 地形说明 |

### 4.3 Cape Cod · 照

| 中文 | 英文 | 首次出现位置 |
|---|---|---|
| 光锥 | Light Cone | 机制提示 |
| 覆盖 | Coverage | 机制提示 |
| 暗角 | Dark Corner | 目标文案 |
| 雾天 | Fog | 环境态切换 |
| 蔓越莓季 | Cranberry Season | 设置页 |

### 4.4 塞舌尔 · 叠

| 中文 | 英文 | 首次出现位置 |
|---|---|---|
| 叠 | Stack / Stacking | 机制提示 |
| **稳** | **Steady** | 机制提示 |
| ⚠ **摇** | ⚠ **`Wobbly`** | 机制提示 · **见 §8 风险** |
| 垫（动词） | Shim | 机制提示 |
| 收分 | Taper | 机制提示 |
| 石缝植物 | Crevice Green | 落成表现 |
| 天然石拱 | Natural Arch | 衍生玩法 |

### 4.5 通用状态与操作

| 中文 | 英文 | 中文 | 英文 |
|---|---|---|---|
| 晨 | Morning | 拍照模式 | Photo Mode |
| 昼 | Day | 建材栏 | Build Menu |
| 日落 | Sunset | 撤销 | Undo |
| 夜 | Night | 旋转 | Rotate |
| 白沙滩 | White Sand | 地点切换 | Location Select |

---

## 5. 保留原名项 · 一律不译（10 条）

> 这些词在英文世界已有稳定用法或本身就是国际通用名，**翻译反而会丢掉辨识度**。包括商店页在内，全部保留。

| 原名 | 中文 | 地点 | 说明 |
|---|---|---|---|
| **Coco de Mer** | 海椰子 | 塞舌尔 | 国际通用名（法语），指该物种时全球都用此名 |
| **Takamaka** | 红厚壳 | 塞舌尔 | 无通用英文名，音译即本名 |
| **Yposkafa** | 洞穴屋 | 圣托里尼 | 希腊语本名，旅游与建筑文献通用 |
| **Kouloura** | 葡萄藤篮 | 圣托里尼 | 希腊语本名，葡萄酒文化圈通用 |
| **Nanyin** | 南音 | 泉州 | 联合国非遗名录用名 |
| **Zayton** | 刺桐（城） | 泉州 | 历史文献用名（马可·波罗） |
| **Minnan** | 闽南 | 泉州 | 学术通用音译 |
| **Xunpu** | 蟳埔 | 泉州 | 地名音译 |
| **Caldera** | 火山口湾 | 圣托里尼 | 地质学术语，英文通用 |
| **Creole** | 克里奥尔 | 塞舌尔 | 文化术语，英文通用 |

---

## 6. 新手目标文案（6 条 × 4 地点 = 24 条）

> ⚠ **一致性说明**：新手目标里出现的数量词（"10 格"、"3 座"）是**引导计数**，沿用本体既有机制，
> **不属于"机制数值反馈"**。泉州 R1 的「全程不显示任何数字」红线针对的是**连通链本身的反馈**（不显示产率/效率/进度条），与本表不冲突。

### 泉州 · Connect

| # | 中文 | English |
|---|---|---|
| 1 | 铺 10 格码头栈道 | Lay 10 tiles of Pier Boardwalk |
| 2 | 立起 1 座石构航标塔 | Raise a Stone Beacon Tower |
| 3 | 用石梁桥把一座屿连到岸上 | Connect an islet to the shore with a Stone Beam Bridge |
| 4 | 建 2 座蚵壳厝，让渔船归港 | Build 2 Oyster-Shell Houses and watch the boats come home |
| 5 | 建 1 座红砖古厝，装上燕尾脊 | Build a Red-Brick Mansion and crown it with a Swallowtail Ridge |
| 6 | 切到夜晚，看灯火一盏一盏亮起 | Switch to night and watch the lights come on, one by one |

### 圣托里尼 · Cantilever

| # | 中文 | English |
|---|---|---|
| 1 | 铺 10 格白墙屋 | Lay 10 blocks of Whitewashed House |
| 2 | 向外悬挑 2 格以上，造出第一个露台 | Cantilever 2 tiles out to make your first terrace |
| 3 | 用扶壁柱撑住一次更远的悬挑 | Support a longer reach with a Buttress |
| 4 | 建 1 座蓝顶 | Build a Blue Dome |
| 5 | 用 Skala 阶梯连接上下两层 | Link two levels with Skala Steps |
| 6 | 切到日落，截一张金色的岛 | Switch to sunset and capture the island in gold |

### Cape Cod · Illuminate

| # | 中文 | English |
|---|---|---|
| 1 | 建 3 座银灰木瓦小屋 | Build 3 Gray Shingle Cottages |
| 2 | 切到夜晚，找出最暗的一角 | Switch to night and find the darkest corner |
| 3 | 建 1 座高地灯塔 | Build a Highland Light |
| 4 | 用 1 座小灯塔补掉一个暗角 | Fill one dark corner with a Nauset Light |
| 5 | 让整片建造区剩下的暗角少于 3 处 | Leave fewer than 3 dark corners in your build |
| 6 | 切到雾天，截一张光锥 | Switch to fog and capture the light cone |

### 塞舌尔 · Stack

| # | 中文 | English |
|---|---|---|
| 1 | 在沙滩的巨石上再叠一块 | Stack one more boulder onto a beach rock |
| 2 | 用楔石垫稳一块摇晃的石头 | Shim a wobbly stone steady with a Wedge Stone |
| 3 | 把一整座石堆垫到完全不晃 | Shim a whole stack until nothing wobbles |
| 4 | 让石缝里长出绿色 | Let green grow in the crevices |
| 5 | 种 1 棵海椰子树 | Plant a Coco de Mer |
| 6 | 引来一只象龟 | Attract a Giant Tortoise |

> ⚠ **塞舌尔 #3 曾被写成「堆到 5 层」——已修正。**
> 这是我的红线：**塞舌尔不显示层数、不设高度目标**（P1：一旦有层数，它就从松弛沙盒变成挑战游戏）。
> 目标改为「垫到完全不晃」——要求的是**状态**（稳），不是**数值**（层）。本地化时若有人把 #3 改回带层数的写法，请驳回。

---

## 7. 机制提示语（选中建材时浮现一句话，14 条）

> 教学原则：不开局弹教程墙，玩家**第一次选中**相关建材时才在建材栏下方浮现一句，学完即走。

### 泉州（6）

| 建材 | 中文 | English |
|---|---|---|
| 石构航标塔 | 航标要立在湾口，渔船才看得见回家的路。 | A beacon at the bay mouth shows the boats their way home. |
| 石梁桥 | 石梁可以跨过水面，把屿和岸连起来。 | Stone beams cross the water, linking islet to shore. |
| 蚵壳厝 | 蚝壳砌的墙，冬暖夏凉。 | Walls of oyster shell: cool in summer, warm in winter. |
| 红砖古厝 | 红砖白石，天井通风。 | Red brick, white stone, and a skywell for air. |
| 燕尾脊 | 燕尾脊要架在坡屋顶上。 | A Swallowtail Ridge sits on top of a Sloped Roof. |
| 刺桐树 | 刺桐先花后叶，泉州因它得名。 | The Zayton Tree flowers before it leafs — and gave the city its name. |

### 塞舌尔（4）

| 建材 | 中文 | English |
|---|---|---|
| 花岗岩巨石 | 越大越稳，越小越灵。转一转，重心会变。 | Bigger is steadier, smaller is freer. Rotate to shift its weight. |
| 楔石 | 楔石塞进石缝，能让上面的石头站得更稳。 | A Wedge Stone fills the gap and steadies the stone above. |
| 象龟 | 石堆稳了，象龟才会来。 | Steady the stack, and a tortoise may come. |
| 海椰子树 | 海椰子只长在塞舌尔。 | The Coco de Mer grows nowhere else on Earth. |

### Cape Cod（2）

| 建材 | 中文 | English |
|---|---|---|
| 高地灯塔 | 一塔管一大片，先补最黑的地方。 | One tower sweeps a wide arc — start with the darkest spot. |
| 雾号站 | 雾天里，雾号站的光晕会加倍。 | In fog, a Fog Station's glow reaches twice as far. |

### 圣托里尼（2）

| 建材 | 中文 | English |
|---|---|---|
| 白墙屋 | 贴着实心崖体建，才站得住。 | Build against solid rock and it will hold. |
| 扶壁柱 | 想挑得更远，就加一根扶壁柱。 | To reach further out, add a Buttress. |

---

## 8. 上线前检查清单（按冻结时点排序）

| 优先级 | 检查项 | 位置 | 冻结时点 |
|---|---|---|---|
| **P0** | 泉州 7 条文化术语定名已按本表执行（尤其 `Zayton Tree`） | 商店页 | **最早** |
| **P0** | §5 十项保留原名在商店页**未被翻译** | 商店页 | **最早** |
| **P0** | ⚠ `摇` 的英文为 **`Wobbly`**，未出现 `Unstable` / `Failing` / `Failed` | 游戏内 | 1.0 |
| P1 | 四地点动词译为四个不同英文词（Connect / Cantilever / Illuminate / Stack） | 商店页 · 游戏内 | 商店页 |
| P1 | `Minnan Red-Brick Mansion` 在建材栏**降级显示**为 `Red-Brick Mansion` | 游戏内 | 1.0 |
| P1 | 塞舌尔目标 #3 **不含层数** | 游戏内 | 1.0 |
| P2 | 24 条新手目标已按本表翻译 | 游戏内 | 1.0 |
| P2 | 14 条机制提示语已按本表翻译 | 游戏内 | 1.0 |
| P2 | 南音副标**未写** "Chinese opera" | 设置页 · 鸣谢页 | 1.0 |

---

## 9. ⚠ 两条最危险的项（本地化必读）

### 9.1 最可能被误译：**「摇」→ `Wobbly`**

**这是全表风险最高的一条。**

- 中文「摇」在设计上是**一个松弛的、无惩罚的视觉提示**——石头轻轻晃，告诉玩家"这块没垫稳"，但**不是失败**。
- 英文最自然的翻译是 `Unstable` 或 `Unsteady`。**这两个词都不能用**：它们带有"不安全、要塌了"的负面语义，会把一个柔和的视觉提示变成**失败判定**，直接违背 P1 松弛无压。
- 更不能用 `Failing` / `Failed`。
- ✅ **定名 `Wobbly`**：口语、轻、带一点可爱感（a wobbly table 是日常说法，无危险暗示），与"摇"的语感完全对应。
- 它出现在**塞舌尔机制反馈的核心路径上**（每放一块石头都可能看到），高频暴露，译错的代价是全表最大的。

### 9.2 最容易在 UI 被截断：**`Minnan Red-Brick Mansion`**

- 3 个词 + 2 个连字符，建材栏格子窄，**几乎必然被截断成 "Minnan Red-B..."**。
- ✅ **处理方式**：建材栏主显示 `Red-Brick Mansion`，`Minnan`（闽南）只在 tooltip / 建材详情里出现。
- 同理检查：`Stone Beam Bridge`、`Oyster-Shell House`、`Whitewashed House`、`Granite Boulder (Large)` —— 都需要实测一遍建材栏宽度，**不要等上线后靠玩家反馈发现截断**。

---

## 10. 术语统计

| 类别 | 条数 |
|---|---|
| 地点名 + 核心动词 | 8 |
| 泉州文化术语（含 1 条待定） | 8 |
| 建材名 | 36 |
| 机制与状态术语 | 33 |
| 保留原名项 | 10 |
| 新手目标文案 | 24 |
| 机制提示语 | 14 |
| **合计** | **133** |

---

## 11. 待确认

| # | 项 | 状态 |
|---|---|---|
| 1 | **D-1**：泉州航标用石塔（`Stone Beacon Tower`）还是西式灯塔（`Lighthouse`） | ⚠ 未拍板，影响术语 #8 与 3.1 首行 |
| 2 | 「出砖入石」是否在游戏内 UI 露出（目前只在建材说明与商店页） | 待定 |
| 3 | 南音是否需要在设置页 / 鸣谢页单独标注来源 | 建议标注（世界非遗，标注是加分项） |
| 4 | 塞舌尔「垫」的动词译法：`Shim` vs `Wedge`（名词已定为 Wedge Stone，动词用 Shim 避免重复） | 建议维持 `Shim` |
| 5 | 商店页是否需要泉州七条的**中文原名并列**（如 "蚵壳厝 Oyster-Shell House"） | 建议并列——海外玩家对异形文字有好奇心，且凸显真实文化来源 |
