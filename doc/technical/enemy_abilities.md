# 章节鼠群技能运行接口

日期：2026-09-26。状态：技能逻辑已实现，专项及相关既有逻辑回归通过；画面、交互和整局平衡由集成验收另行记录。玩法与参数权威来源为 [鼠群重设计](../design/chapter_enemy_redesign.md)，本页约定代码边界与 UI 接口。

## 模块与时间

`CombatController` 继续拥有敌人列表、移动、普攻、统一伤害与死亡。新增 `EnemyAbilities` 由战斗控制器持有，反向使用弱引用，维护技能动作、锁定目标、护盾、酸格、醒面和订单；不持有场景节点。定义数据只读，运行值存于单位字典和处理器集合。

`step(delta)` 接受游戏时间。新技能单位或地面效果存在时，将大时间步拆为不超过 1/60 秒的小步；正常 `RunController` 已使用同等小步，不额外乘倍速。各步先推进临时状态，随后结算美食出手、弹体、鼠群灼烧，再推进新技能、地面效果及订单；这样本体致死可取消同一步到时的技能。旧第一章鼠大厨的召唤与狂暴接口保持。

移动统一查询前方最近美食，按接触边界截断位移，冲刺不穿越阻挡。所有技能伤害调用 `damage_enemy` / `damage_unit`；酸液持续伤害显式标记为非直接伤害，吐司直接减伤只处理直接命中。技能暂停普攻并清零积攒，普通溜勺疲劳允许普攻是设计明文例外。

## 配置字段

`EnemyDef` 新增 `rank`、`behavior_id`、`art_id`、`skills`；旧鼠 `behavior_id=legacy`。`stats` 仍保存 hp/speed/dps/leak，以及可选 armor_hits/armor。以下字段均在定义资源保存，脚本不另设平衡值。

| behavior_id | skills 字段 |
|---|---|
| skater | interval, windup, dash_speed, dash_duration, recovery_speed, recovery, segments, segment_pause |
| scout | windup, entrance_min, entrance_max, clearance |
| rivet | unarmored_speed |
| breaker | interval, windup, damage, recovery；监工另有 unarmored_speed |
| acid | interval, windup, reach, damage, tick_damage, tick_interval, ground_duration, max_rows |
| dough | interval, windup, shield, shield_duration |
| ration | interval, windup, reach, shield, shield_duration, supplies |
| skewer | splash_reach, splash_ratio；督运另有 threshold, windup, shield, shield_duration |
| windwhistle | interval, rage_interval, threshold, windup, dash_speed, dash_duration, damage, recovery, rage_recovery, exposed |
| ironpot | shield, interval, rage_interval, threshold, windup, damage, recovery, exposure_duration, exposed |
| starter | interval, reach, windup, ground_duration, damage, recovery, exposed, threshold, max_targets, rage_max_targets, slow_penalty |
| quartermaster | initial_delay, thresholds, windup, order_gap, observation, failure_duration, exposed, shield, shield_duration, rows, order_ids |

未知敌人 ID、非法行或缺少波次时 `spawn` 返回空字典，既不新增实体也不发送生成信号。未知 behavior 仅运行普通移动与普攻，不能意外继承首领技能。资源合法性仍由 Catalog 校验。

`WaveDef.stats` 的 `boss_id/elite_id` 标明新特殊敌人；`balanced_lanes` 选择新均衡选路。批次可带 `exclude_rows`（首领前尾波避中央行）与 `avoid_previous_ids`（精英入场避开上一批指定威胁行）。仅新编排启用均衡逻辑，第一章旧随机消耗保持；普通 composition 含本波精英或首领，订单援军另由 skills.order_ids 生成，不混入计划数。具体生成规则由 [32 小关编排](../design/chapter_encounters_v2.md) 维护。

## 单位与表现字段

所有实体提供 `rank/art_id/hp_scale/damage_scale`，缩放在生成时确定。附加运行字段：

