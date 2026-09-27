# 项目文档索引

`doc/` 是本项目全部设定、设计、工程决策和验收记录的统一存放位置。根目录的 [AGENTS.md](../AGENTS.md) 规定协作流程，工程细则在本目录维护。

## 当前文档

| 文档 | 用途 | 状态 |
|---|---|---|
| [testing/code_optimization.md](testing/code_optimization.md) | 帧内绘制、战斗查询索引、重复逻辑与死代码清理，五项旧断言修正及前后确定性与性能对比 | 已实现；47 项回归通过，32 小关确定性一致 |
| [testing/chapter_enemy_edges.md](testing/chapter_enemy_edges.md) | 新鼠 37 张图集、780 帧边界碎片修复及复验 | 透明边、尺寸、4 项回归与双尺寸原生画面通过 |
| [testing/food_attack_speed.md](testing/food_attack_speed.md) | 全部攻击美食攻速降低 50% 的配置与回归验证 | 配置及七组回归通过；整局平衡未重验 |
| [testing/food_damage.md](testing/food_damage.md) | 全部美食及食谱灼烧的历次调整与当前翻倍验证 | 本轮配置及六组回归通过；整局平衡未重验 |
| [design/chapter_enemy_redesign.md](design/chapter_enemy_redesign.md) | 后四关 8 新普通鼠、4 精英、4 独立首领的设定、属性、技能、背景与反制 | 玩法已接入；图集边界已修复，完整细节验收待完成 |
| [design/chapter_encounters_v2.md](design/chapter_encounters_v2.md) | 后四关 32 小关组成、教学、选路与批次节奏 | 32 波次与排程检查通过；连续采样完成，真人平衡待验 |
| [art/chapter_enemy_redesign.md](art/chapter_enemy_redesign.md) | 延续 F 画风的角色轮廓、概念图、技能表现与制作验收 | 全套运行图已整理；完整细节验收待完成 |
| [art/chapter_enemy_assets.md](art/chapter_enemy_assets.md) | 16 角色、卸壳变体、独立技能帧与实际来源、接口、整理记录 | 37 图／780 帧已整理；隔离带、尺寸及脚点通过，完整细节另验 |
| [art/chapter_enemy_redesign_prompts.md](art/chapter_enemy_redesign_prompts.md) | 四首领概念图的完整提示词、来源与画风修订 | 已归档，最终参考图已入库 |
| [technical/enemy_abilities.md](technical/enemy_abilities.md) | 新鼠与独立首领状态、计时、护盾、伤害及取消接口 | 已接入；专项回归通过 |
| [technical/enemy_presentation.md](technical/enemy_presentation.md) | 技能预警、地面状态、首领面板、悬停与生命周期 | 已接入；正式图集边界与原生专项已复验，完整细节另验 |
| [art/chapter_enemy_audio.md](art/chapter_enemy_audio.md) | 新鼠四类原创合成音效、事件映射与资产校验 | 已生成并接入；听感待检查 |
| [testing/chapter_enemy_redesign.md](testing/chapter_enemy_redesign.md) | 本次设计文档静态检查、交叉评审与后续验证边界 | 设计检查记录；不代表实现通过 |
| [testing/chapter_enemy_implementation.md](testing/chapter_enemy_implementation.md) | 新鼠群技能、表现、音效、原生画面与当前验收边界 | 历史 44／2；图集失败已修复，4 项相关回归及原生专项复验通过 |
| [testing/chapter_enemy_balance.md](testing/chapter_enemy_balance.md) | 三难度三构筑三种子的基线，以及两关编排修正后的连续补采 | 基线 27 场 24 胜；新版普通 5 场全胜，分版本记录 |
| [TODO.md](TODO.md) | 首版玩法、内容数值、实现方案、里程碑及验收基线 | 连续四十关与新鼠群已接入；新鼠图集边界已整理，未更新发布包 |
| [design/campaign.md](design/campaign.md) | 场景内五大关连续推进、后四关重设、全局进度与 v4 迁移 | 连续流程已实现；新鼠群验证与剩余项分项记录 |
| [testing/continuous_campaign.md](testing/continuous_campaign.md) | 连续四十关、跨大关继承、迁移防重、原生界面及正常战斗采样 | 本轮验证记录 |
| [testing/continuous_campaign_autoplay.json](testing/continuous_campaign_autoplay.json) | 六个连续场景战斗样本 | 自动证据，含失败样本 |
| [testing/continuous_campaign_growth.json](testing/continuous_campaign_growth.json) | 零资产三卡连续挑战与逐关读档 | 实际5-7失败，保留真实结果 |
| [design/campaign_independent_history.md](design/campaign_independent_history.md) | 原独立选关／解锁／重置方案与分期路线 | 已废弃，仅历史背景 |
| [testing/campaign_autoplay.json](testing/campaign_autoplay.json) | 第一大关三构筑三种子的逐关自动采样 | 自动证据，不代表真人或成长路径 |
| [testing/campaign.md](testing/campaign.md) | 战役实现、迁移、回归与试玩证据 | 逻辑、成长、原生交互、发布验证及性能限制已记录 |
| [releases/0.2.0-rc1.md](releases/0.2.0-rc1.md) | 五夜候选包、启动、兼容、来源及限制 | 本轮候选交付记录 |
| [testing/campaign_playtest_form.md](testing/campaign_playtest_form.md) | 可选的匿名逐关试玩记录表 | 仅材料；本次真人测试用户豁免 |
| [engineering.md](engineering.md) | 工程基线、模块约束、代码与资源规范、验证和交付流程 | 工程约定；现状差异见正文 |
| [design/pvz_innovation_research.md](design/pvz_innovation_research.md) | PVZ 与相关策略游戏调研、十二项机制候选、优先级及验证建议 | 调研完成；新增机制均为拟议，未纳入首版排期 |
| [design/meta_progression.md](design/meta_progression.md) | 灵感购卡、有限携卡、翻倍刷新与耗材概率强化 | 已接入，初始参数与验收边界见专项记录 |
| [technical/card_progression.md](technical/card_progression.md) | 卡片参数、概率、经济、模块和 v2 迁移规格 | 已接入，数值待真人平衡 |
| [decisions/ADR-001-profile-transactions.md](decisions/ADR-001-profile-transactions.md) | 卡片资产与对局单文件原子事务的取舍 | 已采用 |
| [testing/meta_progression.md](testing/meta_progression.md) | 成长体系逻辑、存档、界面与经济试算验收 | 见实际检查与限制 |

