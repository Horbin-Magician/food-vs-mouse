# 战斗环境与 HUD 验收

日期：2026-09-25。状态：实现、导入及原生渲染通过；真实鼠标复验未完成。范围：本工作区战斗美术改动，设计见 [战斗环境](../art/battle_environment.md)。

环境：macOS、Apple M4、Godot 4.6.3.stable、Compatibility / OpenGL 4.1 Metal。测试使用隔离 QA 存档，不覆盖玩家进度。

## 已执行

- `Godot --headless --path . --editor --import --quit`：新增背景与 BattleArt 类导入成功，无解析错误或缺失引用。
- `python3 tools/run_tests.py`：20 组现有测试全部通过，涵盖业务、存档、投影、UI、拖放、热量、锅铲与直接铲除。卡牌居中区域最终调整后再次执行 `test_ui.gd` 通过。后者退出有 ObjectDB instances leaked 警告，未定位来源，不宣称资源泄漏检查通过。
- 原生 `tests/shop_flow_gallery.gd`：购物及战斗屏幕运行、捕获；未报新增脚本错误。
- 原生 `tests/battle_art_gallery.gd`：1280×720 与 1600×900 截图并目视检查。八卡、冷却遮罩、费用不足灰显、14 个美食及七路老鼠、热量／耐久／金币、底部暂停与波次文本均可见；卡牌右沿不超过 830 的断言通过。棋盘位置与面积不变，入场角色与右侧信息牌无交叠。
- 最终 1280×720 画面归档为 [预览](../art/previews/battle_environment.png)。背景原图 1672×941；没有修改原厨房图或角色图集。
- `git diff --check` 通过。

## 未完成与限制

尝试通过 cua 选择 Godot 原生窗口进行鼠标复验，但工具只返回已有编辑器窗口，未提供独立游戏进程的可选择窗口；当前平台的 `listWindows` 不可用。因此不将自动输入或原生截图描述为真实鼠标验收。新布局下鼠标拖放、取消、暂停及非默认缩放的真实交互仍待复验。未执行完整真人试玩、性能测试或重导发行包；不据此标记使用体验／平衡里程碑通过。
