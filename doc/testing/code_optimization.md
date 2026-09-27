# 代码性能与清理（2026-09-27）

状态：已实现；不改变玩法规则、数值、结算顺序、存档格式或界面布局。运行期约定见 [战斗查询索引](../technical/runtime.md#战斗查询索引2026-09-27)。

## 改动

| 位置 | 内容 | 目的 |
|---|---|---|
| `scripts/ui/heat_pickup_view.gd`、`inspiration_pickup_view.gd` | `_draw` 每帧只做一次悬停命中检测 | 原先每个拾取物都重新扫描全部拾取物（O(n²)） |
| `scenes/main.gd` | 操作提示颜色仅在状态切换时写入；食谱提示每帧只拼一次；卡牌键数组提到循环外 | 避免每帧主题重排与重复分配 |
| `scenes/main.gd` | `_draw` 先按行分桶再逐行绘制，行内及类别顺序不变 | 原先每行遍历全部尸体、美食、敌人和弹体（7 次） |
| `scenes/main.gd`、`scripts/ui/enemy_skill_feedback.gd` | 进度条、首领面板和粮签框的 `StyleBoxFlat` 改为成员缓存 | 避免绘制时每帧新建资源 |
| `scenes/main.gd`、`scenes/front_end.gd`、`scripts/model/run_state.gd`、`scripts/controllers/save_service.gd` | 本局灵感公式合并为 `RunState.earned_inspiration()`，账本首通读取合并为 `SaveService.first_clear_reward()`；战报只读一次存档；战斗中 `rebuild()` 每场只读一次账本 | 去除重复公式及战斗中每次点击的存档读取 |
| `scripts/controllers/combat_controller.gd`、`enemy_abilities.gd` | `alive` 身份索引取代 `enemies.has()`；每只移动敌人复用一次 `blocker_ahead`（向后位移时完整重算）；弹体目标改用普通循环；帧长不超过 1/60 秒时跳过技能内容扫描 | 去除每步 O(敌²) 内容比较与重复美食扫描 |
| `scripts/controllers/recipe_system.gd`、`scripts/ui/status_feedback.gd` | 美食行动循环及状态刷新期间用占用快照做相邻判断 | 原先每个美食的每次判断都扫描全部美食（O(美食²)） |
| `scripts/unit_animator.gd` | `bind()` 切换控制器前断开旧信号 | 与其他表现层一致，防止重复连接 |
| `scenes/main.gd`、`scripts/controllers/shop_controller.gd` | 删除无引用的 `row_content()`、`panel_button()`、`TOP_RECT`、未发出的 `card_upgraded` 信号及从未放入内容的 `shop_items` 容器 | 清理死代码 |

## 测试修正

五项既有失败均为设计变更后未同步的旧断言，按现行文档更新，未改业务代码：

| 测试 | 旧期望 | 现行依据 |
|---|---|---|
| `test_campaign.gd:67` | 大关切换后美食计时与面粉归零 | [小关结束条件](../design/waves.md#小关结束条件2026-09-26)：计时连续，最终胜败才清场 |
| `test_content.gd:34-38` | 清完召唤物下一步即切关 | 同上：末次投放后等待 `transition_delay`，清场不提前结束 |
| `test_edges.gd:66` | 灼烧三跳后 242 生命 | [美食伤害](food_damage.md)：灼烧 1.5／跳，改为读取配置 |
| `test_meta_flow.gd:30` | 6 级包子伤害 31.2 | 同上：基础伤害 6，按基础值 × 1.3 计算 |
| `test_ui.gd:115` | 状态显示「清理余鼠」 | waves.md：「剩余 N 秒 · 余鼠 M」 |

`test_ui.gd` 原先对空 `shop_items` 的三处循环断言实际不检查任何按钮，改为检查 `Recipe_*` 食谱按钮数量、热量不足时禁用及「还差」提示。`status_stress.gd` 改用 `combat.clear()` 而非直接清空敌人数组。`doc/art/ui_battle_refresh.md` 中「清理余鼠」与 waves.md 冲突，已改为链接现行规则。

## 验证

环境：macOS、Apple M4、Godot 4.6.3 stable、Compatibility；对照基线为提交 `2148df1` 的独立工作树。

- 无界面编辑器导入：无解析错误或丢失引用。
- `python3 tools/run_tests.py`：47 / 47 通过（基线 42 通过、5 失败）。
- 确定性：`tests/autoplay.gd` 在默认、困难及 6 级普通三组参数下与基线输出一致；临时脚本逐关运行第 2～5 大关全部 32 小关（固定阵容及食谱，每关至多 120 游戏秒，每秒记录全部敌人与美食状态），3859 行摘要与基线逐字节相同，覆盖 8 种新普通鼠、4 精英和 4 独立首领。
- 战斗步基准（56 美食、100 敌人，无界面，600 步 × 3 次）：每步 3.43 → 1.64 ms。
- 窗口压力（`--disable-vsync`，1280×720，各 1 次，仅作参考）：`stress.tscn` 平均 96.5 → 110.6 FPS、p95 13.4 → 11.4 ms；`status_stress.tscn` 78.0 → 83.2 FPS。
- 视觉：`chapter_boss_gallery.gd`、`economy_gallery.gd`、`screens_gallery.gd` 通过；人工查看首领面板、粮签高亮、灵感拾取、进度条及同行美食／老鼠遮挡顺序正常。

## 后续处理（2026-09-27）

- 用户确认不再需要右侧信息面板：删除 `panel`、`PANEL_RECT`、`panel_open`／`layout_phase`、`set_panel_open()` 与 `panel_label()`，`sync_panel_visibility()` 更名为 `sync_overlay_visibility()`，只保留小铺与存档重试遮罩逻辑。面板原本恒隐藏，点击、悬停和拖放中的面板区域判断恒为假，删除后行为不变。设计依据见 [UI 规范](../art/ui.md)。`test_ui.gd`／`test_shovel.gd` 移除面板断言，原面板区点击改为小铺区点击，长文案检查改为针对小铺食谱卡。
- `tests/continuous_campaign_gallery.gd` 按现行小铺时机更新并通过，记录见 [连续战役验证](continuous_campaign.md#原生画面与鼠标)。
