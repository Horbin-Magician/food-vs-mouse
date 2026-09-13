# 美术生成提示词

2026-09-13，Codex 内置 image_gen，四次独立生成，无参考图。最终源图保存在 assets/art/，alpha 原样保留。以下为实际提交的完整提示词；生成结果的实际规格以 asset_pack.md 为准。

## food

Use case: stylized-concept. Asset type: production 2D game sprite atlas for an original cozy midnight kitchen tower defense. Create ONE transparent PNG atlas, 1536x1024 landscape, strict 4 columns by 2 rows of equal cells, no visible grid. Exactly eight separate full-body anthropomorphic food defenders, one centered in each cell with 15% transparent margin all sides. Row 1 left to right: plump xiaolongbao steamed bun with folded crown and small bamboo steam cannon aimed right; thick golden toast guardian with crust shield; glossy caramel pudding on little saucer; icy lemon tea glass with straw and lemon slice. Row 2: red chili skewer fighter; striped popcorn bucket bomber; ramen bowl with noodles and chopsticks; garlic bread guardian with herb butter and small garlic clove. Charming determined faces, tiny feet, all oriented three-quarter toward RIGHT. Hand-painted cartoon game art, clean dark brown outlines, rounded expressive silhouettes, soft cel shadows, warm cream and amber with teal accents. Each distinct silhouette readable at 64px. No text, letters, labels, numbers, watermarks, UI, extra characters, scenery or baked checkerboard. Genuinely transparent alpha background. Every object wholly inside its own equal cell, consistent scale, no overlap.

## enemy

Use case: stylized-concept. Production sprite atlas for cozy midnight kitchen tower defense. ONE 1536x1024 transparent PNG, strict 4 columns x 2 rows equal cells. Exactly eight full-body cute mischievous kitchen mice, one centered each cell, 15% empty transparent padding on every side, all facing LEFT three-quarter side view, feet on same relative baseline. Row1 left to right: plain gray mouse thief; slim fast mouse with orange neckerchief and sneakers; stocky mouse carrying round silver pot-lid shield; tough toothy mouse chewing a large bone. Row2: mouse with copper cooking-pot drum and wooden spoon drumsticks; dusty pale mouse carrying flour sack; elite pot-lid guard with brass reinforced lid and red scarf; large imposing plump mouse chef boss with tall white toque, apron and ladle. Original hand-painted cartoon art, clean dark brown outlines, rounded shapes, soft cel shadows, muted blue-gray fur, warm cream amber and teal accents. Strong readable silhouettes at 64px, no gore. No text, labels, numbers, grid, backdrop, watermark, UI, or checkerboard. True transparent alpha. No overlap or clipping, every mouse entirely within its own cell.

## recipe

Use case: stylized-concept. Create a production game UI recipe icon atlas, ONE 1536x1024 PNG, exactly 4 columns by 3 rows equal cells, 12 isolated icons on genuinely transparent background. Hand-painted cozy kitchen cartoon, dark brown clean outline, cream amber copper teal, soft cel shading, bold simple readable forms. Center each icon in its equal cell with 20 percent empty padding, nothing crossing cells. Row1: bamboo steamer releasing pressurized steam; black wok tossing vegetables in broad arc; copper heat-recycling kettle with circular arrows; bursting golden popcorn. Row2: blue ice cubes with snowflake; red chili crossing blue ice cube; red chili over small flame; long skewer with five red chilies. Row3: two caramel puddings; breakfast platter of toast pudding and egg; small warm bakery oven; toast with golden protective shield. No labels, text, letters, numbers, border, grid, backdrop, checkerboard or watermark. Original game artwork.

## background

Use case: stylized-concept. Asset type: 2D game environment background 1536x864, 16:9 landscape. Original cozy midnight Chinese diner kitchen after closing, hand-painted cartoon, clean dark brown outlines and soft painted shading, warm amber lanterns against midnight teal. Camera high oblique looking onto a large empty rectangular dark teal preparation counter covering central 70 percent, quiet low contrast surface to hold a tower defense board overlay. Decorative detail only at outer edges: left stacked rice sacks and wooden pantry crates, top hanging copper pans and bamboo steamers, right dark mouse hole near kitchen floor with scattered flour, small night window with moon at top, lower edge wood trim and folded cloth. Beautiful atmospheric polished indie game environment, no characters, no food warriors, no text, no writing, no logos, no HUD, no grid, no cards. Keep center uncluttered and dark so colorful game units stand out.


## 鼠群动作图集生成（2026-09-13）

使用内置 imagegen；参考 `assets/art/mice.png` 原创角色。输出 `assets/art/mouse_frames/{gray,runner,lid,gnawer,drummer,flour,elite,boss}.png`，各 1536×1024、6×4 格。初始生成结果为带棋盘底色的 RGB；用户授权本地处理后，经 `tools/clean_mouse_frames.py` 去底、恢复跨格部件及统一重排，当前最终资产为真实 RGBA。原始生成图保存在 `assets/art/source/mouse_frames/`，`.gdignore` 排除原图导入/导出；当前验收见 [鼠群逐帧验收](../testing/mouse_animation.md)。

完整共用提示词：

```text
Use case: stylized-concept. Asset type: production 2D game animation sprite sheet. Reference image is the project's original 8 mouse characters, use only the specified character and preserve its identity, clothing, colors and painterly cartoon style. Create ONE transparent PNG sprite sheet, EXACTLY 6 equal columns by 4 equal rows, 24 full-body poses, no text, no labels, no grid lines, no shadows, genuine alpha transparent background. Each cell same size, same character scale and fixed center, feet baseline at 86 percent cell height, ample padding including tail and props, no overlap between cells. Character faces LEFT throughout. Row 1 six distinct consecutive walk-cycle frames: left foot reaches forward, weight on left, right knee lifts passing, right foot reaches forward, weight on right, left knee lifts passing. Arms counter-swing, head and ears gently bob. Row 2 six consecutive attack frames: head leans toward left target, hands/weapon thrust, fully extended strike with open mouth, recoil head, hands pull back, neutral. Row 3 six consecutive hurt frames: startled head, eyes squeeze shut and head recoils right, hands protect chest, knees bend, head recovers, neutral. Row 4 six consecutive non-gory death frames: shocked loss of balance, hands release grip and knees buckle, tipping sideways, body falling, lying on side eyes closed, settled lying on side. Death body's low position must stay low in cell. Maintain recognizable hands feet and facial features in every pose. Only one mouse per cell. The 24 poses must have genuinely different articulated legs arms and heads, never copies merely rotated. Output landscape 1536x1024.
```

每次分别追加 Character：

- `gray`: top left gray hooded thief mouse carrying brown sack with cheese
- `runner`: top second athletic gray runner, orange scarf, teal sneakers
- `lid`: top third gray mouse with teal scarf leather vest and round silver pot lid shield
- `gnawer`: top fourth gray mouse with gold ear ring holding large bone in both hands
- `drummer`: bottom left gray mouse with teal scarf, copper drum and two wooden spoons; strike drum in attack
- `flour`: bottom second gray mouse carrying flour sack, beige apron and flour dust on fur
- `elite`: bottom third armored gray mouse, red scarf, ornate round gold pot lid shield
- `boss`: bottom right large gray mouse chef, white chef hat and coat, red neckerchief, soup ladle

另尝试 background-extraction：移除灰鼠棋盘背景、保持全部姿态位置并输出真实 alpha；结果仍非透明，未采用该变体。
