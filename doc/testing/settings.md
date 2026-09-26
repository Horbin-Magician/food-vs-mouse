# 统一设置与倍速布局验证

日期：2026-09-26。状态：已实现，自动回归、原生输入事件和双尺寸画面通过；真实鼠标复验受限。设计依据：[设置窗口](../design/settings.md)、[UI 规范](../art/ui.md)。属于首版「使用体验」，不表示完整试玩里程碑通过。

## 环境与范围

- macOS / Apple M4，Godot `4.6.3.stable.official.7d41c59c4`，Compatibility / OpenGL 4.1 Metal。
- 1280×720 与 1600×900 等比缩放，测试使用 `user://qa_settings_*` 隔离存档及音量配置；截图与日志放 `/tmp`，不纳入版本控制。
- 热量下方倍速、右上设置、菜单／卡册／小铺／战斗／战报入口、暂停与声音、离开确认和存档失败保留。

## 实际检查

| 项目 | 结果 |
|---|---|
| Godot 导入 | 标准本机导入无新增解析、缺失资源或导入错误；齿轮 SVG 与测试 UID 有效 |
| 全仓回归 | `python3 tools/run_tests.py` 共 36／36 通过，退出码 0；包含现有战斗、掉落、商店、成长、存档、音频及新增设置专项 |
| 输入专项 | `test_settings.gd` 在 headless 与原生渲染窗口均通过；输入走 `Input.parse_input_event` / `Viewport.push_input`，覆盖 Esc 开关、长按、设置外点击后 Esc、右键、锅铲清理、显式设置按钮与底层倍速隔离 |
| 暂停与导航 | 战斗时间与动画冻结；关闭恢复原暂停、主按钮明确继续；2× 保留；嵌套确认 Esc 仅取消确认；小铺内容、资源及随机状态保留 |
| 存档与失败 | 战斗返回菜单保留本关准备快照与已收灵感；继续恢复准备，未保存战斗现场；准备保存／战报结算失败均停留窗口显示错误，修复存储后可重试，未重复结算 |
| 声音 | 既有 audio / audio_flow / hub_audio 回归通过，三路音量、静音保存及暂停降音行为保持 |
| 原生画面 | `settings_gallery.gd` 生成关前设置及两种尺寸战斗／设置／确认共 7 图并目视检查：热量四位数、倍速、8 张卡、设置与锅铲互不重叠；设置滑杆、文字和主按钮完整，遮罩清楚 |
| 真实退出 | `settings_gallery.gd -- --qa --quit-check` 从战斗设置确认退出，进程退出码 0，最终无 ERROR／WARNING；用例设三秒超时防止假通过 |
| 既有交互 | UI、拖放、锅铲、购物测试更新至新入口后通过；未保留隐藏旧暂停按钮来规避新交互检查 |

命令：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/food_settings_final_import.log --editor --import
python3 tools/run_tests.py
/Applications/Godot.app/Contents/MacOS/Godot --path . --log-file /tmp/food_settings_native_test.log --script tests/test_settings.gd -- --qa-test
/Applications/Godot.app/Contents/MacOS/Godot --path . --log-file /tmp/food_settings_gallery.log --script tests/settings_gallery.gd -- --qa
```

## 修复的边界与限制

- Godot 嵌入独占窗口在点击外部后可能清空内部窗口焦点，导致 Esc 无接收者。设置及确认失焦时延迟恢复最内层嵌入窗口焦点，不激活系统前台；原失败用例保留且已通过。
- 独立战斗场景初始化失败时隐藏设置入口并检查空运行状态，防止错误页面点击设置后解引用空状态。
- 首次沙箱导入遇到系统证书读取和 Godot 编辑器设置写入限制，随后标准本机运行完成；不将沙箱日志描述为产品解析错误。
- 原生鼠标工具仅绑定到已打开的 Godot 编辑器，未能定位独立验收游戏窗口；因此没有把程序注入的原生输入事件记为物理鼠标／键盘验收。
- 早期复用旧音频截图夹具时，立即退出曾报告音频异步释放资源仍在使用；新设置夹具正常截图结束使用既有 AudioCleanup 等待释放。第二次多窗口截图曾在调整窗口尺寸后的渲染等待停住，已结束该隔离测试进程；最终结果与退出检查见下方补记。
- 未更新发行导出包，未进行完整八关试玩或性能测试。

## 最终补记

- 七张原生截图最终重跑退出码 0，日志无 ERROR／WARNING；夹具改为两帧布局后主动绘制，避免窗口被遮挡时无限等待 `frame_post_draw`。最终确认框按钮和失焦边框沿用深绿主题。
- 独立真实退出用例最初复现一条音频资源仍在使用的错误。入口现冻结操作、防止重复退出，调用 SoundService.shutdown 解绑、清空流引用，并给混音线程最多一秒释放时间；复跑已正常退出且无资源泄漏日志。主菜单、战报与设置退出共用该清理；独立战斗入口同样接入。
- 最后一次音频清理变更后再次执行全仓回归，仍为 36／36 通过。

退出专项命令：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --log-file /tmp/food_settings_quit_clean.log --script tests/settings_gallery.gd -- --qa --quit-check
```
