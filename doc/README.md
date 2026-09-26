# 项目文档索引

`doc/` 是本项目全部设定、设计、工程决策和验收记录的统一存放位置。根目录的 [AGENTS.md](../AGENTS.md) 规定协作流程，工程细则在本目录维护。

## 当前文档

| 文档 | 用途 | 状态 |
|---|---|---|
| [TODO.md](TODO.md) | 首版玩法、内容数值、实现方案、里程碑及验收基线 | 首版代码已接入，真人与平衡验收待完成 |
| [engineering.md](engineering.md) | 工程基线、模块约束、代码与资源规范、验证和交付流程 | 工程约定；现状差异见正文 |

| [technical/runtime.md](technical/runtime.md) | 模块、时间、随机、阶段与存档设计 | 已确定，逐步实现 |
| [design/screens.md](design/screens.md) | 主菜单、继续／新局与全屏胜败战报 | 已实现，窗口鼠标验收待完成 |
| [testing/screens.md](testing/screens.md) | 菜单与战报流程、存档及渲染验证 | 导入、16 组回归与原生渲染通过 |
| [design/shop.md](design/shop.md) | 食谱与灵感统一商店购买、价格与存档兼容规则 | 已实现，经济平衡待验证 |
| [testing/shop.md](testing/shop.md) | 统一商店的交易、购物完成开战、存档与窗口验收 | 最新流程自动／渲染通过，鼠标复验待完成 |
| [design/heat.md](design/heat.md) | 热量自然恢复、生产火苗与点击飞行收取 | 已实现，验证边界见专页 |
| [testing/heat.md](testing/heat.md) | 热量拾取的逻辑、输入与窗口验证 | 拾取回归及上限调整验证通过，范围与限制见正文 |
| [testing/implementation.md](testing/implementation.md) | 分步实现与实际验证记录 | 持续更新 |

| [art/ui.md](art/ui.md) | 全局 UI 主题、图上费下与星内等级卡牌、拖放与冷却、小铺弹窗规范 | 已接入，验证见专页 |
| [testing/ui.md](testing/ui.md) | 全界面优化的自动、渲染与鼠标验收 | 锅铲光标回归、两尺寸渲染及 macOS 编辑器旧光标缓存重载复验通过 |
| [art/damage_feedback.md](art/damage_feedback.md) | 双方伤害数字、shader、事件及生命周期 | 已实现，原生画面通过 |
| [testing/damage_feedback.md](testing/damage_feedback.md) | 伤害数值、暂停倍速、shader 与渲染验证 | 逻辑及原生渲染通过，真人压力待验 |
| [art/projectiles.md](art/projectiles.md) | 五种美食弹体与高压蒸汽变体 | 已实现 |
| [testing/projectiles.md](testing/projectiles.md) | 弹体导入、暂停倍速、回归与渲染 | 自动和原生渲染通过，真人试玩未执行 |
| [art/presentation.md](art/presentation.md) | 原创视觉、音效与来源许可 | 生成美术已接入 |
| [art/style_exploration.md](art/style_exploration.md) | 小笼包与灰鼠的现代 Q 版风格、造型与动作创意候选 | 已选择 F，历史候选保留 |
| [art/f_animation_frames.md](art/f_animation_frames.md) | 已选 F 风格的小笼包与灰鼠完整动作图集 | 72 帧原稿已交付；运行时接入及检查见 F 专项记录 |
| [art/f_restyle.md](art/f_restyle.md) | F 风格全角色造型及正式资源替换 | 全部 16 角色已正式替换，小笼包及鼠群逐帧已接入 |
| [art/f_restyle_prompts.md](art/f_restyle_prompts.md) | 八美食与七鼠新图的完整内置工具提示词 | 已归档 |
| [testing/f_restyle.md](testing/f_restyle.md) | F 替换的源图、处理与接入验收 | 15 组回归及原生渲染完成；窗口交互／缩放复验受限 |
| [testing/mouse_animation.md](testing/mouse_animation.md) | 鼠群逐帧动作、回归与图集验收 | 14 组回归、全部帧渲染与原生窗口专项通过 |
| [art/animation.md](art/animation.md) | 美食程序动画与鼠群四组逐帧动画规则及验收 | 鼠群专项通过，历史美食验收边界见正文 |
| [art/perspective.md](art/perspective.md) | 正交棋盘、顶部卡牌、底部操作栏与鼠标命中 | 棋盘居中、左侧行号及右侧灰箭头移除已实现，验证见专页 |
| [art/asset_pack.md](art/asset_pack.md) | 29 项美术内容、规格、映射与接入 | 已生成并接入 |
| [art/generation_prompts.md](art/generation_prompts.md) | 四类资源的完整生成提示词 | 已记录 |
| [testing/asset_edges.md](testing/asset_edges.md) | 图集透明边缘、跨格残片修复与验证 | 已修整；逐格对照、导入与原生渲染通过 |
| [testing/art_pack.md](testing/art_pack.md) | 美术导入、窗口及性能验收 | 见实际记录 |
| [testing/layout.md](testing/layout.md) | 正交棋盘与顶部 UI 验证 | 自动及渲染检查通过，鼠标复验待完成 |
| [releases/0.1.0.md](releases/0.1.0.md) | macOS 导出与启动、存档兼容性 | 本机导出启动通过 |

| [design/waves.md](design/waves.md) | 组合波次、重点路线及后期数量调整 | 已实现，真人平衡待验 |
| [testing/balance.md](testing/balance.md) | 压力测试、组合鼠潮回归和真人验收缺口 | 新波次回归及渲染通过，真人待验收 |

## 后续文档归档

按实际工作需要创建目录和文档，不预建没有内容的模板文件。

| 目录 | 应记录的内容 |
|---|---|
| `design/` | 战斗、经济、食谱、成长、角色设定、关卡、数值、叙事和交互设计 |
| `technical/` | 状态机、模块接口、数据结构、资源格式、存档、随机性和性能方案 |
| `art/` | 视觉规范、动画、UI 资产、音频设计及素材来源记录 |
| `decisions/` | 影响范围、架构、接口或工作流的重要决策及替代方案 |
| `testing/` | 验收用例、复现步骤、实际测试结果、性能环境和试玩分析 |
| `releases/` | 导出流程、版本说明、目标平台、发布检查和已知问题 |

新增文档必须加入本索引，并链接相关上游规则。文档至少包含：状态（拟议／已确定／已实现／已废弃）、适用范围、设计或规则、边界及异常情况、验收方式；涉及数值或接口时增加相应定义。只有实际完成实现及验证，才能更新为“已实现”。

重要决策使用 `decisions/ADR-NNN-主题.md`，记录背景、选择、理由、影响、状态和日期。被替代的决策保留历史并链接后继决策；当前规则同步更新到其权威文档。
