# F 版小笼包与灰鼠动作图集

日期：2026-09-25。状态：72 帧原始绘制稿已交付；后续已完成小笼包 36 帧与灰鼠四动作 24 帧运行时接入，最新结果见 [全角色替换](f_restyle.md)。以下保留原稿制作阶段记录。对应「使用体验」美术制作，沿用 [单位动画](animation.md) 的玩法与事件边界。

## 最终文件与实际检查

- [小笼包 36 帧](previews/f_animation_frames/bun_f_all_frames.png)
- [灰鼠 36 帧](previews/f_animation_frames/gray_f_all_frames.png)

两图实际均为 1254×1254 PNG，含 alpha 通道（macOS `sips` 检查），按 6×6 等分为 209×209 格；工具没有输出请求的 3072×3072。2026-09-25 在 Codex 目视逐行检查：最终两图各含 36 个主体，小笼包朝右、鼠主动作朝左；呼吸／眨眼、落地挤压、攻击、受击、倒地／软塌及调位／行走均有姿态变化，F 的旋涡特征保留。

小笼包首张攻击行第 4 格漏画主体，已用内置 image_gen 定向重绘并复查补齐，首张不作为交付文件。未使用本地代码修改图像。

限制：图像边缘仍有彩色／半透明残留；部分蒸汽、尾巴靠近格边，安全留白未全部满足。小笼包攻击回弹与灰鼠步态的连续性仍需切帧播放复核；当前仅为完整动作绘制稿，不能称为可直接加载的生产图集。未进行 alpha 像素边界自动验证、逐帧播放或 Godot 导入／交互测试；未改游戏资源引用、脚本、玩法或存档。正式接入前须清理边缘、统一锚点和复核循环。

## 设计与交付范围

以 [F 原图](previews/style_exploration/f_spiral_pop.png) 为身份和画风参考：深蓝轮廓、奶油桃金包子、灰蓝鼠身、珊瑚粉耳尾；包子偏心旋拧褶皱与鼠耳廓／尾巴旋涡呼应。包子朝右、灰鼠朝左；无服饰、持物和人形四肢。原有正式资源保持现状，F 为这两个角色的新选定方向。

每角色 6 列×6 行、每动作 6 帧，合计 72 帧。每行从左向右播放：

| 行 | 小笼包 | 灰鼠 | 播放 |
|---|---|---|---|
| 1 | 呼吸、眨眼待机 | 嗅闻、眨眼待机 | 循环 |
| 2 | 放置落地回弹 | 生成落地回弹 | 单次 |
| 3 | 顶部旋口蒸汽攻击 | 四足行走 | 包子单次，鼠循环 |
| 4 | 受击恢复 | 探头啃咬攻击 | 单次 |
| 5 | 泄气软塌退场 | 受击恢复 | 单次 |
| 6 | 准备阶段调位弹跳 | 侧倒退场 | 单次 |

调位帧不代表美食获得自行行走能力；实际位移仍由棋盘调位表现控制。蒸汽仅从顶部发出，不添加武器。死亡不增加掉落或延迟结算；鼠保持四足动物体态，倒地无血腥。

现有鼠图集是 6×4，本次扩展图集不直接兼容现有加载器。小笼包新增逐帧受击／退场仅作为绘制资产，未声称相关运行时事件已接入。正式接入时须明确帧映射、事件时点和时长，不凭图集增加蓄力延迟或改变伤害。暂停、倍速及死亡快照要求仍按动画权威规范执行。

## 验收与限制

检查两图各 36 个姿态、固定朝向、造型一致、动作顺序、完整耳尾／蒸汽和跨格情况；检查实际文件尺寸与 alpha。请求 3072×3072 与真实透明不等于工具保证，须记录实际结果。未经切帧、固定锚点及循环播放检查的生成源图不得称为运行时成品。本轮不修改游戏代码，因此不以 Godot 测试替代图片视觉检查。

## 来源与完整提示词

### 小笼包攻击行修订提示词

