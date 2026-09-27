# 后四大关鼠群成长加快

日期：2026-09-27。状态：已实现，六组相关回归与导入检查通过，整局平衡待验。属于内容数值和平衡迭代。

规则以[编排属性曲线](../design/chapter_encounters_v2.md#属性曲线)为准。验收覆盖配置字段、章间连续成长、普通／精英的难度倍率、技能／护盾、BOSS 固定基础属性及召唤物、Godot 导入和主场景加载。

## 实际验证

环境：macOS，Godot 4.6.3.stable.official.7d41c59c4，本次工作区。

- 32 份波次资源逐字段与修改前比较：生命／伤害符合新曲线，其他 stats 字段一致；2-1 数值保持原值，实际修改其余 31 份资源。第一大关、敌人基础资源和难度资源未修改。
- 六组既有回归通过：test_campaign_content（40 关、3200 个种子排程）、test_chapter_bosses、test_enemy_abilities、test_boss_difficulty、test_core（72 项）、test_wave_completion。同步更新铆壳鼠与总管援军的两处固定生命期望，保留实际战斗与技能验证。
- 导入和主场景无界面 120 帧加载退出码均为 0，无脚本解析或缺失引用错误。仍有 macOS 系统证书读取错误；导入报告沙盒无法保存用户目录编辑器设置，主场景退出有资源未释放日志。
- 执行命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/food-growth-<name>.log --script res://tests/test_<name>.gd`；导入使用 `--editor --import --quit`，主场景使用 `--quit-after 120`。
- `git diff --check` 及本次修改文档的本地链接检查通过。

原生视觉、人工交互、整局四十关平衡、性能与发行包未复验，不将无界面运行视为视觉通过。
