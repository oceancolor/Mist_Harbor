# 四地点实现与验收说明

## 运行时结构

- `location_profile.gd` 从 `data/locations.json` 加载地点边界、种子、构筑动词和四态环境。
- `expansion_rules.gd` 将东、西、上、下、南、北编码为六位连接掩码。接口名相同或使用通配接口时才能衔接。
- `world_model.gd` 保存规范构筑单元，不把视觉变体写进存档。放置、拆除、旋转、撤销、重做和导入都会重新推导连接掩码。
- `build_world.gd` 根据掩码选择 `single/end/straight/corner/tee/cross/vertical`。存在对应 GLB 时使用模型变体，否则使用基础 GLB 加程序化接缝。
- 地点存档路径为 `user://<location>_slot_<n>.json`。schema v1 存档读取为泉州；schema v2 显式保存 `location_id`。

## 四个构筑动词

- 泉州“连”：对玩家新增的栈道、桥拱和房屋执行 BFS，目标是形成连续生活线。
- 圣托里尼“悬”：侧面有锚点而正下方为空的玩家建筑计作悬挑；地点垂直上限为 32。
- 塞舌尔“叠”：花岗巨石向上扩充时必须有下方稳定支撑，稳定叠层进入进度。
- Cape Cod“照”：灯塔、路灯和航标使用 `light` 接口形成光网；视觉只使用 emission、光斑和光锥，不创建真实点光源。

## 资产与连接面

`palette.json` 是运行时建材与接口规则的唯一源。每个可扩充单元可声明：

- `family`：视觉和玩法家族；
- `connectors`：六个局部方向允许的接口名；
- `locations`：允许出现的地点；
- `mesh`：基础 GLB；变体命名为 `<mesh>_<variant>.glb`。

同族模型以一米网格、底面中心原点、Y-up GLB 为约定。`asset_budgets.json` 是三角面与尺寸硬门禁；在线候选和确定性资产均不得绕过 Blender QA。

## 自动化验收

`python tools/dev.py test` 覆盖：

- 四地点配置、边界、地形生成、地点建材白名单和独立存档；
- 六方向连接掩码、动态变体、邻居拆除更新和旧存档迁移；
- 泉州 BFS、圣托里尼悬挑、塞舌尔稳定度、Cape Cod 光网；
- 四态环境、地点切换、M1—M6 与零 `OmniLight3D`。

Web 导出后运行 `browser_smoke.py`，额外验证真实画布放置、撤销/重做、四态环境、四地点切换、IndexedDB 存档和浏览器错误。人工美术评审仍需按 `Dev Driven/acceptance-checklist.md` 检查构图、文化语义和截图质量；自动化测试不冒充审美结论。
