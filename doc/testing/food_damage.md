# 美食伤害减半验证

日期：2026-09-26。环境：macOS，Godot 4.6.3.stable.official.7d41c59c4；本次工作区版本。范围：内容数值与平衡迭代；规则见 [玩法基线](../TODO.md)。

## 变更

六种攻击美食的基础直接伤害与「小火慢烤」固定灼烧伤害减半；吐司、布丁保持零伤害。其余配置、倍率和伤害结算顺序不变。更新既有构筑测试的新伤害期望，并把基础弹体击杀测试观察时间从 10 秒延长为 15 秒，以适应输出下降，不改变敌人或击杀条件。

## 实际验证

- 对八份 FoodDef 与 HEAD 逐字段比较：damage 均为原值 50%，其余字段完全一致。
- Godot `--headless --path . --editor --import` 完成，未出现脚本解析或资源引用错误；沙盒阻止保存用户目录的编辑器设置，日志另有 macOS 系统证书读取错误，不将此次运行描述为零错误。
- 七组回归通过：`test_core`、`test_builds`、`test_meta_progression`、`test_damage_feedback`、`test_enemy_abilities`、`test_wave_completion`、`test_heat`。执行方式为 Godot `--headless --path . --log-file /tmp/food-damage-engine-<test>.log --script res://tests/<test>.gd`。
- `test_builds` 使用新小笼包基础值验证 +10 与早餐倍率，并读取实际灼烧配置验证绕过护甲的伤害。
- 默认日志目录在沙盒内不可写，首次测试因此启动失败；改为 `/tmp` 日志后复验。局外成长测试的 `user://qa_meta_*` 测试存档同样不可写，首次断言后超时；仅将临时脚本副本的测试目录替换为 `/tmp/food_damage_qa_meta_*` 后通过，未改正式存档路径。
- 主场景无界面运行 120 帧退出码为 0，无新增解析错误；退出时报告 ObjectDB／1 个资源仍在使用，以及系统证书读取错误，未在本次纯数值调整中扩大修复范围。
- `git diff --check` 通过。

## 验收边界

本次未修改交互或美术，未执行原生视觉／人工交互复验、完整四十关平衡采样、性能测试或发行包导出。既有平衡报告不代表伤害减半后的难度已通过。固定护甲保持原值，实际扣血可能低于旧值的 50%。
