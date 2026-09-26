class_name CardHub
extends Control

signal back_requested
signal launch_requested(selected: Array, difficulty: String, scene_id: String)

var model: MetaProgression
var sound: SoundService
var art := ArtCatalog.new()
var tab: String = "shop"
var main_uid: String = ""
var materials: Array = []
var selected: Array = []
var scene_id: String = "kitchen"
var difficulty: String = "easy"
var feedback: String = ""
var scroll_offset: int = 0
var inventory_scroll: ScrollContainer
var status: Label

func setup(storage: SaveService, catalog: Catalog, initial_tab: String = "shop") -> void:
	model = MetaProgression.new(storage, catalog)
	tab = initial_tab
	if model.reload():
		selected = model.profile.meta.loadout.duplicate()
		scene_id = model.profile.run.get("scene_id", "kitchen")
		difficulty = model.profile.run.get("difficulty", "easy")
	else: feedback = model.error
	rebuild()

func caption(parent: Control, value: String, pos: Vector2, bounds: Vector2, font_size: int = 17, color: Color = GameTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = bounds
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func play_cue(id: String) -> void:
	if is_instance_valid(sound) and not id.is_empty(): sound.cue(id)

func button(parent: Control, value: String, pos: Vector2, bounds: Vector2, callback: Callable, primary: bool = false, click_cue: String = "ui_click") -> Button:
	var node := Button.new()
	node.text = value
	node.position = pos
	node.size = bounds
	node.pressed.connect(func() -> void:
		play_cue(click_cue)
		callback.call())
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary: GameTheme.primary(node)
	parent.add_child(node)
	return node

func portrait(parent: Control, id: String, pos: Vector2, bounds: Vector2) -> void:
	var image := TextureRect.new()
	image.texture = art.food_portrait(id)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = pos
	image.size = bounds
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func surface(pos: Vector2, bounds: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = bounds
	panel.add_theme_stylebox_override("panel",GameTheme.box(GameTheme.SURFACE,18,GameTheme.BORDER))
	add_child(panel)
	return panel

func inset(parent: Control, pos: Vector2, bounds: Vector2, border: Color = GameTheme.BORDER) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = bounds
	panel.add_theme_stylebox_override("panel",GameTheme.box(GameTheme.RAISED,10,border))
	parent.add_child(panel)
	return panel

func food_role(id: String) -> String:
	var stats: Dictionary = model.data.foods[id].stats
	if stats.kind == "producer": return "热量补给"
	if stats.kind == "wall": return "前排阻挡"
	if stats.has("slow"): return "减速控场"
	if stats.has("radius"): return "范围清群"
	if stats.has("pierce"): return "穿透输出"
	if stats.has("aura"): return "近战助攻"
	return "近程高伤" if stats.reach < 4 else "稳定远攻"

func owned_count(id: String) -> int:
	var count: int = 0
	for item: Dictionary in model.profile.meta.cards:
		if item.id == id: count += 1
	return count

func card_tooltip(item: Dictionary) -> String:
	var definition: FoodDef = model.data.foods[item.id]
	var stats: Dictionary = definition.stats
	return "%s +%d · %s\n每次放置 %d 热量 · 放置冷却 %s 秒\n收藏卡可重复放置，不会因战斗消耗。" % [definition.title,int(item.level),food_role(item.id),int(stats.cost),str(stats.cooldown)]

func rebuild() -> void:
	if is_instance_valid(inventory_scroll): scroll_offset = inventory_scroll.scroll_vertical
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	inventory_scroll = null
	size = Vector2(1280,720)
	theme = GameTheme.create()
	var background := ColorRect.new()
	background.size = size
	background.color = GameTheme.BG
	add_child(background)
	caption(self,"美食卡册",Vector2(40,21),Vector2(240,50),32)
	caption(self,"备好拿手菜，再守一夜",Vector2(270,36),Vector2(550,30),17,GameTheme.MUTED)
	button(self,"返回主菜单",Vector2(1050,28),Vector2(188,44),func() -> void: back_requested.emit(),false,"ui_cancel")
	for index: int in range(3):
		var key: String = ["shop","enhance","loadout"][index]
		button(self,["灵感卡店","卡片强化","出战阵容"][index],Vector2(40+index*166,86),Vector2(152,42),func() -> void:
			tab = key
			scroll_offset = 0
			feedback = ""
			rebuild(),tab == key)
	if model.profile.is_empty():
		caption(self,feedback,Vector2(48,180),Vector2(1140,120),22,GameTheme.DANGER)
		return
	var wallet := inset(self,Vector2(874,84),Vector2(364,46))
	caption(wallet,"灵感  %d" % model.profile.meta.inspiration,Vector2(16,6),Vector2(188,32),22,GameTheme.GOLD)
	caption(wallet,"收藏 %d 张" % model.profile.meta.cards.size(),Vector2(216,10),Vector2(140,28),16,GameTheme.MUTED)
	if not model.editable():
		feedback = "当前有未结束的对局：可查看卡片，请返回主菜单继续或选择新局结束旧局。"
	if tab == "shop": build_shop()
	else:
		build_inventory()
		if tab == "enhance": build_enhancement()
		else:
			build_scenes()
			build_loadout()
	status = caption(self,feedback,Vector2(44,654),Vector2(1190, 48),17,GameTheme.ACCENT)

func transact(result: String, success_cue: String = "ui_click") -> void:
	feedback = result
	if result.is_empty():
		feedback = model.profile.meta.last_action.get("text","操作已保存")
		play_cue(success_cue)
	else: play_cue("ui_error")
	rebuild()

func build_shop() -> void:
	var meta: Dictionary = model.profile.meta
	var revision: int = int(model.profile.revision)
	caption(self,"今夜上新",Vector2(44,150),Vector2(200,30),22)
	caption(self,"新卡用于出战，同名卡也能用于强化",Vector2(214,153),Vector2(700,28),17,GameTheme.MUTED)
	for index: int in range(meta.offers.size()):
		var offer: Dictionary = meta.offers[index]
		var definition: FoodDef = model.data.foods[offer.id]
		var panel: Panel = surface(Vector2(44+index*232,196),Vector2(212,388))
		caption(panel,food_role(offer.id),Vector2(18,14),Vector2(176,26),16,GameTheme.ACCENT)
		portrait(panel,offer.id,Vector2(24,44),Vector2(164,142))
		caption(panel,definition.title,Vector2(18,188),Vector2(176,34),23)
		caption(panel,"放置 %d 热量" % int(definition.stats.cost),Vector2(18,228),Vector2(180,28),17,GameTheme.GOLD)
		caption(panel,"+0 新卡  ·  已拥有 %d 张" % owned_count(offer.id),Vector2(18,260),Vector2(182,28),15,GameTheme.MUTED)
		var shortfall: int = maxi(int(model.data.progression.card_price)-int(meta.inspiration),0)
		var availability: String = "每件限购一次" if shortfall == 0 else "还差 %d 灵感" % shortfall
		if offer.bought: availability = "已加入收藏"
		elif not model.editable(): availability = "对局中 · 仅可查看"
		caption(panel,availability,Vector2(18,297),Vector2(180,23),14,GameTheme.MUTED if shortfall == 0 or offer.bought else GameTheme.DANGER)
		var buy := button(panel,"已售罄" if offer.bought else "购买 · %d 灵感" % model.data.progression.card_price,Vector2(16,330),Vector2(180,42),func() -> void: transact(model.buy(index,revision),"purchase"),true,"")
		buy.name = "Buy_%d" % index
		buy.disabled = offer.bought or not model.editable() or shortfall > 0
		buy.tooltip_text = "%s · 放置冷却 %s 秒\n购买后可在出战阵容页携带。" % [food_role(offer.id),str(definition.stats.cooldown)]
	var info: Panel = surface(Vector2(984,196),Vector2(252,388))
	caption(info,"换一批拿手菜",Vector2(20,18),Vector2(216,36),23)
	caption(info,"每局结束自动换货\n并重置手动刷新费用",Vector2(20,70),Vector2(212,58),17,GameTheme.MUTED)
	caption(info,"本次刷新",Vector2(20,150),Vector2(210,26),15,GameTheme.MUTED)
	caption(info,"%d 灵感" % model.refresh_cost(),Vector2(20,180),Vector2(210,42),30,GameTheme.GOLD)
	var next_cost: String = "下次刷新 %d 灵感" % (model.refresh_cost()*2)
	if int(meta.refreshes)+1 >= model.data.progression.refresh_limit: next_cost = "本次后达到刷新上限"
	caption(info,next_cost,Vector2(20,228),Vector2(212,27),16,GameTheme.MUTED)
	var refresh_state: String = "本周期已刷新 %d 次" % int(meta.refreshes)
	if meta.refreshes >= model.data.progression.refresh_limit: refresh_state = "本周期刷新已达上限"
	elif meta.inspiration < model.refresh_cost(): refresh_state = "还差 %d 灵感可刷新" % (model.refresh_cost()-int(meta.inspiration))
	caption(info,refresh_state,Vector2(20,280),Vector2(212,36),15,GameTheme.MUTED)
	var refresh := button(info,"刷新卡店",Vector2(16,330),Vector2(220,42),func() -> void: transact(model.refresh(revision),"refresh"),false,"")
	refresh.name = "Refresh"
	refresh.disabled = not model.editable() or meta.inspiration < model.refresh_cost() or meta.refreshes >= model.data.progression.refresh_limit
	caption(self,"灵感来自通关与鼠群掉落，失败也保留。收藏卡可反复放置。",Vector2(44,606),Vector2(912,30),17,GameTheme.MUTED)
	button(self,"去配阵出战 →",Vector2(984,600),Vector2(252,40),func() -> void:
		tab = "loadout"
		scroll_offset = 0
		feedback = ""
		rebuild(),true)

func build_inventory() -> void:
	caption(self,"选择主卡和材料，右侧预览结果" if tab == "enhance" else "点选携带；同种美食会替换原卡",Vector2(42,146),Vector2(736,28),16,GameTheme.MUTED)
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.position = Vector2(40,182 if tab == "enhance" else 346)
	inventory_scroll.size = Vector2(744,450 if tab == "enhance" else 286)
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(inventory_scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	inventory_scroll.add_child(grid)
	var revision: int = int(model.profile.revision)
	for item: Dictionary in model.profile.meta.cards:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(172,214)
		var highlighted: bool = item.uid == main_uid if tab == "enhance" else item.uid in selected
		panel.add_theme_stylebox_override("panel",GameTheme.box(GameTheme.RAISED,12,GameTheme.GOLD if highlighted else (GameTheme.ACCENT if tab == "enhance" and item.uid in materials else GameTheme.BORDER)))
		panel.tooltip_text = card_tooltip(item)
		grid.add_child(panel)
		portrait(panel,item.id,Vector2(6,6),Vector2(74,74))
		caption(panel,model.data.foods[item.id].title,Vector2(82,13),Vector2(82,26),16)
		caption(panel,"+%d" % int(item.level),Vector2(82,46),Vector2(82,30),21,GameTheme.GOLD)
		caption(panel,"%s · %d 热量" % [food_role(item.id),int(model.data.foods[item.id].stats.cost)],Vector2(10,83),Vector2(156,25),15,GameTheme.ACCENT)
		var protection: String = "基础卡 · 不可作材料" if item.starter else ("已锁定 · 不可作材料" if item.locked else "可作为强化材料")
		caption(panel,protection,Vector2(10,113),Vector2(156,23),13,GameTheme.MUTED)
		if tab == "loadout":
			caption(panel,"已选入今夜阵容" if highlighted else "可重复放置",Vector2(10,145),Vector2(156,22),13,GameTheme.GOLD if highlighted else GameTheme.MUTED)
			var pick := button(panel,"✓ 已携带" if item.uid in selected else "携带出战",Vector2(10,172),Vector2(152,32),func() -> void: choose(item.uid),highlighted,"")
			pick.name = "Equip_" + item.uid
			pick.disabled = not model.editable()
		else:
			var main_pick := button(panel,"主卡 ✓" if item.uid == main_uid else "选主卡",Vector2(8,148),Vector2(74,30),func() -> void:
				main_uid = item.uid
				materials.erase(main_uid)
				feedback = ""
				rebuild(),item.uid == main_uid)
			main_pick.add_theme_font_size_override("font_size",14)
			var material := button(panel,"材料 ✓" if item.uid in materials else "选材料",Vector2(88,148),Vector2(76,30),func() -> void: select_material(item.uid),item.uid in materials,"")
			material.name = "Material_" + item.uid
			material.add_theme_font_size_override("font_size",14)
			material.disabled = item.starter or item.locked or item.uid == main_uid or not model.editable()
			material.tooltip_text = "所选材料无论成败都会消耗；先选主卡，再选 1～3 张材料。"
			if not item.starter:
				var lock := button(panel,"解除锁定" if item.locked else "锁定保护",Vector2(8,182),Vector2(156,24),func() -> void:
					materials.erase(item.uid)
					transact(model.toggle_lock(item.uid,revision)),false,"")
				lock.add_theme_font_size_override("font_size",12)
				lock.disabled = not model.editable()
				lock.tooltip_text = "锁定只防止作为材料消耗，不保护强化时的降级。"
	inventory_scroll.set_deferred("scroll_vertical",scroll_offset)

func choose(uid: String) -> void:
	if uid in selected:
		selected.erase(uid)
		play_cue("ui_cancel")
	else:
		var item: Dictionary = MetaProgression.card(model.profile.meta,uid)
		for other: String in selected.duplicate():
			if MetaProgression.card(model.profile.meta,other).id == item.id: selected.erase(other)
		if selected.size() >= model.data.progression.loadout_limit:
			feedback = "最多携带 %d 种美食，请先取消一张" % model.data.progression.loadout_limit
			play_cue("ui_error")
			rebuild()
			return
		selected.append(uid)
		play_cue("ui_click")
	feedback = ""
	rebuild()

func select_material(uid: String) -> void:
	if uid in materials:
		materials.erase(uid)
		play_cue("ui_cancel")
	elif materials.size() < 3:
		materials.append(uid)
		play_cue("ui_click")
	else:
		feedback = "一次最多使用 3 张材料卡"
		play_cue("ui_error")
	rebuild()

func build_enhancement() -> void:
	var panel: Panel = surface(Vector2(812,154),Vector2(424,478))
	var main: Dictionary = MetaProgression.card(model.profile.meta,main_uid)
	var preview: Dictionary = model.preview(main_uid,materials)
	caption(panel,"强化工作台",Vector2(24,16),Vector2(370,38),26)
	caption(panel,"1  选择主卡",Vector2(24,66),Vector2(370,26),16,GameTheme.GOLD)
	var main_slot := inset(panel,Vector2(24,100),Vector2(376,83))
	if main.is_empty():
		caption(main_slot,"从左侧点「选主卡」",Vector2(16,10),Vector2(344,28),20)
		caption(main_slot,"基础卡也能强化，并永久保留。",Vector2(16,44),Vector2(344,26),15,GameTheme.MUTED)
	else:
		portrait(main_slot,main.id,Vector2(6,5),Vector2(72,72))
		caption(main_slot,"%s  +%d → +%d" % [model.data.foods[main.id].title,int(main.level),mini(int(main.level)+1,model.data.progression.max_level)],Vector2(87,7),Vector2(280,30),20,GameTheme.GOLD)
		var stats: Dictionary = model.data.foods[main.id].stats
		var growth: String = "生命 +%d%%" % roundi(main.level * model.data.progression.stat_per_level * 100)
		if stats.damage > 0: growth += "  伤害 +%d%%" % roundi(main.level * model.data.progression.stat_per_level * 100)
		if stats.kind == "producer": growth += "  产量 +%d%%" % roundi(main.level * model.data.progression.production_per_level * 100)
		caption(main_slot,"当前："+growth,Vector2(87,43),Vector2(280,32),14,GameTheme.MUTED)
	caption(panel,"2  选择材料  %d / 3" % materials.size(),Vector2(24,198),Vector2(370,26),16,GameTheme.GOLD)
	for index: int in range(3):
		var slot := inset(panel,Vector2(24+index*128,232),Vector2(120,72),GameTheme.ACCENT if index < materials.size() else GameTheme.BORDER)
		var item: Dictionary = MetaProgression.card(model.profile.meta,materials[index]) if index < materials.size() else {}
		if item.is_empty():
			caption(slot,"＋",Vector2(12,13),Vector2(96,25),21,GameTheme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption(slot,"待选材料",Vector2(8,42),Vector2(104,22),13,GameTheme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			portrait(slot,item.id,Vector2(4,4),Vector2(52,56))
			caption(slot,"+%d" % int(item.level),Vector2(60,7),Vector2(54,26),18,GameTheme.ACCENT)
			caption(slot,model.data.foods[item.id].title,Vector2(57,38),Vector2(59,24),13)
			slot.tooltip_text = card_tooltip(item)
	caption(panel,"3  预览强化结果",Vector2(24,320),Vector2(370,26),16,GameTheme.GOLD)
	var chance_text: String = "成功率 %.1f%%" % (preview.chance*100) if preview.error.is_empty() else "等待选择"
	if not main.is_empty() and main.level >= model.data.progression.max_level: chance_text = "已达最高等级"
	caption(panel,chance_text,Vector2(24,352),Vector2(242,39),26,GameTheme.ACCENT)
	var failure: String = "主卡待选"
	var risk: bool = false
	var guaranteed: bool = preview.error.is_empty() and preview.chance >= 1.0
	if not main.is_empty():
		risk = int(preview.failure_level) < int(main.level)
		failure = "失败退到 +%d" % int(preview.failure_level) if risk else "失败保持 +%d" % int(main.level)
		if main.level >= model.data.progression.max_level: failure = "无需继续强化"
		elif guaranteed:
			failure = "本次必定成功"
			risk = false
	var outcome := caption(panel,failure,Vector2(262,358),Vector2(138,30),16,GameTheme.ACCENT if guaranteed else (GameTheme.DANGER if risk else GameTheme.MUTED))
	outcome.name = "EnhanceOutcome"
	caption(panel,"所选材料无论成败都会消耗 · 无灵感手续费",Vector2(24,400),Vector2(376,25),15,GameTheme.DANGER if not materials.is_empty() else GameTheme.MUTED)
	var revision: int = int(model.profile.revision)
	var enhance := button(panel,"强化这张卡" if preview.error.is_empty() else preview.error,Vector2(24,428),Vector2(376,36),func() -> void:
		var result: String = model.enhance(main_uid,materials,revision)
		var success_cue: String = ""
		if result.is_empty():
			for uid: String in materials: selected.erase(uid)
			materials.clear()
			success_cue = "upgrade_success" if str(model.profile.meta.last_action.get("text","")).begins_with("强化成功") else "upgrade_fail"
		transact(result,success_cue),true,"")
	enhance.name = "Enhance"
	enhance.disabled = not preview.error.is_empty() or not model.editable()

func build_loadout() -> void:
	var panel: Panel = surface(Vector2(812,154),Vector2(424,478))
	caption(panel,"今夜出战",Vector2(24,16),Vector2(230,38),26)
	caption(panel,"%d / %d 种" % [selected.size(),model.data.progression.loadout_limit],Vector2(292,21),Vector2(108,32),20,GameTheme.GOLD)
	caption(panel,"阵容带入整局，收藏卡可反复放置",Vector2(24,60),Vector2(376,26),16,GameTheme.MUTED)
	var attackers: int = 0
	var blockers: int = 0
	var producers: int = 0
	for index: int in range(model.data.progression.loadout_limit):
		var slot := inset(panel,Vector2(24+index*77,100),Vector2(68,98),GameTheme.GOLD if index < selected.size() else GameTheme.BORDER)
		var item: Dictionary = MetaProgression.card(model.profile.meta,selected[index]) if index < selected.size() else {}
		if item.is_empty():
			caption(slot,"＋",Vector2(4,20),Vector2(60,28),24,GameTheme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption(slot,"空位",Vector2(4,62),Vector2(60,24),13,GameTheme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			portrait(slot,item.id,Vector2(6,2),Vector2(56,56))
			caption(slot,model.data.foods[item.id].title,Vector2(2,56),Vector2(64,22),13).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption(slot,"+%d" % int(item.level),Vector2(4,76),Vector2(60,20),13,GameTheme.GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.tooltip_text = card_tooltip(item)
			var stats: Dictionary = model.data.foods[item.id].stats
			if stats.damage > 0: attackers += 1
			if stats.kind == "wall": blockers += 1
			if stats.kind == "producer": producers += 1
	caption(panel,"攻击 %d  ·  阻挡 %d  ·  补给 %d" % [attackers,blockers,producers],Vector2(24,210),Vector2(376,26),17,GameTheme.ACCENT)
	caption(panel,"本局难度 · 出发后全程固定",Vector2(24,252),Vector2(376,26),16,GameTheme.GOLD)
	for index: int in range(model.data.difficulties.size()):
		var id: String = model.data.difficulties.keys()[index]
		var definition: DifficultyDef = model.data.difficulties[id]
		var option := button(panel,"%s%s" % ["✓ " if difficulty == id else "",definition.title],Vector2(24+index*128,286),Vector2(120,38),func() -> void: choose_difficulty(id),difficulty == id)
		option.name = "Difficulty_" + id
		option.add_theme_font_size_override("font_size",16)
		option.disabled = not model.editable()
		option.tooltip_text = "敌人生命 ×%s、伤害 ×%s，通关灵感 ×%s；击杀灵感掉落概率 %d%%。整局不能更改。" % [str(definition.hp_multiplier),str(definition.damage_multiplier),str(definition.reward_multiplier),roundi(definition.inspiration_drop_chance * 100.0)]
	var active: DifficultyDef = model.data.difficulties[difficulty]
	caption(panel,"敌人生命 ×%s · 伤害 ×%s\n通关灵感 ×%s · 击杀掉落 %d%%" % [str(active.hp_multiplier),str(active.damage_multiplier),str(active.reward_multiplier),roundi(active.inspiration_drop_chance*100.0)],Vector2(24,336),Vector2(376,49),16,GameTheme.MUTED)
	var issue: String = MetaProgression.loadout_error(model.profile.meta,selected,model.data)
	if issue.is_empty(): issue = model.data.scene_error(scene_id)
	var readiness: String = "阵容已就绪，先去小铺挑选食谱" if issue.is_empty() else issue
	if not model.editable(): readiness = "对局进行中，请返回主菜单继续"
	caption(panel,readiness,Vector2(24,395),Vector2(376,26),16,GameTheme.ACCENT if issue.is_empty() and model.editable() else GameTheme.DANGER)
	var launch := button(panel,"出发，从第 1 大关开始 →",Vector2(24,428),Vector2(376,36),func() -> void: launch_requested.emit(selected.duplicate(),difficulty,scene_id),true)
	launch.name = "Launch"
	launch.disabled = not issue.is_empty() or not model.editable()
	launch.tooltip_text = issue

func choose_difficulty(id: String) -> void:
	if not model.editable() or not model.data.difficulties.has(id): return
	difficulty = id
	rebuild()

func build_scenes() -> void:
	var selector := OptionButton.new()
	selector.name = "SceneSelect"
	selector.position = Vector2(40, 184)
	selector.size = Vector2(744, 38)
	selector.add_theme_font_size_override("font_size", 19)
	add_child(selector)
	selector.get_popup().add_theme_color_override("font_disabled_color", GameTheme.MUTED)
	selector.get_popup().add_theme_stylebox_override("panel", GameTheme.box(GameTheme.SURFACE, 10, GameTheme.BORDER))
	for id: String in model.data.scenes:
		var scene: ScenarioDef = model.data.scenes[id]
		var issue: String = model.data.scene_error(id)
		selector.add_item("场景 · %s" % scene.title)
		var index: int = selector.item_count - 1
		selector.set_item_metadata(index, id)
		selector.set_item_disabled(index, not issue.is_empty())
		if id == scene_id: selector.select(index)
	selector.disabled = not model.editable()
	selector.item_selected.connect(func(index: int) -> void:
		var id: String = selector.get_item_metadata(index)
		if not model.editable() or not model.data.scene_error(id).is_empty(): return
		scene_id = id
		rebuild())
	var chapters: Array[String] = model.data.scene_chapters(scene_id)
	for index: int in range(chapters.size()):
		var chapter: ChapterDef = model.data.chapters[chapters[index]]
		var stage := inset(self,Vector2(40 + index * 151,232),Vector2(140,52))
		stage.name = "ChapterRoute_" + chapter.id
		stage.mouse_filter = Control.MOUSE_FILTER_STOP
		stage.tooltip_text = "第 %d 大关 · %s\n%s\n场景内按顺序抵达，每大关 8 小关。" % [chapter.order,chapter.title,chapter.strategy]
		caption(stage,"第 %d 大关" % chapter.order,Vector2(10,3),Vector2(120,20),12,GameTheme.GOLD)
		caption(stage,chapter.title,Vector2(10,23),Vector2(120,25),16)
	caption(self,"五大关 × 八小关 · 一次出发，1-1 → 5-8（共 %d 关）\n跨大关保留阵地、热量、粮仓与食谱。" % model.data.scene_wave_count(scene_id),Vector2(44,291),Vector2(734,46),15,GameTheme.MUTED)
