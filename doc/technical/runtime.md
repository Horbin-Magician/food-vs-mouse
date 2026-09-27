# 运行模型与首版实现约定

2026-09-26 连续战役更新：一局改为厨房场景内五大关共四十小关，场外只选场景；跨大关继承阵地、热量、粮仓和食谱。奖励流水使用全局 1～40 关号，存档迁移至 v4；当前权威规则及旧版差异见[连续战役](../design/campaign.md)。本文中的历史八关验证不代表新版整局通过。

卡片体系更新（2026-09-25）：已接入有限携卡和永久强化快照；ShopController 仅负责食谱，MetaProgression 负责局外卡片，SaveService 使用 v2 单文件事务。详见 [实施规格](card_progression.md)。下文旧星级、v1 分文件结算与卡片商品部分保留为历史记录，冲突处以新版规格为准。

状态：设计已确定，按提交逐步实现；验收状态见 [验证记录](../testing/implementation.md)。上游：[玩法基线](../TODO.md)。

## 模块与时间

入口 front_end 场景管理主菜单、游戏实例与结束页（见 [页面流程](../design/screens.md)）；游戏场景拥有 RunController；它组合独立 RefCounted 控制器与 RunState，不使用 Autoload。UI 只发送请求，业务层检查阶段、暂停、费用、冷却和占用。BoardController 管理格子，CombatController 统一伤害／状态／弹体，WaveDirector 管理生成表，ShopController 管理交易，RecipeSystem 管理候选与修正，SaveService 管理独立局外与关间文件。

生产火苗作为 CombatController 临时状态，由 RunController.collect_heat(uid) 接收 UI 拾取请求并校验阶段／暂停；固定步长推进飞行，到达后统一结算热量。表现节点 HeatPickupView 只读取火苗状态，坐标命中与绘制共享投影。数据、合并、清理和完整边界的权威说明见 [热量设计](../design/heat.md)。

