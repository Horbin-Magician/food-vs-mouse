# 后四关首领概念图：提示词归档

日期：2026-09-26。状态：概念参考已生成并目视检查；正式角色图集、技能帧与接入尚未制作。使用本地内置 imagegen 工具，工具未声明模型版本；未使用 CLI/API 回退，没有新增运行依赖。

## 输入、迭代与产物

- 风格权威：[现有 F 角色参考板](previews/f_restyle_roster.png)及[F 规范](f_restyle.md)。参考板是项目已有原创生成美术。
- 首稿仅用于确定漏勺／铁锅／醒面碗／算盘的四种轮廓，因皮毛与材质偏写实未选为本项目交付图。
- 用户强调保持画风一致后，第二次以内置工具编辑首稿，同时把现有参考板作为明确风格参考。第二稿为最终选用的[概念图](previews/chapter_boss_concepts.png)，1536×1024；已从生成目录复制进仓库，文件原样保留，未做裁切、重采样或去底。
- 目视结果：四足、耳尾、朝向和四种道具轮廓符合方案，第二稿更接近既有 F 角色；残留细纹理和算盘珠数量限制详见[美术规格](chapter_enemy_redesign.md#7-概念图与原创来源)。它不是最终透明精灵，也不证明同画风生产验收通过。
- 后续制作须按 F 参考板进一步精简纹理、拆分三枚订单指示、校准脚底及完整四动作；不得把概念板直接作为已完成图集。

## 首稿完整提示词

```text
Use case: stylized-concept
Asset type: one four-character concept art comparison sheet for an original cozy night-kitchen 2D tower-defense game; design reference only, not a gameplay screenshot or sprite atlas.
Primary request: four visibly distinct quadrupedal mouse bosses, one in each cell of a clean 2x2 character sheet. Large polished full-body three-quarter side profiles facing LEFT, each with a small secondary head or prop study. All four remain anatomically cute low-bodied mice with four paws on the ground, large spiral-shaped coral pink ears and curved tails, slate blue gray fur, expressive black eyes. No standing humanoids, clothes, weapons held in hands, chef hats, existing franchise characters.
Style: modern premium chibi game character art, bold dark navy outlines, clear chunky cel shadows, cream peach gold highlights, carefully painted kitchen-object materials, charming but formidable. Silhouettes must remain legible at small game scale. Warm off-white paper background, subtle tidy panels, no dramatic environment.
Top left boss "02": FENG SHAO, a lean fast courier mouse, long low aerodynamic silhouette, swept-back ears, an upturned turquoise metal perforated colander strapped low on the back like a streamlined fairing, two shallow brass measuring spoons tucked flat along the sides as runners, tail curling through a tiny hollow whistle. A few light curved speed marks. No vehicle, no wheels. Emphasis teal and brass.
Top right boss "03": TIE FU, a broad extremely stocky blackiron pot fortress mouse, a squat massive inverted cast-iron cooking pot armor with three visible copper rivets and warm amber seams, ears emerging in front, belly and stout paws visible, dark rounded rectangular silhouette, one very small pressure cap atop the shell. Pot visibly too heavy to lift casually. Extra prop study shows rivets loosened and pot tilted exposing its vulnerable flank. Emphasis charcoal and furnace copper.
Bottom left boss "04": BAI JIAO, an elderly round sourdough keeper mouse, pale blue gray fur dusted with flour, whiskers tipped white, a cracked lavender ceramic mixing bowl on its back, huge asymmetrical creamy fermented dough rising in three bulbous folds over the bowl, wooden stirring paddle strapped flat against the bowl, a few floating translucent dough bubbles. Actual mouse face, ears and all four paws fully visible beneath the bowl, no baker costume. Extra study of small knotted dough lump. Emphasis warm cream and muted lilac.
Bottom right boss "05": TIE SUAN PAN, a calculating grain-route quartermaster mouse, dignified lean angular charcoal gray body with a silver brow tuft, a broad miniature wooden abacus strapped horizontally across the back like cargo, THREE prominent brass counting beads and two sealed grain sachets, curled tail touching the last bead, grain measure scoop strapped alongside; body distinct from fast mouse and pot mouse, no crown or human clothing. Extra prop study shows three beads in ordered states and a split grain sachet. Emphasis aged walnut, deep jade and dawn gold.
Composition: exactly four hero subjects, generous white space, coherent scale, each isolated in its panel, small unobtrusive numerals "02", "03", "04", "05" only. No other text, no labels, no watermark. Keep all tails, ears, cookware and feet uncut. This is a visual concept for four different encounter identities: sprint timing, breakable armor, fermenting dough, finite supply orders.
```

## 第二稿完整提示词（最终选用）

输入顺序：Image 1 为项目 F 参考板；Image 2 为首次生成的四首领概念板。

```text
Use case: style-transfer
Asset type: revised single four-boss concept comparison sheet for the same game as Image 1.
Input images: Image 1 is the EXACT approved visual-style reference, especially its bottom eight mice. Image 2 is the edit target: preserve its four boss identities, panel order, quadrupedal kitchen-object designs, and 02/03/04/05 labels, but redraw ALL characters to match Image 1, not Image 2's illustrative rendering.
Primary request: visibly match the existing F chibi game sprites in Image 1. This is essential: round oversized spiral pink ears, plump simplified gray-blue bodies, very short muzzles, tiny rounded pink paws, big solid-black charming eyes with small white glints, curling pink tails. Thick clean DARK NAVY contour. Flat local colors with just 2-3 clear cel-shadow blocks, soft cream/peach highlight. Clean graphic game sprite finish. Remove fine fur strokes, hair hatching, skin pores, metal scratches, speckling, tiny surface texture, realistic lighting, long realistic snouts, aggressive expressions, and watercolor paper texture. Reference image 1's gray/lid/drummer/boss mice are the exact facial and rendering target.
Keep the four quadrupedal heroes facing LEFT and show complete bodies including ears, tails and cookware. Top left: slim low mouse with teal perforated colander on back, two side measuring spoons, tiny tail whistle. Top right: very squat fat mouse inside a simplified charcoal iron-pot shell, THREE large copper rivets and a tiny top pressure knob; expose face, belly, paws. Bottom left: very round elder mouse, pale-gray fur, lavender bowl on back with THREE big rounded creamy dough lobes, a small wooden paddle strapped to bowl; simplified white flour patches only. Bottom right: alert angular but still cute mouse with horizontal wood abacus on back, exactly THREE large golden counter beads in its readable main prop, two jade grain pouches and grain scoop, curled tail touching a bead; no clothing/crown.
Composition: clean 2x2 design board, each quadrant has only ONE large full-body hero and ONE small simple prop detail, no floating duplicate heads. Solid pale cream background, subtle muted teal panel divisions, generous space. Small numerals "02", "03", "04", "05" only, no other text. This is concept art, not a screenshot or animation atlas. No new character classes, no humanoid poses, no chef hats, no watermark.
```
