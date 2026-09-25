# 美食弹体验证

日期：2026-09-25。状态：实现、导入、相关战斗回归与原生渲染检查通过；真人鼠标试玩未执行，未重导发行包。工作区存在用户的菜单、商店与布局改动，本次仅叠加弹体表现。对应 [设计](../art/projectiles.md)。

环境：macOS、Apple M4、Godot 4.6.3 stable、Compatibility / OpenGL 4.1 Metal。

| 检查 | 实际结果 |
|---|---|
| Godot headless editor import | 六张 SVG、表现脚本和主场景导入通过，无新增解析或资源错误 |
| test_core.gd | PASS core 72，涵盖弹体击杀及暂停等基础行为 |
| test_content.gd | 八关、生成、首领、召唤、面粉和鼓手回归通过 |
| projectile_gallery.gd 原生非 headless 运行 | 五种远程单位由 CombatController 实际生成六颗弹体（含第二个包子）；暂停位置不变、2× 位移和清理断言通过 |
| 默认及放大窗口渲染 | 查看 1280×720 与 1600×900 原生截图：六款轮廓朝右，透明背景无底板，小尺寸可区分，未越相邻行 |
| 出手位置 | 查看真实生成后的截图，沿用原有单位中心与离地高度；弹体飞出时从食物前方逐渐显露 |

画廊另将弹体排列到固定位置以比较；高压包子的 radius 由夹具设置，仅验证外观分支，不代表本次重新验证每第四击食谱触发。尾迹静态，无新增动画时钟。没有新增交互控件，暂停／倍速为程序调用断言，并非真人点击验收。未执行完整八关试玩或压力性能评估，不据此标记使用体验里程碑完成。

复现：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/projectile_gallery.gd
```

生成截图在 /tmp/food_projectiles_{board,roster,large}.png；画廊使用独立 qa 存档目录。保留 [默认尺寸预览](../art/previews/projectiles.png)。
