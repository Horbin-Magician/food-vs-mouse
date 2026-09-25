# F 全角色替换验收

日期：2026-09-25。状态：正式替换、自动回归与原生渲染检查完成；真实鼠标交互与窗口缩放复验受工具限制，未记为通过。环境：macOS、Apple M4、Godot 4.6.3 stable、Compatibility、1280×720。设计依据 [F 全角色规范](../art/f_restyle.md)、[动画接口](../art/animation.md)。

## 资源与处理

用户明确确认后执行 `tools/pack_f_art.py`，保留原图于 `assets/art/source/f_restyle/`，由上级 `.gdignore` 排除导入。Pillow 12.3.0（HPND）、NumPy 2.5.3（BSD-3-Clause）通过 PyPI 安装于临时虚拟环境，仅供离线资产处理。

八美食／八鼠静态图集为 1536×1024；八鼠四动作共 192 帧，每张 6×4；小笼包六动作 36 帧，6×6。动画单元为 256×256，脚底 y=220；静态头像图集为 4×2 格。主体与透明留白检测通过，处理参数及边界详见 [打包报告](f_restyle_packing.json)。浅深背景目视检查全部 16 角色，耳尾、帽子与高光完整，未见明显透明杂边。

## 实际执行

- Godot `--headless --editor --import --quit` 完成，无新增解析错误或缺失资源。
- `python3 tools/run_tests.py`：15 组全部 PASS（animation、art、builds、content、core、drag、edges、food_frames、heat、heat_ui、mouse_frames、progression、projection、save、ui）。新增 food_frames 覆盖小笼包全部帧、事件、暂停、死亡快照、重复致死保护与清理。
- 原生 `tests/mouse_animation_gallery.tscn -- --qa-test --capture-mice`：六幅截图全部目视检查，覆盖 192 帧，无跨格裁切；`tests/bun_animation_gallery.tscn -- --qa-test --capture-bun`：总览检查全部 36 帧及播放列。
- 原生 `tests/mouse_combat_gallery.tscn -- --qa-test --capture-mouse-combat` 返回 PASS，实际战斗行走、攻击、受击与死亡已渲染；检查攻击截图确认新资产显示。
- 原生 `tests/animation_gallery.tscn -- --qa-test --capture-animation` 完成；`tests/art_gallery.tscn -- --qa-test --capture-art` 同时输出商店及完整棋盘截图，目视检查全 16 角色、顶部卡牌与状态显示，归档 [游戏内预览](../art/previews/f_restyle_game.png)。后者退出有 ObjectDB 泄漏警告，未作为无警告检查通过；未观察到渲染缺失。

## 未通过或未执行范围

已尝试通过原生 UI 启动和定位 Godot 调试窗口，但工具返回运行窗口截图不可用，无法可靠完成实际鼠标放置／调位／取消及窗口缩放复验。上述帧捕获是原生 viewport 输出，并非人工交互通过的替代证据。

未重导发行包，未重新执行完整八关试玩、新玩家辨识反馈与性能压力测试；不宣称整个「使用体验」或平衡里程碑通过。