| [technical/runtime.md](technical/runtime.md) | 模块、时间、随机、阶段与存档设计 | 已确定，逐步实现 |
| [design/screens.md](design/screens.md) | 主菜单、继续／新局与全屏胜败战报 | 已实现，窗口鼠标验收待完成 |
| [design/settings.md](design/settings.md) | 热量下方倍速、统一设置、Esc 暂停及返回菜单／退出规则 | 已实现，验证边界见专项记录 |
| [testing/settings.md](testing/settings.md) | 设置、暂停所有权、存档离开与双尺寸界面验收 | 36 项回归、原生输入与渲染通过，真实鼠标复验受限 |
| [testing/screens.md](testing/screens.md) | 菜单与战报流程、存档及渲染验证 | 导入、16 组回归与原生渲染通过 |
| [design/shop.md](design/shop.md) | 大关通关后小铺、普通小关自动衔接与旧档兼容 | 已实现；仅大关间四次购物，最终大关直接胜利 |
| [testing/shop.md](testing/shop.md) | 大关小铺的交易、连续开战、存档重试与窗口验收 | 41 项回归及双尺寸渲染通过；真实鼠标复验受限 |
| [design/economy.md](design/economy.md) | 热量购食谱、跨关保留与鼠群灵感拾取、防重复存档 | 已实现；用户指定掉落率与价格已更新，整局平衡待验 |
| [testing/economy.md](testing/economy.md) | 新经济逻辑、迁移、拾取和窗口验收 | 初次 35 项、本次数值调整九项及双尺寸渲染通过；真实鼠标复验受限 |
| [design/heat.md](design/heat.md) | 热量自然恢复、生产火苗、点击飞行收取与跨关保留 | 已实现，验证边界见专页 |
| [testing/heat.md](testing/heat.md) | 热量拾取的逻辑、输入与窗口验证 | 15 秒生产及拾取回归通过；其他伤害断言失败与验证边界见正文 |
| [testing/implementation.md](testing/implementation.md) | 分步实现与实际验证记录 | 持续更新 |

