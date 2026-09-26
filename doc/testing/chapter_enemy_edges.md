# 新鼠图集边界碎片修复

日期：2026-09-26。状态：已实现，边界专项通过。
环境：macOS / Apple M4，Godot 4.6.3.stable.official.7d41c59c4，Compatibility / OpenGL 4.1 Metal。
设计及整理规则见[资产记录](../art/chapter_enemy_assets.md#5-边界碎片修复2026-09-26已完成)。本次基于已有未提交工作区，仅整理新鼠运行图和对应文档；其他数值、动画代码等用户改动保留。

## 原因与修复

原稿直接作为运行图集使用，部分角色的尾巴、道具跨出名义分格；技能原稿还有 1774×887 等非目标尺寸。运行时按固定行列裁片，导致相邻主体的残片进入当前帧。修复前 `test_enemy_art.gd` 退出码为 1，报告 Gutter、Overflow/baseline、Atlas dimensions。

用户明确授权后执行现有 `tools/pack_chapter_enemies.py --authorized-offline-processing`：

- 从完整源图识别主体，保留独立动作和有意动作线，不用网格硬切越界尾巴。
- 重新排入 256×256 单元，四边至少 16 px 透明隔离，脚点上限 y=220；同角色组参考宽度统一。
- 预乘 alpha 等比缩放，清理轮廓外低透明噪声和透明像素隐藏颜色。
- 共替换 19 张基础／卸壳图、18 张技能图，780 帧；源图不覆盖，角色 ID、帧序和玩法接口不变。

[来源清单](../art/chapter_enemy_source_manifest.json)记录源图及运行图 SHA-256；[打包报告](../../assets/art/chapter_enemy_packing_report.json)记录每帧源边界、输出边界、缩放和同组参考宽度。源图 37 项校验与原清单完全一致。运行图为源图重新排版与缩放，不增加第三方素材或运行依赖。

## 实际验证

1. Python 检查：37 项源／输出哈希、目标尺寸和 780 帧边界记录匹配。生成 10 页全帧预览，逐页目视复核全部基础、技能、卸壳帧，尾巴、器具与动作线保留，未见跨格残片。
2. Godot 导入完成，退出码 0，无新增脚本解析或资源引用错误。首次沙箱运行出现本机系统证书读取及编辑器设置写入错误；随后在正常权限环境重跑无错误。
3. 四项既有回归均打印 PASS、退出码 0 且无 ERROR：
   - `test_art.gd`：44 个图标、透明边和 ID 映射。
   - `test_enemy_art.gd`：16 独立角色、19 基础图、18 技能图、780 帧、16 px 隔离带、尺寸／脚点、每行独立姿势及卸壳映射。
   - `test_mouse_frames.gd`：旧八鼠动画映射、优先级、暂停和死亡清理。
   - `test_enemy_presentation.gd`：新鼠技能帧、事件、暂停／2×、状态与死亡清理。
4. 非 headless 运行 `tests/chapter_enemy_gallery.gd` 完整通过。实际窗口渲染涵盖 1280×720、1600×900、四首领、技能预警／执行、铁釜卸壳、悬停、死亡取消、暂停与 2×。目视复核两尺寸全员对照、四首领及混合战场采样，未见边缘串图或背景方块。

原生截图证据：[1600×900 新旧鼠群对照](../art/previews/chapter_enemy_edges/roster_1600.png)、[1280×720 混合战场](../art/previews/chapter_enemy_edges/mixed_1280.png)。全部帧预览位于本机 `/tmp/chapter_edges_page_0.png` 至 `9.png`，日志为 `/tmp/chapter_edges_*.log`，不纳入游戏资源。

## 复验

```sh
python3 tools/pack_chapter_enemies.py --authorized-offline-processing
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_enemy_art.gd -- --qa-test
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/chapter_enemy_gallery.gd --quit-after 900 -- --qa-test
```

处理器依赖与版本见资产记录。始终以 `source/chapter_enemies/` 原稿为输入，避免对已整理图再次缩小。

## 验收边界

本轮覆盖贴图边界和相关表现回归。未运行完整测试目录、四十关平衡、压力帧率、真实鼠标试玩或导出发行包；不把原生测试夹具当作真人验收。全帧缩略图复核不等于所有动画的实时流畅度评审。铜钉、刻槽等原稿装饰差异沿用资产记录，未作为本次边界修复内容。TODO 的暂停／倍速与场景显示相关项已专项验证，其余玩法必验项未受本次纹理替换影响，未重验。
