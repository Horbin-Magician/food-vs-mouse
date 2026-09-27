# 项目图标

日期：2026-09-27。状态：已绘制并接入，原图及 64 px 预览目视通过，Godot 资源导入和启动完成；系统 Dock 与发行包待验。对应「使用体验」里程碑，仅涉及项目标识，不更改玩法。

## 设计与接口

遵循 [F 角色规范](f_restyle.md)：深蓝轮廓、奶油桃金高光、灰蓝鼠身、珊瑚粉耳尾。以左侧朝右的小笼包与右侧朝左的灰鼠表现对峙；小笼包保留偏心旋口及蒸汽，无四肢或武器，鼠保持四足。青绿深夜背景和暖金边缘呼应食堂。主体占据画面大部分，避免文字、细碎场景和多角色堆叠。

产物为方形 PNG，保存于 `assets/art/project_icon.png`，通过 `project.godot` 的 `application/config/icon` 接入。原 `icon.svg` 留作历史资产。macOS 导出预设显式引用同一 PNG；本次不重建发行包。

验收：检查主体、画风、边界和小尺寸辨识；确认 PNG 可解码、项目引用有效、Godot 导入及主场景启动无错误。图标无需新增交互测试；不代替完整使用体验或发布验收。

## 来源与完整生成提示词

使用内置 image_gen 生成原创图像，无外部下载素材或新增运行依赖。工具未提供模型版本，不推测。授权边界沿用内置生成服务适用条款，不另称第三方开源许可。

```text
Use case: stylized-concept
Asset type: square desktop game application icon, 1024x1024 PNG.
Create a polished original icon for a cute 2D lane-defense game set in a late-night Chinese diner: sentient food defends the pantry from mice. A large cream-gold soup dumpling on the left faces a blue-gray mouse on the right in a playful determined face-off. Dumpling has a distinctive off-center spiral pleated closure, tiny dark oval eyes, peach cheeks, no limbs, no clothes, no weapon. One bold curling steam plume rises from its closure. Mouse crouches naturally on four paws, oversized coral-pink curled ears, cream muzzle, lively dark eyes, curled pink tail, no clothes. Make the two characters equally readable and their faces separated. Modern premium chibi game illustration, confident dark navy outlines, clean broad cel shaded shapes, soft appetizing highlights, restrained detail, expressive silhouettes. Deep midnight teal rounded-square background with a tasteful warm brass rim, subtle warm glow behind the characters. Transparent outside the rounded square. Extremely tight icon composition with safe outer margin, characters large, legible at 64 pixels. No text, letters, logo, watermark, extra characters, kitchen clutter, weapons, photorealism or mockup. Deliver just the finished square icon.
```

## 验证记录

- 环境：macOS，Godot 4.6.3 stable，当前工作区；保留用户原有 `project.godot` 输入事件改动。
- 实际工具输出为 1254×1254 RGBA PNG（提示词请求 1024，未强行修改原图），透明圆角。原图与 `sips` 临时缩至 64×64 的预览已目视检查：包子、鼠脸、耳朵与蒸汽可辨，脸部互不遮挡。缩略图仅用于检查，不入库；保留生成原图 alpha。
- `project.godot` 与 macOS 导出预设均指向正式 PNG；Godot 已生成并保留 `.png.import` 配置及 UID，压缩模式为无损。
- `Godot --headless --path . --editor --import` 完成图标导入，退出码 0，无脚本解析或缺失资源错误。沙箱不允许保存用户目录的编辑器设置，日志有对应错误；macOS 系统证书查询也有环境错误，未将整段日志宣称为零错误。
- 首次主场景冒烟因默认用户日志目录写入受限，在日志轮转处崩溃；改用 `--log-file /tmp/food-vs-mouse-icon-runtime.log --quit-after 120` 后退出码 0，主场景启动完成；输出含系统证书环境错误，以及退出时 ObjectDB 实例和 1 个资源仍在使用的清理提示，未将冒烟记录为零警告。
- `git diff --check` 通过。视觉检查为图像本身及小尺寸预览，未验证系统 Dock 缓存刷新、项目管理器列表或导出的 `.app` 外观；本次没有重导发行包。
- 未更改玩法或输入，无需重复 `TODO.md` 中经济、存档、战斗及性能必验项；不据此标记整体里程碑完成。