- `ability_phase`：normal / windup / action / recovery；`ability_remaining`：当前动作剩余游戏秒；`ability_duration`：当前动作开始时的总游戏秒数，初始及 normal 状态为 0，供表现层按自身时长映射动画帧，不参与结算；`ability_title`：当前动作中文名。
- `shield/shield_max/shield_time`：当前盾、此次完整容量及剩余时间；铁釜开场盾 `shield_time=-1` 表示无自然到期，盾破仍正常取消。
- `exposed/exposed_time`：承伤倍率及剩余秒；无暴露为 1 / 0。`armor` 沿用既有剩余命中数。
- `ration_stock/ration_received`：来源剩余份数、目标本小关是否领取过配给；同帧发放按敌人 UID 升序处理，成功后立即标记。
- `order_index`：当前 0 基订单，尚无订单为 -1；`order_remaining`：尚未落地数量；`order_status`：idle / warning / active / success / failed / done；`order_time`：观察期剩余时间。
- 美食 `proof_time/proof_penalty`：醒面覆盖剩余时间与攻速惩罚；RecipeSystem 与 flour 取最强，生产者不受影响。处理器每步依据有效地面覆层刷新，取消及时撤销。

处理器内部一次性标记、动作计时和目标 UID 不加入关前存档；`clear()` 全部清空，并从美食字典删除 `proof_time/proof_penalty`，而非保存两个零值字段。既有 `SaveService` 无需为敌人现场新增序列化字段。

### 预警与地面效果

UI 只读 `combat.abilities.telegraphs: Array[Dictionary]` 和 `ground_effects: Array[Dictionary]`。预警字段为 `uid/source_uid/skill_id/kind/row/x/rows/cells/target_uid/remaining/duration/end_x`；cells 是 `{row,col}` 数组，rows 为 0 基行。`kind` 与 `skill_id` 采用 dash / switch / heavy / acid / proof / ration / order；换路 rows 精确为来源及目标两行，冲刺 end_x 为当前规则下最远可达点。

地面效果提供 `uid/source_uid/skill_id/kind/row/col/remaining/duration`；kind 为 acid / proof。酸液同格只有一条跳伤时钟，首次落地后满 tick_interval 才跳；后续加入仅更新来源期限，跳时从未过期来源取最高伤害，不新增时钟。每一来源的最后期限仍可产生终末一跳，之后清理。醒面爆开只命中该格当前美食。

`skill_used` 的新增事件 ID 是 dash/switch/heavy/acid/proof/ration/order（实际执行）以及 shield/exposed/armor_break/skewer/order_success/order_failed。source 包含实际 uid/row/x 和 skill_id，targets 是实际目标；表现不能用事件重算伤害或随机路线。地面预警取消后直接从集合移除，已取消攻击不留“即将落地”的提示。

## 结算与清理

伤害依次为来源增伤、暴露、直接固定护甲、盾、本体；反馈伤害和统计包含实际消耗盾与生命的总额，非实际溢出不计。铁釜破盾后的暴露从下一次伤害生效，致死不进入暴露。所有临时盾遵守单槽取强；点心匣另外检查无盾、未领、库存三项，取消不扣库存。

普通酸液已经落地后保留至期限，即使来源死亡；首领死亡移除自己的覆层及未完成订单，已落地护送鼠继续计清场。援军 UID 与订单显式关联，漏怪仍扣粮，但对应订单失败。第 14 秒的到期检查放在本步伤害和敌人漏怪结算后，避免同一步两鼠均死却算成功。

## 验证计划

新增 `test_enemy_abilities.gd` 与 `test_chapter_bosses.gd` 覆盖技能节拍、数值缩放、护盾取强、锁格与 UID、取消、同帧死亡、三单上限、暂停/倍速、大步等价及旧鼠大厨兼容。完成后在本页记录实际命令与结果；原生画面和交互由 UI 集成交付另验。

