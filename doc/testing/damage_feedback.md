# 受击反馈验收

日期：2026-09-25。状态：实现、导入、逻辑回归和原生画面检查通过；真人鼠标试玩、密集战斗可读性及压力性能待验，未重导发行包。设计权威见 [受击反馈](../art/damage_feedback.md)。本次在已有菜单、商店、布局工作区上增量实现，没有回退已有改动。

环境：macOS / Apple M4，Godot 4.6.3 stable，Compatibility / OpenGL 4.1 Metal。无新增插件、外部资产或依赖；shader 与飘字均为项目内原创代码。

| 检查 | 实际结果 |
|---|---|
| Godot headless editor import | 新脚本、shader、主场景解析通过，无新增错误 |
| 原有全部 17 组 test_*.gd | run_tests.py 全部 PASS，覆盖战斗、内容、动画、商店、存档、页面、投影和 UI |
| test_damage_feedback.gd | PASS：锅盖减伤、灼烧不消耗护甲、吐司减伤、实际致死扣血、重复死体不触发、非正伤害不触发、数值格式、连续闪光刷新、容量、计时、阶段及重开解绑 |
| damage_gallery.gd 原生非 headless | PASS：8 美食和 8 鼠群由统一伤害入口触发；暂停飘字不变、2× 实际主场景处理推进 0.1 游戏秒、到期清空 |
| 1280×720 / 1600×900 原生截图 | 已逐图查看：暖白 shader 随轮廓绘制、无透明方框、角色动画帧与闪光对齐；红／黄／橙描边数字可见，连续伤害错开，精英／首领偏右避开名称 |
| 致死和半程淡出 | 已查看：吐司死亡仍短暂显示最后轮廓和实际剩余 880 伤害；灼烧标记为 ·6；0.09 游戏秒后闪光衰减且原贴图恢复；到期后数字和 shader 节点清除 |
| git diff --check | 通过 |

原生画廊为程序驱动的真实渲染，非真人鼠标输入验收；本次没有新增输入控件。暂停与倍速经主场景程序调用验证。此专项不代表使用体验里程碑或完整八关平衡通过。高密度目标的数字仍可能交叠，160 条上限仅限制视觉内存，不改变任何伤害结算。

复现命令（项目根目录）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_damage_feedback.gd -- --qa-test
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/damage_gallery.gd -- --qa-test
```

画廊使用独立 QA 存档目录。临时截图 `/tmp/food_damage_{before,hit,lethal,fade,large,clear}.png` 不入库。