```text
Edit this xiaolongbao animation sprite sheet. Preserve F character identity, line style, palette and the six-by-six layout. Critical repair: row THREE must contain SIX COMPLETE BUN CHARACTERS, one per cell, not isolated steam in place of a bun. Replace the entire third row with six progressive steam attack poses: 1 slight compression, 2 top spiral crown tilts open to right, 3 a SHORT small curl of steam emerges from crown to right, 4 COMPLETE BUN recoils with the steam dissipating just above its crown, 5 complete bun recovers, 6 complete bun neutral. No steam comes from face. Each cell contains the complete dough body with two eyes and spiral crown. Keep all steam WITHIN its own cell. Preserve the existing other five animation rows and all their poses. Also clean isolated background noise and colored halo residue across the whole sheet to true alpha transparency, preserving clean antialiased edges and intentionally drawn steam. No shadows, no background, no new props or text. Exactly 36 whole buns in a 6 column by 6 row regular square grid, safe gaps between cells.
```

使用 Codex 内置 image_gen，以本项目 F 候选图为唯一参考；不新增外部资产或运行依赖，底层模型版本未返回，不推测。保留原始生成图，不对专有权作保证。

### bun_f_all_frames

```text
Use case: stylized-concept, production animation sprite sheet. Use the attached image ONLY as character identity and F art style reference. Draw a complete meticulously organized animation sprite sheet of ONE character. EXACTLY 6 COLUMNS and 6 ROWS = 36 separate frames, equal square cells in a perfectly regular square canvas. Request 3072x3072 pixels. Every row is one temporal sequence read left to right. No header, no text, no letters, no numbering, no gridlines, no UI. Real transparent background, no checkerboard drawing, no colored backdrop, no ground shadows. Each frame must be fully inside its cell with 15% safe padding, no tails or steam crossing cell boundaries. Orthographic three-quarter game sprite perspective fixed for all frames. Same identity, colors, line weight and base scale across all 36 frames. Feet or dough base at consistent local y=80% except airborne and fallen frames, body anchor horizontally consistent so movement loops stay in place. Actual articulated changes and squash/stretch in adjacent frames, not 36 duplicate poses. Preserve F's contemporary crisp dark navy outlines, beautiful cream peach highlights, simple cel-painted volume, appealing exaggerated shape design. No extra characters, scenery, props or existing IP. Cute gentle defeat, no gore.
CHARACTER: only the XIAOLONGBAO on the LEFT of reference, no mouse anywhere. Keep its low asymmetric cream pear-shaped dough body, five deeply sculpted golden-peach pleats gathered into a large off-center clockwise spiral crown, tiny dark oval eyes toward the right, tiny peach cheek spots. No arms, no legs, no clothes, no mouth needed. Always facing RIGHT. Steam shaped in small elegant spiral ribbons is allowed only inside the sprite cell.
ROW 1 IDLE LOOP: (1) neutral, (2) inhale slightly taller, (3) soft peak inhale, (4) exhale slightly rounder, (5) blink with soft compressed dough, (6) eyes reopen toward neutral. Steam curl changes gently.
ROW 2 PLACEMENT LANDING, NONLOOP: (1) suspended a little above floor, vertically elongated, (2) descending, (3) first contact, (4) broad squashed dough and bent spiral crown, (5) soft rebound, (6) settled neutral. No dust.
ROW 3 STEAM ATTACK, NONLOOP: (1) body compresses slightly, crown opens to right, (2) a tight steam puff begins emitting from SPIRAL CROWN, (3) peak emission of a small compact spiral steam bolt to RIGHT with dough recoil to left, (4) steam separates within cell and crown closes, (5) recoil relaxes, (6) neutral. Steam comes from top opening, never eyes or mouth. No metal gun. This is in-place attack, not a jump.
ROW 4 HURT RECOVERY, NONLOOP: (1) recoil left, (2) eyes tightly closed and dough dents on right, (3) peak squish away from impact, (4) wobble returning, (5) eyes open, (6) neutral. No injury marks.
ROW 5 DEFEAT, NONLOOP: (1) eyes close and body droops, (2) crown slumps sideways, (3) body deflates lower, (4) folds collapse softly, (5) a flattened cute dough mound with spiral still visible, (6) same settled flattened mound eyes closed. Keep body intact, no disappearance, no broken food pieces, no resurrection.
ROW 6 PREPARATION REPOSITION HOP, NONLOOP: (1) crouch/squash, (2) stretch takeoff, (3) small airborne arch leaning right, (4) descending, (5) landing squash, (6) settle. Position movement will be handled by engine; keep all frames same horizontal anchor. No legs.
Exactly 36 bun drawings, not a concept board. All six frames of each row have visibly progressive distinct poses.
```

