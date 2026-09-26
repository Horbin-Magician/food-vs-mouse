# 战斗厨房背景与 HUD

状态：已实现；导入、回归与双尺寸原生渲染通过，鼠标复验限制见 [验收](../testing/battle_environment.md)。适用「使用体验」里程碑；玩法基线见 [TODO](../TODO.md)，坐标权威见 [棋盘布局](perspective.md)。

## 视觉与边界

以原创现代 Q 版深夜厨房为环境：青绿木作、暖色灯光、奶油色瓷砖、黄铜收边；左侧粮仓与蒸笼，右侧灶台与厨具。两侧有细节，中间保持低对比，为现有角色留出视觉空间。生成背景不含文字、角色或交互按钮；运行时棋盘格、资源数字、控件、提示均独立绘制，避免画入假按钮。

棋盘仍为 (271,88)、738×574，7×9 正方形格；不更改投影、命中、卡牌尺寸、拖放及冷却；设置、倍速与锅铲位置现按 [设置设计](../design/settings.md) 调整。棋盘采用奶油／鼠尾草色瓷砖与薄接缝、木质外框。顶栏与底栏采用深青绿底、黄铜细边；热量、本局灵感、耐久继续展示实时业务值。两侧环境信息牌展示粮仓状态及本关信息，不能挡住棋盘与右侧入场单位。装饰由 Node2D 绘制，不接收输入。暂停与倍速沿用现有逻辑。

## 来源

背景由 OpenAI 内置 imagegen 生成，作为本项目原创生成美术；无下载第三方素材、无新增插件或运行依赖。不作外部素材独占版权承诺。最终资源与完整提示词在本页补记。

正式资源：`assets/art/battle_kitchen.png`，1672×941，运行时铺满 1280×720；原始生成尺寸与 16:9 的微小差异仅作用于装饰背景，不影响命中。UI 由 `scripts/ui/battle_art.gd` 绘制，样式实例复用；文字读取 RunState，无独立业务状态。卡牌在 x=190–822 居中，粮仓框 x=846–984、本局灵感框 x=994–1094；右侧铭牌 x=1100–1244，避让入场角色。

### 完整生成提示词（内置工具）

```text
Use case: stylized-concept. Asset: production 16:9 background for an original cozy Chinese midnight kitchen tower-defense game. Create polished hand-painted modern chibi game environment, rich teal painted wood cabinets, warm amber lantern light, rounded forms, subtle gouache texture, clean readable silhouettes. Camera is perfectly overhead orthographic, not isometric. Composition crucial: center x=21% to 79%, y=11% to 93% is an EMPTY muted sage work surface with no objects, no grid, no markings; runtime board covers this entire rectangle. All beautiful kitchen details concentrated in left and right 20% side strips. Left strip: bamboo steam baskets, small ceramic rice jar, folded cream towel, leafy herb, dark wood worktop. Right strip: warmly glowing round stove, copper saucepan, hanging ladle, bowls and tiny condiment pots on teal cabinetry. Top 11% and bottom 7% relatively dark empty teal for HUD overlays. Cozy night atmosphere, tasteful golden light pools and dark teal shadows, premium casual strategy game art, cohesive carefully composed decorative side rails. No people, no creatures, no food characters, no lettering, no logos, no UI, no borders, no perspective grid. Landscape 1536x864 or 16:9.
```

## 验收

Godot 4.6.3 导入、相关 UI／拖放／锅铲／投影回归；1280×720 与 1600×900 原生渲染检查棋盘、八卡、暂停和资源；原生窗口检查放置、取消及暂停。未实际执行的验证须明确保留。

2026-09-26 资源区已按 [经济设计](../design/economy.md) 移除金币，原金币框改为紫色本局灵感累计及拾取飞行终点；战斗与小铺热量共用余额，视觉及交互验证见 [经济验收](../testing/economy.md)。
