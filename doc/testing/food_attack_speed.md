# 美食攻速与布丁产量验证

日期：2026-09-26。状态：已实现，专项回归通过。范围：内容数值和平衡迭代，权威规则见 [玩法基线](../TODO.md)。

六种攻击美食的基础间隔翻倍，攻击频率降为当前值的 50%。保留工作区已有伤害和生产调整。验收覆盖资源字段、首次与连续攻击计时、光环／减速公式、相关回归和 Godot 导入／场景加载。

## 验收边界

本次不修改 UI 或输入；原生视觉、人工交互、完整四十关平衡及发行包尚未复验。

## 实际验证

环境：macOS，Godot 4.6.3.stable.official.7d41c59c4，本次工作区。

- 与修改前八份资源逐字段比较：仅六种攻击美食的 interval 翻倍，其他字段和两种非攻击美食均保留原工作区值。
- 七组既有回归通过：`test_core`（72 项）、`test_builds`、`test_status_feedback`、`test_enemy_abilities`、`test_chapter_bosses`、`test_heat`、`test_wave_completion`。覆盖弹体击杀、伤害构筑、蒜香光环、面粉／醒面修正、生产、暂停倍速及关卡结束。首次攻击等待完整间隔的既有逻辑未修改，静态检查确认从资源读取新间隔。
- 状态反馈测试的小笼包光环期望改为 `3.0 / 1.15`。核心弹体测试初次因旧 30 秒窗口不足失败；改用隔离波次的 CombatController 固定步长推进 55 秒，敌人初始位置移至 760，保留敌人属性、实际弹体伤害与击杀断言，复验通过。
- Godot 导入完成，主场景无界面运行 120 帧退出码为 0，无新增脚本解析或资源引用错误。日志仍有 macOS 系统证书读取错误；导入另报沙盒无法保存用户目录编辑器设置，主场景退出有 ObjectDB／资源未释放提示。
- 执行方式：Godot `--headless --path . --log-file /tmp/food-speed-<name>.log --script res://tests/test_<name>.gd`；导入用 `--editor --import`，场景冒烟用 `--quit-after 120`。`git diff --check` 通过。

本次未做新的首次／连续攻击逐帧窗口验收，不将无界面测试视为视觉验证；完整四十关平衡、性能及发行包未重新验证。

## 攻速增加 50% 与布丁产量翻倍（2026-09-27）

状态：已实现，八组相关回归通过；额外边界回归受存档权限限制。范围：内容数值和平衡迭代，当前数值以 [玩法基线](../TODO.md) 为准；上文为历史记录。

- 六种攻击美食 interval 除以 1.5；布丁基础 production 翻倍，生产周期沿用 15 秒。「焦糖加倍」固定收益仍为 5。更新既有热量与光环测试期望，验证基础火苗 30、强化与食谱火苗 41、跨周期合并 71、到账及溢出。
- 环境：macOS，Godot 4.6.3.stable.official.7d41c59c4，本次工作区。保留原有 project.godot 用户改动。
- 通过：test_core（72 项）、test_builds、test_status_feedback、test_enemy_abilities、test_chapter_bosses、test_heat、test_heat_ui、test_wave_completion。覆盖伤害、光环／减速、生产周期、生成时快照、暂停倍速、点击防重、飞行到账与关卡生命周期。
- Godot 导入及主场景无界面 120 帧加载完成；无新增解析或资源引用错误。仍有系统证书读取、编辑器设置目录写入权限及退出资源未释放日志。
- 额外 test_edges 在创建 user://qa_grid_* 与保存测试快照处失败，随后超时终止；受当前沙盒目录权限限制，本次不记为通过。
- 执行：Godot --headless --path . --log-file /tmp/food-buff-<name>.log --script res://tests/test_<name>.gd；导入使用 --editor --import，主场景使用 --quit-after 120。git diff --check 通过。

本次数值调整未执行新的原生视觉或人工交互验收；无界面输入回归不等同于人工验证。完整四十关经济／战斗平衡、性能和发行包未复验。