### gray_f_all_frames

```text
Use case: stylized-concept, production animation sprite sheet. Use the attached image ONLY as character identity and F art style reference. Draw a complete meticulously organized animation sprite sheet of ONE character. EXACTLY 6 COLUMNS and 6 ROWS = 36 separate frames, equal square cells in a perfectly regular square canvas. Request 3072x3072 pixels. Every row is one temporal sequence read left to right. No header, no text, no letters, no numbering, no gridlines, no UI. Real transparent background, no checkerboard drawing, no colored backdrop, no ground shadows. Each frame must be fully inside its cell with 15% safe padding, no tails or steam crossing cell boundaries. Orthographic three-quarter game sprite perspective fixed for all frames. Same identity, colors, line weight and base scale across all 36 frames. Feet or dough base at consistent local y=80% except airborne and fallen frames, body anchor horizontally consistent so movement loops stay in place. Actual articulated changes and squash/stretch in adjacent frames, not 36 duplicate poses. Preserve F's contemporary crisp dark navy outlines, beautiful cream peach highlights, simple cel-painted volume, appealing exaggerated shape design. No extra characters, scenery, props or existing IP. Cute gentle defeat, no gore.
CHARACTER: only the GRAY MOUSE on the RIGHT of reference, no bun anywhere. Preserve smoky periwinkle-gray comma-shaped body, creamy muzzle and underside, oversized coral pink ears with simple spiral cartilage, three small forehead tufts, dark bright oval eyes with whites, pink paws, pink nose, long pink tail in open spiral. Mouse stays a FOUR-LEGGED animal, no humanoid standing, no clothes, no equipment. Always facing LEFT, never mirror or turn toward right. Tail extends behind to right fully inside each cell, curl changes naturally with motion. Same two ears, four anatomically consistent paws and one tail throughout.
ROW 1 IDLE LOOP: (1) neutral low crouch, (2) nose sniffs slightly up, (3) ears gently perk asymmetrically, (4) nose lowers, (5) blink, (6) back to neutral. Keep paws grounded.
ROW 2 SPAWN LANDING, NONLOOP: (1) slightly airborne above baseline all four paws tucked, (2) descending front paws reaching down, (3) front contact, (4) all four paws land body squashes, (5) ears/tail bounce settling, (6) neutral crouch.
ROW 3 WALK LOOP IN PLACE: (1) near forepaw forward and far hindpaw forward contact, (2) weight down, (3) paws pass beneath body, (4) opposite forepaw and hindpaw forward contact, (5) opposite weight down, (6) passing back toward frame 1. Clear alternating front and hind legs, natural quadruped walk with gentle head bob. Body horizontal and pointing left. Not sliding or hopping. Do not translate character across cells.
ROW 4 NIBBLE ATTACK, NONLOOP: (1) low body braces, head reaches left, (2) muzzle opens a little, (3) tiny incisors visible in brief cute bite toward left, (4) mouth closes, (5) head retracts, (6) neutral low crouch. No food target painted in, no hands punching.
ROW 5 HURT RECOVERY, NONLOOP: (1) head recoils right while remaining facing left, (2) eyes shut ears fold back, (3) body crouches low, (4) ears reopen, (5) eyes open body recovers, (6) neutral. No blood or bruises.
ROW 6 DEFEAT, NONLOOP: (1) head droops ears lower, (2) front legs buckle, (3) body begins gentle side roll, (4) lies on side facing left, (5) tail relaxes and paws tuck, (6) motionless resting on side eyes closed. No stars or symbols, no vanishing, no resurrection.
Exactly 36 mouse drawings, not a concept board. Articulated leg, head, ear and tail changes between frames, not rigid transforms of one drawing.
```
