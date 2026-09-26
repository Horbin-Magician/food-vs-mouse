# 状态与技能表现验收

日期：2026-09-26。状态：实现、导入、28 组逻辑回归、双尺寸原生渲染和真实窗口鼠标专项通过。完整八关试玩、多人可读性评价和发行包更新未执行。权威设计见 [状态特征与技能表现](../art/status_effects.md)。保留用户已有的 `export_presets.cfg` 改动。

环境：macOS、Apple M4、Godot 4.6.3 stable、Compatibility / OpenGL 4.1 Metal；逻辑画布 1280×720，原生窗口覆盖 1280×720 与 1600×900。全部特效为项目内原创 GDScript／SVG 矢量绘制，无外部素材或新增依赖。

验证期间共享工作区另有音频模块编辑，主场景曾暂缺 AudioSettings 依赖；本次未修改或回退该工作。最终特效回归在仓库 HEAD 加本次特效改动的临时隔离副本执行（包括主场景的特效接入，排除音频未完成改动），28 组再次通过。收尾时共享工作区 Godot 导入也再次通过；此结果不代表同时进行的音频工作已验收。

共享工作区收尾补跑：`test_status_feedback.gd` 通过；`test_ui.gd` 的交互断言 PASS，但退出仍报告音频资源占用，verbose 指向 `assets/audio/music/battle.ogg`、`won.ogg` 的 OggPacketSequence 及 AudioStream 播放实例。未将这次共享 UI 运行计为无错误通过，未改动并行音频模块；特效隔离副本的 UI 回归及原生画廊无该资源错误。

| 检查 | 实际结果 |
|---|---|
| Godot editor import | 脚本、场景与全局类加载通过，无新增解析／引用错误，保留新增脚本 UID |
| `python3 tools/run_tests.py` | 28 组全部 PASS，含原有战斗、首领数值、波次、存档、菜单、拖放、铲除及动画回归 |
| `test_status_feedback.gd` | 验证正交攻速／伤害加成、重复来源、来源移除、生产者／防御者不显示无效攻速、高压第四发前就绪；鼓舞半径 144 与 144.01、异行／自身排除；真实冰火命中、状态到期、直接／持续伤害护甲次数、面粉死亡只发一次 |
| 技能与生命周期 | 实际首领十秒召唤、两条不同随机行、半血首次狂暴与重装援军、重复受击不重复狂暴；致死范围命中仍留特效，坐标快照不随已移除实体变化；零时间冻结、到期清空、80 项上限、随机状态不变、阶段与重开解绑；关间真实回血效果单独保留 |
| 原生 `status_gallery.gd` | 已查看状态、召唤初始／中段、狂暴、范围／生产／面粉效果和清理画面。血条下徽记区分叠加效果；三类来源环、护盾、冰棱、粉尘和狂暴锯齿环可见；召唤连线终点对应实际入场路线 |
| 暂停与 2× | 原生画廊断言暂停多帧 age 不变；通过主场景 `_process(0.05)` 验证 2× 实际推进 0.1 游戏秒 |
| 窗口鼠标 | 使用原生输入在 1600×900 暂停窗口指向小笼包，读取“蒜香攻速 · 早餐伤害 · 高压就绪”；指向灰鼠读取“减速 2.4s · 灼烧 2.9s”；点击继续、观察真实战斗推进和状态到期、再次暂停通过。原有铲除／放置未在本次重新真人操作，由既有自动回归覆盖 |
| 淡出边界修复 | 持续播放曾出现星芒缩为亚像素导致多边形三角化错误；已对极小／透明星芒停止绘制。增加全部 11 种事件完整 70 帧原生渲染，覆盖高屏幕坐标和渐隐尾段，最终运行无渲染错误 |
| 密集表现 | 46 敌人的原生画面验证紧凑分色环和完整徽记；减少到 44 后恢复完整装饰。固定徽记图集与状态组合纹理缓存通过原生绘制；缓存复用及重开释放通过逻辑断言 |
| `git diff --check` | 通过 |

## 压力验证

`tests/status_stress.tscn` 保持 40 美食、100 敌人及实际攻击，敌方伤害设为零避免原压力脚本在同一步集中攻击后掉到 35 美食；100 敌人带减速、灼烧，部分为鼓手、其余为锅盖，美食带面粉状态，启用对应食谱。使用 3 秒预热、约 20 秒采样，渲染和分辨率同上。测试画廊和压力场景使用 QA 状态，不修改玩家存档；压力场景不是正常通关策略。

| 版本／条件 | 平均 FPS | P95 / P99 帧耗时 |
|---|---:|---:|
| 初始每单位完整矢量装饰（已替换） | 16.39 | 79.17 / 82.55 ms |
| 同负载关闭状态绘制的诊断对照 | 86.75 | 13.56 / 17.25 ms |
| 最终徽记图集＋密集分色环缓存（40 / 100，1330 帧，20.03 秒） | **66.39** | **16.84 / 18.82 ms** |

最终压力运行无脚本／渲染错误，平均超过 60 FPS；P99 仍高于 16.67 ms，不能宣称稳定每帧 60 FPS。不同图形 API、硬件和更高分辨率未做性能保证；场景中重叠敌人的徽记仍可能交叠，可通过悬停读取单体状态。该短时表现压力检查不替代完整真人平衡和长期性能验收。

## 复现

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
python3 tools/run_tests.py
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/status_gallery.gd -- --qa-test
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/status_gallery.gd -- --qa-test --status-live
/Applications/Godot.app/Contents/MacOS/Godot --path . tests/status_stress.tscn -- --qa-test
```

`--status-live` 在画廊完成后保留可操作窗口。压力场景可附加 `--without-status-drawing` 运行诊断对照。临时截图 `/tmp/food_status_{statuses,summon_start,summon_mid,rage,large,skills,clear,dense,restored}.png`、日志和压力结果不纳入版本控制。
