# 热量消费与灵感掉落验证

状态：2026-09-26 已完成自动回归和原生渲染；真实鼠标复验受限，完整八关平衡未验。实现依据 [经济设计](../design/economy.md)，归属肉鸽闭环、使用体验与平衡迭代，不据此将完整里程碑标记通过。

## 环境和命令

当前未提交工作区；macOS、Apple M4、Godot `4.6.3.stable.official.7d41c59c4`，原生窗口 OpenGL 4.1 Metal Compatibility。测试使用独立 `user://qa_*`，未改玩家正式档。命令中的 Godot 为本机 `/Applications/Godot.app/Contents/MacOS/Godot`。

- `Godot --headless --path . --editor --import --log-file /tmp/food_economy_import.log`：通过，新增源脚本 UID 已生成，无解析或丢失引用错误。
- `python3 tools/run_tests.py`：运行时已有的 34 项全部通过；随后新增 `test_inspiration_ui.gd` 独立补跑通过，共 35 项。最终存档边界收紧后再次运行 `test_economy.gd`、`test_inspiration_drops.gd`、`test_inspiration_save.gd`，均通过。
- `Godot --path . --log-file /tmp/food_economy_window.log --script tests/economy_gallery.gd -- --qa-test --hold`：原生 Compatibility 场景通过，测试结束已关闭该验收进程。
- `test_inspiration_ui.gd` 同时在原生窗口和 headless 运行通过；通过 Viewport.push_input 走实际 GUI 事件分发，非真实鼠标手动操作。

早期沙盒运行出现 macOS 系统证书访问告警，另一次无指定日志路径启动因 user://logs 写入失败而退出；使用明确日志路径和批准的原生运行权限后，最终上述测试无对应错误。不将早期受限启动记录作通过。

## 覆盖与结果

| 范围 | 实际结果 |
|---|---|
| 热量商店 | 不足、精确余额、重复购买、非法阶段、刷新两次上限和空池通过；开战不退回购物支出，剩余热量跨关和存档保留 |
| 金币取消 | 运行脚本、场景及规则无金币余额／通关金币逻辑；新快照不含 coins，旧字段忽略不兑换 |
| 掉落 | 0%／100%、各难度概率、普通／精英／首领／召唤物、重复伤害、燃烧死亡、漏怪及 debug 分支通过；独立 RNG 同种子复现且不改变玩法 RNG |
| 拾取 | 点击先入账再飞行、重复点击、飞行到顶栏、暂停冻结／禁止拾取、2×、末鼠自动收取、失败清理通过 |
| 胜败竞争 | 同帧击杀与致败漏怪优先判负，未收取掉落不自动入账，已收值保留 |
| 原子存档 | 点击立即可读取局外余额；关前阵地／热量／RNG 不被战斗进度覆盖；写失败不标记拾取、恢复后可重试；部分自动收取成功后失败不会重付 |
| 重打与迁移 | 同关较低／相等累计不重付，仅高于历史累计补差；旧 v1/v2、缺字段、历史余额／卡片／奖励保留，非法／未来关记录拒绝 |
| 局外消费 | 失败保留的实际拾取收入经 MetaProgression 正常购买卡片成功；胜败／放弃／重复结算不重复支付拾取 |
| UI 输入 | 热量不足灰显、真实 GUI 点击扣费、弹窗阻断、灵感与火苗重叠优先级、选卡／锅铲不误触、飞行越过卡牌不选卡、顶栏及战报统计一致 |

## 原生画面与限制

`tests/economy_gallery.gd` 生成并目视检查 1280×720 和 1600×900 下的小铺与战斗四张 PNG，位于 `/tmp/food_economy_{shop,shop_large,battle,battle_large}.png`，不纳入仓库。食谱单价、刷新价、热量余额与跨关提示完整；紫色四角灵感、橙色火苗、飞向顶栏的表现可区分，无新增重叠或裁切。

真实鼠标复验尝试使用 CUA 获取 Godot 应用及窗口列表；工具持续绑定 `meta_manual.tscn - food-vs-mouse - Godot Engine` 编辑器，仅列出该窗口，无法指定独立测试进程。因此未宣称完成系统鼠标点击与手动缩放；已完成的输入覆盖来自原生运行中的 GUI 事件测试。完整八关真人体验、掉落／价格与布丁跨关资源经济、密集拾取磁盘写入性能和发行包更新均未验证。

## 用户指定数值调整（2026-09-26）

状态：已实现并完成相关验证。现行数值以 [经济设计](../design/economy.md) 为准：三档击杀掉落概率独立保存于 DifficultyDef，删除 ProgressionDef 的旧基础概率；通关奖励倍率仍沿用原规则，价格读取 rules.tres。旧存档余额与已购食谱保持，未购商品应用当前价格。

同一 macOS／Apple M4／Godot 4.6.3 环境，导入检查 `/tmp/food_retune_import.log` 通过，无解析或资源错误。此次按影响范围运行九项回归：`test_economy`、`test_builds`、`test_save`、`test_ui`、`test_inspiration_ui`、`test_difficulty`、`test_difficulty_rewards`、`test_inspiration_save`、`test_inspiration_drops`，全部通过。掉落测试逐档用 2,048 次实际死亡检查随机阈值，并把通关收益倍率改为 7 后验证掉落结果不变；保留独立 RNG、0%／100%、非法概率、暂停、死亡与失败边界。交易测试验证新价下不足、精确余额、重复操作、跨阶段拒绝、刷新上限和实际扣费后的存档恢复；初始 150 热量对应食谱禁用、购物完成仍可点击。

重新运行原生 `tests/economy_gallery.gd`，并目视检查 1280×720、1600×900 的小铺截图：500 热量食谱、100 热量刷新、初始余额不足提示和通关收益说明均完整，无新增截断。图像仍输出到上文临时路径，未纳入仓库。此次未重复全量 35 项、系统鼠标人工复验或完整八关平衡，也未更新发行包。
