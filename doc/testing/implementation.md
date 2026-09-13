# 分步实施验证记录

状态：持续更新；未列为通过的验收均未完成。日期：2026-09-13。环境：macOS、Apple M4、Godot 4.6.3 stable、Compatibility OpenGL 4.1 Metal。

## 步骤 1：战斗骨架

- 建立主场景、资源定义、独立运行状态、阵地／战斗／波次／流程模块，初始三卡与第一关。
- `--headless --editor --import`：脚本与资源无解析错误。本机沙箱无法保存全局编辑器配置；系统证书读取产生环境错误。后续运行指定 `/tmp` 日志避免 Godot 在沙箱无法创建 user 日志时崩溃。
- `--headless --log-file /tmp/fvm-run.log --quit-after 120`：退出 0，无脚本错误。
- `--headless --log-file /tmp/fvm-test.log --script tests/test_core.gd`：8 项通过，含放置重复／冷却／费用、暂停、弹体击杀、粮仓归零优先。
- 真实游戏窗口：确认中文显示、5×8 阵地、卡牌、开战、放置、热量扣除、暂停反馈和入口提示。当前为原创程序绘制占位视觉。
- 完整第一关人工游玩、缩放、取消和失败后重开尚待最终视觉回归；不能据此宣称第一里程碑全部验收通过。