### 本轮实际验证

2026-09-26，macOS，Godot `4.6.3.stable.official.7d41c59c4`。所有测试使用既有独立 QA 目录，无正式档案读写。受限环境首次运行出现 macOS 证书访问通告，`test_edges` 的 QA 目录写入被限制；停止该次运行后使用获准的本机环境复验，没有把受限失败计为通过。

原生权限下实际执行并通过：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/enemy_abilities_final_import.log --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_enemy_abilities.gd -- --qa-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_chapter_bosses.gd -- --qa-test
```

两项新增专项通过，无脚本错误；同样运行并通过 `test_content`、`test_boss_difficulty`、`test_edges`、`test_status_feedback`，`test_core` 也已通过。检查覆盖四位首领独立循环、三单排队和上限、酸液同格单时钟、目标新 UID 不继承旧锁定、有限配给、破盾溢出、半血残壳只露腹一次、灼烧与醒面爆开同一步时优先取消、订单到期同时援军致死优先失败，以及 16 秒大步和 960 次小步结果一致。初次大步比较发现浮点边界少结算一次普攻，统一计时容差后复验通过。

交付前追加 `test_enemy_presentation.gd`，不加载角色图集而实际调用新表现层绘制：幂等绑定、重开解绑、阶段清理、53 个有效预警在 48 项装饰上限下保留、绘制不改变 RNG 或业务快照、暂停/2×、关前去除醒面字段与恢复无减益、四位新首领不串用旧波次无限召唤。该测试通过；纯数据与无界面绘制仍不代替原生窗口的视觉判断。

为独立技能图集补充 `ability_duration` 后，再次运行 `test_enemy_abilities` 与 `test_chapter_bosses`，两项通过；新增断言确认初始化、动作切换、倍速推进期间总时长不递减，以及回到 normal 后清零。该字段只供表现读取，未改变战斗计时或平衡参数。

技能帧选择接入后追加并通过表现专项：真实夹钳重砸在命中步已进入 recovery 时仍先选 execute，暂停不换帧，随后切换 recover，死亡副本不再选择技能帧。真实点心匣配给分别覆盖夹钳、酵团与红签接收者；接收外部护盾不播放主动施法。测试发现按鼠种判断盾动画会误认酵团和红签的外部配给，表现层现于事件发生时记录是否正在完成自身护盾动作，并据此过滤。

Godot 导入完成并生成新增脚本与测试 UID；`git diff --check` 通过。本节只证明实际执行的逻辑检查。完整全量回归、三难度连续采样、原生技能画面、真实鼠标、画面性能及发布由主线程集成记录，不在此预先计为通过。

### 战斗逻辑短时压力采样

2026-09-26，在 Apple M4、macOS、Godot `4.6.3-stable (official)` 上以获准的本机 headless 运行临时采样脚本。场景从 120 只新鼠（112 只普通鼠、4 精英、4 首领）与 42 个美食开始，采用第五章第 8 关、简单难度的真实定义与属性；只错开技能起始相位，使多组预警和地面效果同时发生。单位受到正常伤害，不补充死亡单位。脚本放在系统临时目录，不新增永久测试或改动平衡资源。

固定每步 1/60 游戏秒，热身 1 秒后测量 10 秒，共 600 步。总耗时 3.208914 秒，平均每模拟秒耗时 **0.320891 秒**，平均每步 **5.348 毫秒**；每模拟秒的分段耗时范围为 0.299715–0.343119 秒。期间鼠数为 113–120，结束时 115；42 个美食均存活。发生 67 次技能事件，峰值为 23 个有效预警和 7 个地面效果；600 步中有 599 步存在预警、289 步存在地面效果。

该采样包含战斗与技能结算，不含角色图集、实际窗口渲染或输入；运行时其他 QA 工作也可能影响耗时。此结果不能推定 GPU 开销、原生帧率或长期稳定性能，只说明上述短时负载的实际逻辑开销。