| [art/battle_environment.md](art/battle_environment.md) | 深夜厨房背景、瓷砖与战斗 HUD 视觉及生成提示词 | 已接入，原生鼠标复验待完成 |
| [testing/battle_environment.md](testing/battle_environment.md) | 战斗美术的导入、回归与双尺寸渲染验证 | 已完成，窗口工具限制见正文 |
| [art/ui_refresh.md](art/ui_refresh.md) | 全操作界面的主题、菜单／战报层级与设置速记 | 已实现，验收与限制见专项 |
| [art/ui_card_hub.md](art/ui_card_hub.md) | 卡店用途、强化预览、五槽阵容与难度信息 | 已实现 |
| [art/ui_battle_refresh.md](art/ui_battle_refresh.md) | 战斗 HUD 去重、冷却秒数及小铺预算 | 已实现 |
| [testing/ui_refresh.md](testing/ui_refresh.md) | 本轮全界面自动、双尺寸渲染及原生鼠标验收 | 36 项回归、38 张原生画面与关键鼠标链路通过，八关试玩待验 |
| [art/ui.md](art/ui.md) | 全局 UI 主题、图上费下与星内等级卡牌、拖放与冷却、小铺弹窗规范 | 已接入，验证见专页 |
| [testing/ui.md](testing/ui.md) | 全界面优化的自动、渲染与鼠标验收 | 锅铲光标回归、两尺寸渲染及 macOS 编辑器旧光标缓存重载复验通过 |
| [art/damage_feedback.md](art/damage_feedback.md) | 双方伤害数字、shader、事件及生命周期 | 已实现，原生画面通过 |
| [testing/damage_feedback.md](testing/damage_feedback.md) | 伤害数值、暂停倍速、shader 与渲染验证 | 逻辑及原生渲染通过，真人压力待验 |
| [art/status_effects.md](art/status_effects.md) | Buff 光晕、状态徽记、首领召唤与技能动画及事件接口 | 已接入 |
| [testing/status_effects.md](testing/status_effects.md) | 状态边界、技能事件、生命周期、双尺寸与鼠标验收 | 28 组回归及原生专项通过；性能限制见正文 |
| [art/projectiles.md](art/projectiles.md) | 五种美食弹体与高压蒸汽变体 | 已实现 |
| [testing/projectiles.md](testing/projectiles.md) | 弹体导入、暂停倍速、回归与渲染 | 自动和原生渲染通过，真人试玩未执行 |
| [art/presentation.md](art/presentation.md) | 原创视觉、音效与来源许可 | 生成美术已接入 |
| [art/audio.md](art/audio.md) | 七种场景音乐、事件音效、混音、暂停与声音设置 | 已接入 |
| [art/audio_assets.md](art/audio_assets.md) | 原创旋律、音色、生成工具、资产规格与来源 | 7 首音乐与 28 音效生成、解码及确定性检查通过 |
| [testing/audio.md](testing/audio.md) | 音频资产、流程、混音、音量设置及原生交互验收 | 31 组回归、双尺寸画面及鼠标检查通过；听感边界见正文 |
| [art/style_exploration.md](art/style_exploration.md) | 小笼包与灰鼠的现代 Q 版风格、造型与动作创意候选 | 已选择 F，历史候选保留 |
| [art/f_animation_frames.md](art/f_animation_frames.md) | 已选 F 风格的小笼包与灰鼠完整动作图集 | 72 帧原稿已交付；运行时接入及检查见 F 专项记录 |
| [art/f_restyle.md](art/f_restyle.md) | F 风格全角色造型及正式资源替换 | 全部 16 角色已正式替换，小笼包及鼠群逐帧已接入 |
| [art/f_restyle_prompts.md](art/f_restyle_prompts.md) | 八美食与七鼠新图的完整内置工具提示词 | 已归档 |
| [testing/f_restyle.md](testing/f_restyle.md) | F 替换的源图、处理与接入验收 | 15 组回归及原生渲染完成；窗口交互／缩放复验受限 |
| [testing/mouse_animation.md](testing/mouse_animation.md) | 鼠群逐帧动作、回归与图集验收 | 14 组回归、全部帧渲染与原生窗口专项通过 |
| [testing/animation_smoothness.md](testing/animation_smoothness.md) | 动画换帧、连续受击防重置及平滑形变验证 | 四组回归与原生采样完成；窗口交互与连续观看待复验 |
| [art/animation.md](art/animation.md) | 美食程序动画与鼠群四组逐帧动画规则及验收 | 鼠群专项通过，历史美食验收边界见正文 |
| [art/perspective.md](art/perspective.md) | 正交棋盘、顶部卡牌、底部操作栏与鼠标命中 | 棋盘居中、左侧行号及右侧灰箭头移除已实现，验证见专页 |
| [art/asset_pack.md](art/asset_pack.md) | 29 项美术内容、规格、映射与接入 | 已生成并接入 |
| [art/generation_prompts.md](art/generation_prompts.md) | 四类资源的完整生成提示词 | 已记录 |
| [testing/asset_edges.md](testing/asset_edges.md) | 图集透明边缘、跨格残片修复与验证 | 已修整；逐格对照、导入与原生渲染通过 |
| [testing/art_pack.md](testing/art_pack.md) | 美术导入、窗口及性能验收 | 见实际记录 |
| [testing/layout.md](testing/layout.md) | 正交棋盘与顶部 UI 验证 | 自动及渲染检查通过，鼠标复验待完成 |
| [releases/0.1.0.md](releases/0.1.0.md) | macOS 导出与启动、存档兼容性 | 本机导出启动通过 |

| [design/difficulty.md](design/difficulty.md) | 开局统一难度、整局锁定、倍率与兼容规则 | 已实现，整局平衡待试玩 |
| [testing/difficulty.md](testing/difficulty.md) | 难度及收益、存档及界面验证 | 整局锁定 31 组回归与双尺寸渲染通过；鼠标复验限制见正文 |
| [testing/spawn_rate.md](testing/spawn_rate.md) | 全部 40 小关出兵频率提高 50% 的排程、回归及原生画面验证 | 已通过专项检查，整局平衡未重采 |
| [design/waves.md](design/waves.md) | 组合波次、重点路线、生命与召唤，以及末波后 10 秒通关 | 已实现，余鼠跨关整局平衡待验 |
| [testing/wave_completion.md](testing/wave_completion.md) | 末波后 10 秒、余鼠保留、大关 BOSS 击败门槛及界面 | 9 组回归、导入与双尺寸原生画面通过 |
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
