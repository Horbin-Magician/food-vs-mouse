class_name CardHub
extends Control

signal back_requested
signal launch_requested(selected: Array)

var model: MetaProgression
var art := ArtCatalog.new()
var tab: String = "shop"
var main_uid: String = ""
var materials: Array = []
var selected: Array = []
var feedback: String = ""
var scroll_offset: int = 0
var inventory_scroll: ScrollContainer
var status: Label

func setup(storage: SaveService, catalog: Catalog, initial_tab: String = "shop") -> void:
	model = MetaProgression.new(storage, catalog)
	tab = initial_tab
	if model.reload(): selected = model.profile.meta.loadout.duplicate()
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

func button(parent: Control, value: String, pos: Vector2, bounds: Vector2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.position = pos
	node.size = bounds
	node.pressed.connect(callback)
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
	caption(self,"美食卡册",Vector2(40,24),Vector2(400,50),32)
	button(self,"返回主菜单",Vector2(1050,28),Vector2(188,44),func() -> void: back_requested.emit())
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
	caption(self,"灵感  %d    ·    收藏 %d 张" % [model.profile.meta.inspiration,model.profile.meta.cards.size()],Vector2(692,88),Vector2(540,38),21,GameTheme.GOLD)
	if not model.editable():
		feedback = "当前有未结束的对局：可查看卡片，请返回主菜单继续或选择新局结束旧局。"
	if tab == "shop": build_shop()
	else:
		build_inventory()
		if tab == "enhance": build_enhancement()
		else: build_loadout()
	status = caption(self,feedback,Vector2(44,646),Vector2(1190, 60),17,GameTheme.ACCENT)

func transact(result: String) -> void:
	feedback = result
	if result.is_empty(): feedback = model.profile.meta.last_action.get("text","操作已保存")
	rebuild()

func build_shop() -> void:
	var meta: Dictionary = model.profile.meta
	var revision: int = int(model.profile.revision)
	caption(self,"每张 +0 卡片 %d 灵感 · 可购入同名卡作为强化材料" % model.data.progression.card_price,Vector2(44,152),Vector2(1000,30),18,GameTheme.MUTED)
	for index: int in range(meta.offers.size()):
		var offer: Dictionary = meta.offers[index]
		var panel: Panel = surface(Vector2(44+index*232,206),Vector2(212,352))
		portrait(panel,offer.id,Vector2(22,18),Vector2(168,168))
		caption(panel,model.data.foods[offer.id].title,Vector2(18,194),Vector2(180,34),23)
		caption(panel,"强化 +0 · 独立卡片",Vector2(18,240),Vector2(180,28),15,GameTheme.MUTED)
		var buy := button(panel,"已售罄" if offer.bought else "购买 · %d 灵感" % model.data.progression.card_price,Vector2(16,290),Vector2(180,42),func() -> void: transact(model.buy(index,revision)),true)
		buy.name = "Buy_%d" % index
		buy.disabled = offer.bought or not model.editable() or meta.inspiration < model.data.progression.card_price
	var info: Panel = surface(Vector2(984,206),Vector2(252,352))
	caption(info,"刷新卡店",Vector2(20,22),Vector2(210,40),24)
	caption(info,"每局结束自动换货。\n手动刷新费用逐次翻倍，\n下局结算时重置。\n\n本周期已刷新 %d 次。" % int(meta.refreshes),Vector2(20,80),Vector2(214,164),17,GameTheme.MUTED)
	var refresh := button(info,"刷新 · %d 灵感" % model.refresh_cost(),Vector2(16,290),Vector2(220,42),func() -> void: transact(model.refresh(revision)))
	refresh.name = "Refresh"
	refresh.disabled = not model.editable() or meta.inspiration < model.refresh_cost() or meta.refreshes >= model.data.progression.refresh_limit
	caption(self,"通过关卡赚取灵感，失败保留收益。购买卡片后，在「出战阵容」选择本局携带的美食。",Vector2(44,590),Vector2(1150,38),18,GameTheme.MUTED)

func build_inventory() -> void:
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.position = Vector2(40,154)
	inventory_scroll.size = Vector2(744,468)
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
		panel.custom_minimum_size = Vector2(172,220)
		var highlighted: bool = item.uid == main_uid if tab == "enhance" else item.uid in selected
		panel.add_theme_stylebox_override("panel",GameTheme.box(GameTheme.RAISED,12,GameTheme.GOLD if highlighted else (GameTheme.ACCENT if item.uid in materials else GameTheme.BORDER)))
		grid.add_child(panel)
		portrait(panel,item.id,Vector2(40,8),Vector2(92, 80))
		caption(panel,model.data.foods[item.id].title + " +%d" % int(item.level),Vector2(10,91),Vector2(152,28),17)
		caption(panel,"基础保护" if item.starter else ("已锁定" if item.locked else "可作材料"),Vector2(10,121),Vector2(152,22),13,GameTheme.MUTED)
		if tab == "loadout":
			var pick := button(panel,"已携带 ✓" if item.uid in selected else "携带",Vector2(10,160),Vector2(152,40),func() -> void: choose(item.uid),highlighted)
			pick.name = "Equip_" + item.uid
			pick.disabled = not model.editable()
		else:
			button(panel,"主卡 ✓" if item.uid == main_uid else "主卡",Vector2(8,154),Vector2(72,30),func() -> void:
				main_uid = item.uid
				materials.erase(main_uid)
				feedback = ""
				rebuild(),item.uid == main_uid)
			var material := button(panel,"材料 ✓" if item.uid in materials else "材料",Vector2(88,154),Vector2(76,30),func() -> void: select_material(item.uid),item.uid in materials)
			material.name = "Material_" + item.uid
			material.disabled = item.starter or item.locked or item.uid == main_uid or not model.editable()
			if not item.starter:
				var lock := button(panel,"解除锁定" if item.locked else "锁定保护",Vector2(8,189),Vector2(156,25),func() -> void:
					materials.erase(item.uid)
					transact(model.toggle_lock(item.uid,revision)))
				lock.disabled = not model.editable()
	inventory_scroll.set_deferred("scroll_vertical",scroll_offset)

func choose(uid: String) -> void:
	if uid in selected: selected.erase(uid)
	else:
		var item: Dictionary = MetaProgression.card(model.profile.meta,uid)
		for other: String in selected.duplicate():
			if MetaProgression.card(model.profile.meta,other).id == item.id: selected.erase(other)
		if selected.size() >= model.data.progression.loadout_limit:
			feedback = "最多携带 %d 种美食，请先取消一张" % model.data.progression.loadout_limit
			rebuild()
			return
		selected.append(uid)
	feedback = ""
	rebuild()

func select_material(uid: String) -> void:
	if uid in materials: materials.erase(uid)
	elif materials.size() < 3: materials.append(uid)
	else: feedback = "一次最多使用 3 张材料卡"
	rebuild()

func build_enhancement() -> void:
	var panel: Panel = surface(Vector2(812,154),Vector2(424,468))
	var main: Dictionary = MetaProgression.card(model.profile.meta,main_uid)
	caption(panel,"强化工作台",Vector2(24,18),Vector2(370,40),27)
	if main.is_empty():
		caption(panel,"先从左侧选择主卡，\n再选 1～3 张材料卡。\n\n材料成败均消耗；基础卡可以\n强化，但不能作为材料。",Vector2(24, 90),Vector2(368,200),20,GameTheme.MUTED)
		return
	var preview: Dictionary = model.preview(main_uid,materials)
	caption(panel,"%s  +%d → +%d" % [model.data.foods[main.id].title,int(main.level),mini(int(main.level)+1,model.data.progression.max_level)],Vector2(24, 70),Vector2(370,40),22,GameTheme.GOLD)
	var stats: Dictionary = model.data.foods[main.id].stats
	var growth: String = "生命 +%d%%" % roundi(main.level * model.data.progression.stat_per_level * 100)
	if stats.damage > 0: growth += " · 伤害 +%d%%" % roundi(main.level * model.data.progression.stat_per_level * 100)
	if stats.kind == "producer": growth += " · 产量 +%d%%" % roundi(main.level * model.data.progression.production_per_level * 100)
	caption(panel,growth,Vector2(24,116),Vector2(376,36),15,GameTheme.MUTED)
	var names: PackedStringArray = []
	for uid: String in materials:
		var item: Dictionary = MetaProgression.card(model.profile.meta,uid)
		if not item.is_empty(): names.append("%s +%d" % [model.data.foods[item.id].title,int(item.level)])
	caption(panel,"材料 %d/3\n%s" % [materials.size(),"\n".join(names)],Vector2(24,160),Vector2(370,108),18)
	caption(panel,"成功率 %.1f%%" % (preview.chance*100),Vector2(24,278),Vector2(370, 40),29,GameTheme.ACCENT)
	caption(panel,"失败主卡保持 +%d" % int(main.level) if main.level < model.data.progression.protected_target else "失败主卡降至 +%d" % (int(main.level)-1),Vector2(24,326),Vector2(370,28),18,GameTheme.DANGER if main.level >= model.data.progression.protected_target else GameTheme.MUTED)
	caption(panel,"所选材料全部消耗，结果立即保存。",Vector2(24,360),Vector2(376,26),16,GameTheme.MUTED)
	var revision: int = int(model.profile.revision)
	var enhance := button(panel,"强化" if preview.error.is_empty() else preview.error,Vector2(24,404),Vector2(376,42),func() -> void:
		var result: String = model.enhance(main_uid,materials,revision)
		if result.is_empty():
			for uid: String in materials: selected.erase(uid)
			materials.clear()
		transact(result),true)
	enhance.name = "Enhance"
	enhance.disabled = not preview.error.is_empty() or not model.editable()

func build_loadout() -> void:
	var panel: Panel = surface(Vector2(812,154),Vector2(424,468))
	caption(panel,"今夜出战",Vector2(24,18),Vector2(370, 40),27)
	caption(panel,"已选 %d / %d 种美食" % [selected.size(),model.data.progression.loadout_limit],Vector2(24,74),Vector2(370, 40),22,GameTheme.GOLD)
	var names: PackedStringArray = []
	for uid: String in selected:
		var item: Dictionary = MetaProgression.card(model.profile.meta,uid)
		if not item.is_empty(): names.append("%s  +%d" % [model.data.foods[item.id].title,int(item.level)])
	caption(panel,"\n".join(names),Vector2(24,128),Vector2(370,184),22)
	caption(panel,"同类只携带一张，至少一种能攻击。\n局内保留热量费用与放置冷却；\n用金币买食谱，每过一关赚灵感。",Vector2(24,312),Vector2(370,80),16,GameTheme.MUTED)
	var issue: String = MetaProgression.loadout_error(model.profile.meta,selected,model.data)
	var launch := button(panel,"出发，守住今夜 →",Vector2(24,404),Vector2(376,42),func() -> void: launch_requested.emit(selected.duplicate()),true)
	launch.name = "Launch"
	launch.disabled = not issue.is_empty() or not model.editable()
	launch.tooltip_text = issue