每帧以同一游戏 delta（真实 delta × 1 或 2）推进，暂停 delta 为零；以 1/60 秒固定步长执行模拟。伤害先处理死亡、后检查漏怪，步末先判粮仓归零，再按 [小关结束条件](../design/waves.md#小关结束条件2026-09-26) 判最后计划投放后的 10 秒倒计时结束；大关末关额外要求 BOSS 已被击败。RunController 在每次开战重置 boss_defeated，由 CombatController.enemy_killed 确认对应 boss_id 的真实击杀，漏怪或集合清理不算击败。死亡和漏怪从集合移除，每个实体只结算一次。弹体不追踪死亡目标，普通弹命中沿路径首个敌人；穿透记录已命中 ID。攻击计时首次等待完整间隔，生产亦然。

定义使用带稳定 ID 的自定义 Resource，stats 存放可调参数；实例加载后只读。运行实体为独立字典，uid 仅局内身份。运行状态保存基础数据，不保存对象引用。跨模块通过显式方法和信号：CombatController.unit_died(food_id)、enemy_leaked(damage)、enemy_killed(enemy_id)；RunController.changed 通知 UI，阶段只由 RunController 切换。

已接入的表现专用 `food_hurt(unit)`、`food_fallen(unit)` 信号与小笼包死亡快照的时点和生命周期统一在 [动画接口](../art/animation.md#f-小笼包逐帧接口2026-09-25) 维护；这些表现数据不参与逻辑存档或胜败判断。

## 随机与生成

单个显式 RandomNumberGenerator 属于 RunController，消费顺序为各小关开战生成表，仅大关通关后生成食谱商品；新局与普通关不消耗商店随机数。保存种子与 rng.state；表现不使用此随机源。各关生成方式、组合批次及随机路线约束统一见 [组合鼠潮](../design/waves.md)。WaveDirector 保持 time/id/row 事件接口。

## 阶段与边界

prepare → battle → prepare，最终进入 won/lost。关后收取剩余灵感、结算通关灵感与免费恢复并保存；普通关自动开战，仅大关通关后开店；不再存在独立灵感／免费选谱阶段。商品、交易与旧快照迁移规则见 [食谱购买](../design/shop.md)。准备阶段是每小关可恢复快照，是否购物由 ShopController.is_open() 判定；普通快照自动尝试开战一次，失败等待手动重试；购物完成后通过 RunController.start 保存快照并开始本关，付费维修已移除。升星保留损失生命的绝对值；移动交换使用同一对象。

## 验收

覆盖交易原子性、重复操作、满盘放置边界、死亡／漏怪竞争、跨关恢复、星级公式、种子复现、存档往返与损坏，以及 Godot 导入和真实窗口操作。版本 1 存档只接受已知 ID、合法阶段／格子／数值；局内损坏不影响独立局外文件。目标时长与构筑强度均需试玩验证，不从自动化通关推断。

## 存档、解锁与开发入口细化

局内 JSON 保存版本、随机种子／状态的十进制字符串（避免浮点精度损失）、运行 ID 及 RunState 字段。临时文件完整关闭后原子改名覆盖。准备购买／刷新成功后保存；开战前也保存。局外文件保存累计击杀、已解锁食谱、上次已结算运行 ID，先写局外再移除局内快照，防止重复结算。胜败及主动重开视为本局结束；关闭窗口仅回滚本关，不结算该次未完成战斗。局外损坏单独提示；未知版本／非法字段拒绝恢复。

开发面板仅 `-- --dev` 且调试构建开启，允许指定种子、准备阶段跳到指定关、加资源，显示各路敌人生命总量。发行导出不接受此入口。压力验证独立场景，直接构造 40 个美食和 100 个敌人用于性能测量，不算正常通关。

输入：`open_settings` 为 Esc，`cancel_selection` 为右键（设置与暂停规则见 [设置设计](../design/settings.md)），`board_select` 为左键，`debug_panel` 为 F3；仅查看与速度／暂停控制在暂停时可用。主菜单覆盖旧局有确认；首关步骤式引导已取消，详情与反馈依据 [UI 规范](../art/ui.md#提示栏与引导移除2026-09-13)。当前角色采用 [F 风格生成资产](../art/f_restyle.md)，背景与食谱采用既有生成图集，UI 和状态由程序绘制，音乐与音效由项目内离线脚本生成；无外部音频素材依赖。真实美术质量与玩法可读性列入试玩验收。

性能实现：每个模拟步在弹体伤害结算后收集鼓手来源，移动只查询该集合；已死亡或越界来源立即排除。UI 缓存两种格子 StyleBox，不在每帧创建 40 个 Resource。两项均不改变数值与随机源消费顺序。

## 棋盘几何扩展（2026-09-13）

当前几何为 7 行 × 9 列，详见 [棋盘布局](../art/perspective.md)。RunState 提供共享行列与宽度常量；业务边界、生成中央行、随机召唤范围、存档格子唯一键和表现映射统一采用新几何。版本 1 存档继续保留原坐标；全盘保存上限改为 63。新旧范围与实际检查见 [布局验证](../testing/layout.md)。


## 卡牌拖放接口（2026-09-13）

已实现并通过相关回归：BoardController.placement_error(id, row, col, paused) 提供无副作用的放置合法性查询，返回空字符串或失败原因；place 在写入前复用该查询，保证预览与结算使用同一规则。主场景只持有临时拖动 ID、起点、阶段／暂停快照和阈值状态，不写 RunState。左键按下由卡牌 gui_input 发起，移动和松手由主场景 _input 接收；取消与生命周期清理不触发业务操作。规则见 [UI 规范](../art/ui.md#美食卡拖放2026-09-13)。

## 菜单入口（2026-09-25）

`scenes/front_end.tscn` 为项目启动入口，只读检查快照；用户选择后创建并初始化 RunController，注入 `scenes/main.tscn` 的 run 成员。main 仅在未注入状态时执行自身读档／初始化，以保留独立场景与既有测试入口。front_end 在 won/lost 时隐藏并禁用游戏场景处理，展示只读战报；离开时使用 SaveService 的幂等结算重试，成功后释放旧游戏实例。QA 注入的存档目录不被 main 覆盖。无新增 Autoload 或存档字段。

## 伤害表现事件（2026-09-25）

CombatController 在统一扣血入口新增 `damage_resolved(unit, actual, is_food, direct)`，减伤与过量伤害处理后发送。DamageFeedback 只订阅并展示，不反写运行状态；载荷语义、shader、飘字和清理规则统一见 [受击反馈](../art/damage_feedback.md)。原有受击与死亡信号保持原时点，继续驱动 UnitAnimator。

## 状态与技能表现事件（2026-09-26）

CombatController 的 `skill_used(effect_id, source, targets)` 与 BoardController 的 `healed(unit)` 驱动 StatusFeedback。状态来源、载荷、绘制层级、寿命、恢复事件跨阶段例外和验收规则统一见 [状态特征与技能表现](../art/status_effects.md)。鼓舞表现和移动速度共用 `is_drummer_boosted(enemy, sources)`，邻接 Buff 使用 RecipeSystem.adjacent；表现不反写战斗、不消费随机数、不加入存档。

## 铲除表现接口（2026-09-25）

BoardController.remove(row, col, paused) 移除旧 confirmed 参数；成功移除发送 removed(unit)，空格不发送。ShovelFeedback 订阅当前 board 并复制绘图所需的纹理与位置，不保留可变单位引用；绑定新局时断开旧信号并清空快照。主场景用统一 visual_delta 推进，在棋盘角色后、界面前绘制。规则及验收依据 [UI 规范](../art/ui.md#直接铲除与动画2026-09-25)。

## 关前难度（2026-09-26）

DifficultyDef 与 RunState.difficulty、RunController.new_run 的整局难度参数、生成倍率和旧档默认值见 [难度设计](../design/difficulty.md)。创建新局时持久化选择，所有局内阶段均不可修改；不改变随机源调用。

## 音频表现服务（2026-09-26）

入口拥有 `SoundService` 并注入 main 与 CardHub，独立 main 运行时自行创建；不使用 Autoload。`bind_run` 管理业务信号的订阅和解绑，阶段变化驱动七种音乐场景。`CombatController.heat_collected(pickup)` 仅在火苗首次进入飞行时发送，飞行过程或重复点击不重发。音频只观察事件，不改写玩法和随机状态。AudioProfile／AudioCueDef 保存音频路径、混音、冷却与优先级；AudioSettings 承担统一设置 UI，音量由 SoundService 独立保存，并在战斗中打开时暂停；通过 menu_requested／quit_requested 请求 front_end 导航，保存失败仍留在窗口。完整配置、生命周期、暂停和速度边界见 [音频设计](../art/audio.md)。

## 灵感掉落与热量经济（2026-09-26）

热量跨关保留并用于食谱／刷新，金币删除。CombatController 独立掉落 RNG、拾取物与飞行计时；RunController.collect_inspiration 先调用 SaveService.collect_inspiration 成功记账，再启动飞行；同关重新开始以最高收集累计防刷。失败写入保持拾取物，关末自动收取若失败则暂停并允许恢复后重试；粮仓归零仍优先判负。SaveService 在 v2 快照与流水添加可选 inspiration_collected 字典，旧 coins 忽略，既有余额与奖励保留。权威边界与参数见 [经济设计](../design/economy.md)。
