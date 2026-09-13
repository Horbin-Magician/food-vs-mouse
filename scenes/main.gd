extends Node2D

var projection: BoardProjection = BoardProjection.new()
var art: ArtCatalog = ArtCatalog.new()
var animator: UnitAnimator = UnitAnimator.new()
const TOP_RECT := Rect2(12, -16, 1256, 100)
const FOOTER_Y := 678.0
const SHOP_RECT := Rect2(220, 82, 840, 556)
const PANEL_RECT := Rect2(974, 180, 282, 444)
const CARD_DRAG_THRESHOLD := 6.0
const FOOD_ROLES := {"bun":"蒸汽输出", "toast":"前排守卫", "pudding":"热量生产", "tea":"冰霜减速", "pepper":"近距爆发", "popcorn":"范围清群", "noodles":"穿透输出", "garlic":"相邻增益"}
var shop_overlay: Control
var shop_surface: Panel
var shop_items: HBoxContainer
var shop_refresh: Button
var modal_shade: ColorRect
var ui: Control
var start_button: Button
var pause_button: Button
var speed_button: Button
var repair_button: Button
var toggle_button: Button
var panel_style: StyleBoxFlat
var top_style: StyleBoxFlat
var run: RunController = RunController.new()
var selected: String = ""
var drag_card: String = ""
var drag_active: bool = false
var drag_origin: Vector2
var drag_phase: String
var drag_paused: bool
var drag_preview: TextureRect
var pointer: Vector2 = Vector2(-1,-1)
var move_from: Vector2i = Vector2i(-1, -1)
var shovel: bool = false:
	set(value):
		shovel = value
		if is_node_ready(): update_shovel_cursor()
var shovel_cursor: ImageTexture
var shovel_cursor_active: bool = false
var pending_remove: Vector2i
var heat_label: Label
var heat_pickup_view: HeatPickupView
var shovel_button: Button
var panel_open: bool = true
var layout_phase: String = ""
var header: Label
var cards: HBoxContainer
var panel: VBoxContainer
var confirm: ConfirmationDialog
var sound: SoundService
var inspect: Label
var feedback_text: String = ""
var feedback_remaining: float = 0.0
var restart: ConfirmationDialog
var debug_window: AcceptDialog
var debug_enabled: bool = false
var old_phase: String = ""
var old_pantry: int = 10
var old_units: int = 0

func _ready() -> void:
	panel_style = GameTheme.box(GameTheme.SURFACE, 16, GameTheme.BORDER)
	top_style = GameTheme.box(GameTheme.SURFACE, 16, GameTheme.BORDER)
	top_style.corner_radius_top_left = 0
	top_style.corner_radius_top_right = 0
	get_viewport().gui_embed_subwindows = true
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = GameTheme.create()
	add_child(ui)
	run.persistence = true
	debug_enabled = OS.is_debug_build() and "--dev" in OS.get_cmdline_user_args()
	if "--qa" in OS.get_cmdline_user_args() or "--qa-test" in OS.get_cmdline_user_args():
		run.saves.folder = "user://qa_automated/" if "--qa-test" in OS.get_cmdline_user_args() else "user://qa_visual/"
		DirAccess.make_dir_recursive_absolute(run.saves.folder)
	sound = SoundService.new()
	add_child(sound)
	RenderingServer.set_default_clear_color(GameTheme.BG)
	heat_label = label(Vector2(76, 14), 26)
	heat_label.add_theme_color_override("font_color", GameTheme.GOLD)
	header = label(Vector2(948, 674), 14)
	header.tooltip_text = "进度表示计划鼠潮的生成比例；全部生成后仍需清除剩余敌人。"
	start_button = button("开始鼠潮  →", Vector2(24, FOOTER_Y), func() -> void: run.start(); rebuild())
	start_button.custom_minimum_size = Vector2(160, 30)
	start_button.tooltip_text = "战斗中退出将回到本关开战前；准备操作自动保存。"
	GameTheme.primary(start_button)
	pause_button = button("暂停", Vector2(196, FOOTER_Y), func() -> void:
		if run.state.phase == "battle": run.paused = not run.paused)
	pause_button.custom_minimum_size = Vector2(82, 30)
	speed_button = button("1× 速度", Vector2(288, FOOTER_Y), func() -> void: run.speed = 3.0 - run.speed)
	speed_button.custom_minimum_size = Vector2(96, 30)
	repair_button = button("维修 · 4 金", Vector2(396, FOOTER_Y), func() -> void: report(run.board.repair()))
	repair_button.custom_minimum_size = Vector2(132, 30)
	toggle_button = button("收起小铺", Vector2(708, FOOTER_Y), func() -> void: set_panel_open(not panel_open))
	toggle_button.custom_minimum_size = Vector2(116, 30)
	var cursor_image: Image = preload("res://assets/ui/spatula.svg").get_image()
	cursor_image.resize(32, 32, Image.INTERPOLATE_LANCZOS)
	shovel_cursor = ImageTexture.create_from_image(cursor_image)
	shovel_button = button("", Vector2(1170, 6), func() -> void:
		shovel = not shovel
		selected = ""
		move_from = Vector2i(-1,-1))
	shovel_button.custom_minimum_size = Vector2(60, 60)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		shovel_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	shovel_button.add_theme_stylebox_override("focus", GameTheme.box(Color.TRANSPARENT, 4, GameTheme.GOLD))
	shovel_button.add_theme_color_override("icon_hover_color", GameTheme.ACCENT)
	shovel_button.add_theme_color_override("icon_pressed_color", GameTheme.GOLD)
	shovel_button.add_theme_color_override("icon_hover_pressed_color", GameTheme.GOLD)
	shovel_button.toggle_mode = true
	shovel_button.icon = preload("res://assets/ui/spatula.svg")
	shovel_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shovel_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	shovel_button.expand_icon = true
	shovel_button.add_theme_constant_override("icon_max_width", 34)
	shovel_button.tooltip_text = "选中锅铲后点击美食铲除；右键或 Esc 取消。战斗中需确认，无返还。"
	button("重新开局", Vector2(836, FOOTER_Y), func() -> void: restart.popup_centered(Vector2i(460, 190)))
	cards = HBoxContainer.new()
	cards.position = Vector2(190, 6)
	cards.add_theme_constant_override("separation", 8)
	ui.add_child(cards)
	panel = VBoxContainer.new()
	panel.position = PANEL_RECT.position + Vector2(18, 18)
	panel.size.x = 246
	panel.add_theme_constant_override("separation", 10)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(panel)
	heat_pickup_view = HeatPickupView.new()
	heat_pickup_view.run = run
	heat_pickup_view.projection = projection
	heat_pickup_view.target = heat_label
	ui.add_child(heat_pickup_view)
	modal_shade = ColorRect.new()
	modal_shade.color = Color(0.025, 0.065, 0.07, 0.72)
	modal_shade.size = Vector2(1280,720)
	modal_shade.visible = false
	ui.add_child(modal_shade)
	confirm = ConfirmationDialog.new()
	style_dialog(confirm, "移除这份美食？", "战斗中铲除不会返还热量。\n确认后，该格子将立即空出。", "确认铲除")
	confirm.confirmed.connect(func() -> void: report(run.board.remove(pending_remove.y, pending_remove.x, run.paused, true)))
	restart = ConfirmationDialog.new()
	style_dialog(restart, "重新开始今夜守卫？", "当前阵地与本局进度将结束。\n本局已达成的食谱解锁会保留。", "重新开局")
	restart.confirmed.connect(func() -> void:
		panel_open = true
		run.new_run(int(Time.get_unix_time_from_system()))
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
		feedback_remaining = 0.0
		rebuild())
	inspect = label(Vector2.ZERO, 13)
	inspect.visible = false
	inspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Give wrapping a width before the first drag/hover message is measured.
	inspect.size = Vector2(360, 0)
	inspect.add_theme_stylebox_override("normal", GameTheme.box(GameTheme.RAISED, 8, GameTheme.BORDER))
	drag_preview = TextureRect.new()
	drag_preview.size = Vector2(64, 64)
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.modulate.a = 0.7
	drag_preview.visible = false
	ui.add_child(drag_preview)
	get_window().focus_exited.connect(cancel_card_drag)
	shop_overlay = Control.new()
	shop_overlay.size = Vector2(1280, 720)
	shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.visible = false
	ui.add_child(shop_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.065, 0.07, 0.72)
	shade.size = shop_overlay.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_overlay.add_child(shade)
	shop_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("board_select"):
			shop_overlay.accept_event()
			set_panel_open(false))
	shop_surface = Panel.new()
	shop_surface.position = SHOP_RECT.position
	shop_surface.size = SHOP_RECT.size
	shop_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_surface.add_theme_stylebox_override("panel", panel_style)
	shop_overlay.add_child(shop_surface)
	ui.move_child(modal_shade, -1)
	if debug_enabled: create_debug_panel()
	run.changed.connect(rebuild)
	if not run.resume_run():
		var save_error: String = run.message
		run.new_run(int(Time.get_unix_time_from_system()))
		if not save_error.is_empty(): run.message = save_error
	rebuild()

func label(position_value: Vector2, size: int) -> Label:
	var node: Label = Label.new()
	node.position = position_value
	node.add_theme_font_size_override("font_size", size)
	ui.add_child(node)
	return node

func button(title: String, position_value: Vector2, action: Callable) -> Button:
	var node: Button = Button.new()
	node.text = title
	node.position = position_value
	node.pressed.connect(action)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ui.add_child(node)
	return node

func report(error: String) -> void:
	feedback_text = error
	feedback_remaining = 0.0 if error.is_empty() else 3.0
	run.message = "操作完成" if error.is_empty() else error
	if error.is_empty(): run.persist()
	rebuild()

func rebuild() -> void:
	if cards == null: return
	cancel_card_drag()
	for child: Node in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	for child: Node in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	if layout_phase != run.state.phase:
		panel_open = run.state.phase != "battle"
		layout_phase = run.state.phase
	panel_label({"prepare":"打烊小铺", "battle":"本局食谱", "won":"今夜，守住了", "lost":"明晚，再来"}.get(run.state.phase,""), 24, GameTheme.TEXT)
	panel_label({"prepare":"购买美食与灵感食谱，为下一波做准备", "battle":"已获得的加成持续生效", "won":"八关告捷 · 食堂安然无恙", "lost":"粮仓失守 · 换个阵容再试试"}.get(run.state.phase,""), 13, GameTheme.MUTED)
	if run.state.phase == "prepare":
		build_shop()
	if run.state.phase in ["won","lost"]:
		panel_label("今 夜 战 报", 13, GameTheme.GOLD)
		for line: String in ["守卫时长        %.1f 分钟" % (run.state.elapsed/60.0), "击退鼠群        %d" % run.state.metrics.kills, "粮仓损失        %d" % run.state.metrics.leaks, "美食阵亡        %d" % run.state.metrics.deaths]:
			panel_label(line, 18, GameTheme.TEXT)
		var again: Button = panel_button("再守一夜  →",func() -> void: restart.popup_centered(Vector2i(460,190)))
		GameTheme.primary(again)
	var owned: Label = panel_label("已购食谱 %02d  ·  悬停查看" % run.state.recipes.size(), 13, GameTheme.MUTED)
	owned.mouse_filter = Control.MOUSE_FILTER_STOP
	owned.tooltip_text = "尚未购买食谱；在小铺用金币购买。" if run.state.recipes.is_empty() else "本局食谱\n"
	for id: String in run.state.recipes: owned.tooltip_text += run.data.recipes[id].title + " · " + run.data.recipes[id].stats.description + "\n"
	for id: String in run.state.cards:
		var node: Button = Button.new()
		var stats: Dictionary = run.data.foods[id].stats
		node.custom_minimum_size = Vector2(72, 76)
		GameTheme.food_card(node)
		var affordability := ShaderMaterial.new()
		affordability.shader = preload("res://scripts/ui/card_affordability.gdshader")
		node.material = affordability
		node.toggle_mode = true
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = art.food_portrait(id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.name = "Portrait"
		portrait.position = Vector2(12,8)
		portrait.size = Vector2(48,43)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(portrait)
		var badge := TextureRect.new()
		badge.name = "UpgradeStar"
		badge.texture = preload("res://assets/ui/upgrade_star.svg")
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.position = Vector2(48, 0)
		badge.size = Vector2(24, 24)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(badge)
		var level := card_label(badge, str(run.state.star(id)), Vector2(0, 5), Vector2(24, 16), 11, Color("#fff7ec"))
		level.name = "Level"
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var flame := TextureRect.new()
		flame.texture = preload("res://assets/ui/flame.svg")
		flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flame.position = Vector2(12, 58)
		flame.size = Vector2(10, 11)
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(flame)
		var cost: Label = card_label(node, str(stats.cost), Vector2(24,55), Vector2(36,18), 14, Color("#304447"))
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.name = "Cost"
		# Share only within this card; cooldown and selection retain their own colors.
		for content: Control in node.get_children():
			content.material = affordability
			for detail: Control in content.get_children():
				detail.material = affordability
		var cooldown: ColorRect = ColorRect.new()
		cooldown.color = Color(0.02, 0.05, 0.06, 0.62)
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown.name = "Cooldown"
		var mask_material := ShaderMaterial.new()
		mask_material.shader = preload("res://scripts/ui/card_cooldown.gdshader")
		cooldown.material = mask_material
		node.add_child(cooldown)
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var selection := Panel.new()
		selection.name = "Selection"
		selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var selection_style := GameTheme.box(Color.TRANSPARENT, 6, GameTheme.GOLD)
		selection_style.set_border_width_all(2)
		selection.add_theme_stylebox_override("panel", selection_style)
		selection.visible = false
		node.add_child(selection)
		selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.tooltip_text = "%s · %s\n生命 %.0f · 伤害 %.0f\n间隔 %.2f 秒 · 射程 %.1f 格\n放置冷却 %.0f 秒 · 持有 %d/6 张 · 累计 3/6 张升星" % [run.data.foods[id].title, FOOD_ROLES.get(id,"美食"), run.board.max_hp(id), stats.damage * run.data.rules.star_hp[run.state.star(id) - 1], stats.interval, run.recipes.reach(id), stats.cooldown, run.state.cards[id]]
		node.set_meta("details", node.tooltip_text)
		node.gui_input.connect(func(event: InputEvent) -> void:
			if event.is_action_pressed("board_select"): begin_card_drag(id))
		cards.add_child(node)
	cards.position.x = 190 + (922 - (run.state.cards.size() * 80 - 8)) * 0.5
	sync_panel_visibility()

func set_panel_open(value: bool) -> void:
	panel_open = value
	sync_panel_visibility()
	if not value: toggle_button.grab_focus()

func sync_panel_visibility() -> void:
	panel.visible = panel_open and run.state.phase != "prepare"
	var show_shop: bool = panel_open and run.state.phase == "prepare"
	if show_shop:
		cancel_card_drag()
		selected = ""
		shovel = false
		move_from = Vector2i(-1, -1)
	var was_visible: bool = shop_overlay.visible
	shop_overlay.visible = show_shop
	if show_shop and not was_visible:
		shop_surface.get_node("Close").grab_focus()

func shop_button(title: String, pos: Vector2, bounds: Vector2, action: Callable) -> Button:
	var node := Button.new()
	node.text = title
	node.position = pos
	node.custom_minimum_size = bounds
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	shop_surface.add_child(node)
	return node

func build_shop() -> void:
	for child: Node in shop_surface.get_children():
		shop_surface.remove_child(child)
		child.queue_free()
	card_label(shop_surface, "打烊小铺", Vector2(24, 20), Vector2(380, 36), 26, GameTheme.TEXT)
	card_label(shop_surface, "购买美食与灵感食谱，为下一波做准备", Vector2(24, 61), Vector2(400, 22), 14, GameTheme.MUTED)
	card_label(shop_surface, "金币  %d" % run.state.coins, Vector2(576, 28), Vector2(140, 28), 20, GameTheme.GOLD)
	var close := shop_button("关闭 ×", Vector2(724, 24), Vector2(92, 36), func() -> void: set_panel_open(false))
	close.name = "Close"
	close.tooltip_text = "关闭小铺，继续布阵；也可按 Esc 或右键。"
	shop_items = HBoxContainer.new()
	shop_items.position = Vector2(24, 96)
	shop_items.size = Vector2(792, 222)
	shop_items.add_theme_constant_override("separation", 12)
	shop_surface.add_child(shop_items)
	var focus_buttons: Array[Button] = [close]
	for index: int in range(run.state.offers.size()):
		var offer: Dictionary = run.state.offers[index]
		var count: int = run.state.cards.get(offer.id, 0)
		var sold: bool = offer.id.is_empty() or offer.bought or count >= 6
		var item := Button.new()
		item.custom_minimum_size = Vector2(256, 222)
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item.disabled = sold or run.state.coins < run.data.foods[offer.id].stats.price
		item.pressed.connect(func() -> void: report(run.shop.buy(index)))
		shop_items.add_child(item)
		focus_buttons.append(item)
		if offer.id.is_empty():
			item.text = "已收集全部美食"
			continue
		var portrait := TextureRect.new()
		portrait.texture = art.food(offer.id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(76, 8)
		portrait.size = Vector2(104, 100)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if item.disabled: portrait.modulate.a = 0.45
		item.add_child(portrait)
		var title := card_label(item, run.data.foods[offer.id].title, Vector2(16, 110), Vector2(224, 28), 20, GameTheme.MUTED if sold else GameTheme.TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var details := card_label(item, "%s · %s" % [FOOD_ROLES.get(offer.id, "美食"), "解锁新美食" if count == 0 else "持有 %d/6" % count], Vector2(12, 146), Vector2(232, 22), 13, GameTheme.MUTED)
		details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var price: String = "已满星" if count >= 6 else ("已售罄" if sold else "%d 金 · %s" % [run.data.foods[offer.id].stats.price, "金币不足" if item.disabled else "购买"])
		var price_label := card_label(item, price, Vector2(16, 183), Vector2(224, 26), 16, GameTheme.MUTED if item.disabled else GameTheme.GOLD)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.tooltip_text = price if item.disabled else "购买后自动解锁或累积升星进度；累计 3 张二星，6 张三星。"
	card_label(shop_surface, "灵感食谱 · 每张 %d 金 · 购买后整局生效" % run.data.rules.recipe_price, Vector2(24, 327), Vector2(760, 24), 15, GameTheme.GOLD)
	if run.state.choices.is_empty():
		card_label(shop_surface, "暂无可购食谱 · 可刷新或继续开战", Vector2(24, 379), Vector2(760, 26), 16, GameTheme.MUTED)
	for index: int in range(run.state.choices.size()):
		var id: String = run.state.choices[index]
		var item := shop_button("", Vector2(24 + index * 268, 361), Vector2(256, 90), func() -> void: report(run.shop.buy_recipe(id)))
		item.custom_minimum_size = Vector2(256, 90)
		item.name = "Recipe_" + id
		item.disabled = run.state.coins < run.data.rules.recipe_price
		item.tooltip_text = run.data.recipes[id].stats.description
		row_content(item, art.recipe(id), run.data.recipes[id].title, "%d 金 · %s" % [run.data.rules.recipe_price, "金币不足" if item.disabled else "购买食谱"])
		focus_buttons.append(item)
	var feedback := card_label(shop_surface, run.message, Vector2(24, 465), Vector2(792, 22), 13, GameTheme.ACCENT)
	feedback.clip_text = true
	feedback.tooltip_text = run.message
	shop_refresh = shop_button("刷新 · %d 金    %d/%d" % [run.data.rules.refresh_cost, run.state.refreshes, run.data.rules.refresh_limit], Vector2(24, 500), Vector2(240, 36), func() -> void: report(run.shop.refresh()))
	shop_refresh.disabled = run.state.refreshes >= run.data.rules.refresh_limit or run.state.coins < run.data.rules.refresh_cost
	shop_refresh.tooltip_text = "刷新次数已用完" if run.state.refreshes >= run.data.rules.refresh_limit else ("金币不足" if shop_refresh.disabled else "更换美食与食谱商品，消耗 %d 金币" % run.data.rules.refresh_cost)
	var owned := card_label(shop_surface, "已购食谱 %02d · 悬停查看" % run.state.recipes.size(), Vector2(288, 507), Vector2(280, 24), 13, GameTheme.MUTED)
	owned.mouse_filter = Control.MOUSE_FILTER_STOP
	owned.tooltip_text = "尚未购买食谱；在小铺用金币购买。" if run.state.recipes.is_empty() else "本局食谱\n"
	for id: String in run.state.recipes: owned.tooltip_text += run.data.recipes[id].title + " · " + run.data.recipes[id].stats.description + "\n"
	var done := shop_button("完成购物  →", Vector2(620, 500), Vector2(196, 36), func() -> void: set_panel_open(false))
	GameTheme.primary(done)
	focus_buttons.append_array([shop_refresh, done])
	# Keep keyboard focus within the modal, including after a purchase rebuild.
	var enabled: Array[Button] = []
	for node: Button in focus_buttons:
		if not node.disabled: enabled.append(node)
	for index: int in range(enabled.size()):
		enabled[index].focus_next = enabled[index].get_path_to(enabled[(index + 1) % enabled.size()])
		enabled[index].focus_previous = enabled[index].get_path_to(enabled[(index - 1 + enabled.size()) % enabled.size()])
	if shop_overlay.visible: close.grab_focus()

func style_dialog(dialog: ConfirmationDialog, title_text: String, body: String, action: String) -> void:
	dialog.title = title_text
	dialog.transparent_bg = true
	dialog.dialog_text = body
	dialog.theme = ui.theme
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dialog.min_size = Vector2i(460,190)
	dialog.ok_button_text = action
	dialog.cancel_button_text = "取消"
	ui.add_child(dialog)
	dialog.visibility_changed.connect(update_shovel_cursor)
	dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.get_label().add_theme_font_size_override("font_size", 16)
	GameTheme.primary(dialog.get_ok_button())

func card_label(parent: Control, text: String, pos: Vector2, bounds: Vector2, font_size: int, color: Color, wrap: bool = false) -> Label:
	var caption := Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	caption.text = text
	caption.position = pos
	caption.size = bounds
	caption.add_theme_font_size_override("font_size", font_size)
	caption.add_theme_color_override("font_color", color)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(caption)
	return caption

func panel_label(text: String, font_size: int, color: Color) -> Label:
	var caption := Label.new()
	caption.text = text
	caption.add_theme_font_size_override("font_size", font_size)
	caption.add_theme_color_override("font_color", color)
	panel.add_child(caption)
	return caption

func row_content(node: Button, texture: Texture2D, title: String, description: String, price: String = "") -> void:
	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(10, 10)
	portrait.size = Vector2(38, 24)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(portrait)
	card_label(node, title, Vector2(56,10), Vector2(134,24), 16, GameTheme.MUTED if node.disabled else GameTheme.TEXT)
	if not price.is_empty():
		card_label(node, price, Vector2(191,12), Vector2(48,22), 13, GameTheme.MUTED if node.disabled else GameTheme.GOLD)
	card_label(node, description, Vector2(12,48), Vector2(222,node.custom_minimum_size.y - 54), 12, GameTheme.MUTED, true)
	if node.disabled: portrait.modulate.a = 0.45

func _process(delta: float) -> void:
	animator.bind(run, projection)
	var before: float = run.state.elapsed
	run.advance(delta)
	if not drag_card.is_empty() and (run.state.phase != drag_phase or run.paused != drag_paused or placement_modal_visible()):
		cancel_card_drag()
	drag_preview.visible = drag_active
	drag_preview.position = pointer - Vector2(32, 54)
	var visual_delta: float = 0.0
	if not run.paused:
		visual_delta = run.state.elapsed - before if run.state.phase == "battle" else (minf(delta, 0.25) if run.state.phase == "prepare" else 0.0)
	animator.advance(visual_delta, run.combat.enemies)
	heat_label.text = "%03d" % run.state.heat
	heat_label.tooltip_text = "每关上限 %.0f；每秒恢复 %.0f，准备阶段不恢复。\n点击布丁冒出的火苗，飞入此处后获得热量。" % [run.data.rules.heat_cap, run.data.rules.heat_rate]
	heat_pickup_view.queue_redraw()
	header.text = wave_status()
	update_controls()
	if run.state.phase != old_phase and run.state.phase in ["prepare","won"]: sound.cue("clear")
	if run.state.pantry < old_pantry: sound.cue("danger")
	if run.state.units.size() > old_units: sound.cue("place")
	old_phase = run.state.phase
	old_pantry = run.state.pantry
	old_units = run.state.units.size()
	feedback_remaining = maxf(0.0, feedback_remaining - delta)
	update_inspector()
	queue_redraw()

func wave_progress() -> float:
	if run.state.phase == "prepare": return 0.0
	if run.state.phase == "won": return 1.0
	return clampf(float(run.director.cursor) / maxi(1, run.director.events.size()), 0.0, 1.0)

func wave_status() -> String:
	var status: String = {"prepare":"等待开战", "won":"守卫成功", "lost":"粮仓失守"}.get(run.state.phase, "")
	if run.state.phase == "battle":
		status = "清理余鼠 %d" % run.combat.enemies.size() if wave_progress() >= 1.0 else "鼠潮 %d%% · 余鼠 %d" % [roundi(wave_progress() * 100), run.combat.enemies.size()]
		if run.paused: status = "暂停 · " + status
	return "第 %02d / 08 关 · %s" % [run.state.wave, status]

func draw_wave_progress() -> void:
	var bar := Rect2(948, 705, 300, 5)
	draw_style_box(GameTheme.box(GameTheme.RAISED, 3), bar)
	var fill_width: float = bar.size.x * wave_progress()
	if fill_width > 0:
		draw_style_box(GameTheme.box(GameTheme.DANGER if run.state.phase == "lost" else GameTheme.ACCENT, 3), Rect2(bar.position, Vector2(fill_width,bar.size.y)))
	for index: int in range(1,8):
		var x: float = bar.position.x + bar.size.x * index / 8.0
		draw_line(Vector2(x,bar.position.y),Vector2(x,bar.end.y),GameTheme.BG,2)
	draw_circle(Vector2(bar.end.x,bar.position.y+2.5),4,GameTheme.GOLD)

func update_controls() -> void:
	var phase: String = run.state.phase
	sync_panel_visibility()
	modal_shade.visible = confirm.visible or restart.visible
	start_button.disabled = phase != "prepare"
	start_button.text = "开始鼠潮  →" if phase == "prepare" else {"battle":"守卫进行中", "won":"守卫完成", "lost":"守卫结束"}.get(phase, "")
	pause_button.disabled = phase != "battle"
	pause_button.text = "继续" if run.paused else "暂停"
	pause_button.tooltip_text = "暂停时可查看信息，不能执行战斗操作。"
	speed_button.text = "%.0f× 速度" % run.speed
	repair_button.disabled = phase != "prepare" or run.state.repaired or run.state.coins < run.data.rules.repair_cost
	repair_button.text = "本关已维修" if run.state.repaired else "维修 · %d 金" % run.data.rules.repair_cost
	repair_button.tooltip_text = "仅准备阶段可用" if phase != "prepare" else ("本关维修次数已用完" if run.state.repaired else ("金币不足" if run.state.coins < run.data.rules.repair_cost else "恢复场上美食 30% 最大生命；每个准备阶段一次。"))
	var panel_name: String = {"prepare":"小铺", "battle":"食谱", "won":"战报", "lost":"战报"}.get(phase, "面板")
	toggle_button.text = ("收起" if panel_open else "打开") + panel_name
	shovel_button.disabled = phase not in ["prepare", "battle"] or run.paused
	if phase not in ["prepare", "battle"]: shovel = false
	shovel_button.set_pressed_no_signal(shovel)
	update_shovel_cursor()
	for index: int in range(cards.get_child_count()):
		var id: String = run.state.cards.keys()[index]
		var card: Button = cards.get_child(index)
		card.set_pressed_no_signal(id == selected)
		card.get_node("Selection").visible = id == selected
		var remaining: float = run.state.cooldowns.get(id,0.0)
		card.tooltip_text = "" if drag_active else "%s\n%s\n按住拖到格子放置 · 右键 / Esc 取消" % [card.get_meta("details"), card_status(id)]
		card.material.set_shader_parameter("unaffordable", run.state.heat < run.data.foods[id].stats.cost)
		var cooldown: ColorRect = card.get_node("Cooldown")
		var duration: float = run.data.foods[id].stats.cooldown
		var ratio: float = clampf(remaining / duration, 0, 1) if duration > 0 else 0.0
		cooldown.visible = phase == "battle" and ratio > 0
		cooldown.material.set_shader_parameter("remaining_ratio", ratio)
		cooldown.material.set_shader_parameter("card_size", card.size)

func update_shovel_cursor() -> void:
	if confirm == null or restart == null or shop_overlay == null: return
	var active: bool = shovel and run.state.phase in ["prepare", "battle"] and not run.paused and not confirm.visible and not restart.visible and not shop_overlay.visible
	if active == shovel_cursor_active: return
	shovel_cursor_active = active
	# Controls request the hand cursor; replace both shapes while the tool is active.
	for shape: Input.CursorShape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(shovel_cursor if active else null, shape, Vector2(20, 5) if active else Vector2.ZERO)

func _exit_tree() -> void:
	if not shovel_cursor_active: return
	for shape: Input.CursorShape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(null, shape)
	shovel_cursor_active = false

func card_status(id: String) -> String:
	if run.state.phase == "prepare": return "准备阶段仅可调整已有美食，开战后可放置新美食"
	if run.state.phase in ["won", "lost"]: return "本局已结束"
	if run.state.phase != "battle": return "等待下一关"
	if run.paused: return "已暂停"
	var remaining: float = run.state.cooldowns.get(id,0.0)
	if remaining > 0: return "冷却 %.1f 秒" % remaining
	if run.state.heat < run.data.foods[id].stats.cost: return "热量不足"
	return "已选中 · 可放置" if selected == id else "可放置"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		cancel_card_drag()
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
	if debug_enabled and event.is_action_pressed("debug_panel"): debug_window.popup_centered()
	if event.is_action_pressed("board_select"):
		if confirm.visible or restart.visible or shop_overlay.visible: return
		if panel.visible and PANEL_RECT.has_point(event.position): return
		var pickup_uid: int = heat_pickup_view.pickup_at(event.position)
		if pickup_uid >= 0:
			report(run.collect_heat(pickup_uid))
			get_viewport().set_input_as_handled()
			return
		var cell: Vector2i = projection.cell_at(event.position)
		var col: int = cell.x
		var row: int = cell.y
		if col < 0 or col >= RunState.COLS or row < 0 or row >= RunState.ROWS: return
		if shovel:
			if run.state.phase == "battle" and not run.paused:
				pending_remove = Vector2i(col,row)
				confirm.popup_centered(Vector2i(460,190))
			else: report(run.board.remove(row,col,run.paused,true))
		elif run.state.phase == "prepare":
			if move_from.x < 0: move_from = Vector2i(col,row)
			else:
				report(run.board.move(move_from.y,move_from.x,row,col))
				move_from = Vector2i(-1,-1)
		elif not selected.is_empty(): report(run.board.place(selected,row,col,run.paused))

func text_at(position_value: Vector2, title: String, color: Color = Color.WHITE, size: int = 16) -> void:
	draw_string(ThemeDB.fallback_font, position_value, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if run.state == null: return
	draw_kitchen()
	draw_board()
	var hovered: Dictionary = hovered_unit()
	if not hovered.is_empty():
		var start_x: float = hovered.col * 96 + 48
		var reach: float = minf(run.recipes.reach(hovered.id) * 96, RunState.BOARD_WIDTH - start_x)
		draw_colored_polygon(projection.polygon(Rect2(start_x, hovered.row * 96, reach, 96)), Color(0.5, 0.85, 0.9, 0.14))
	# Draw each lane back to front; all objects share the same projected ground.
	for row: int in range(RunState.ROWS):
		for unit: Dictionary in run.state.units:
			if unit.row == row: draw_food(unit)
		for enemy: Dictionary in run.combat.enemies:
			if enemy.row == row: draw_mouse(enemy)
		for shot: Dictionary in run.combat.projectiles:
			if shot.row == row:
				var pos: Vector2 = projection.foot(shot.x, row) - Vector2(0, 27 * projection.depth_scale(row))
				draw_circle(pos, 5 * projection.depth_scale(row), Color("fff1b5"))
	if run.state.phase == "battle":
		for i: int in range(run.director.cursor,mini(run.director.cursor + 3,run.director.events.size())):
			var event: Dictionary = run.director.events[i]
			if event.time - run.director.elapsed <= 5:
				text_at(projection.foot(RunState.BOARD_WIDTH + 7, event.row) + Vector2(0, -8),"◀",Color("ffbe75"), 20)
	draw_style_box(top_style, TOP_RECT)
	draw_texture_rect(preload("res://assets/ui/flame.svg"), Rect2(38, 14, 26, 30), false)
	text_at(Vector2(38, 61), "粮仓 %d/10   金 %d" % [run.state.pantry,run.state.coins], GameTheme.TEXT, 13)
	draw_line(Vector2(178,12),Vector2(178,60),GameTheme.BORDER)
	text_at(Vector2(554, 698), "右键 / Esc  取消选择", GameTheme.MUTED, 12)
	if panel.visible: draw_style_box(panel_style, PANEL_RECT)
	draw_wave_progress()
	if drag_active:
		var cell: Vector2i = projection.cell_at(pointer)
		if cell.x >= 0:
			var tile: PackedVector2Array = projection.tiles[cell.y * RunState.COLS + cell.x]
			var tint: Color = GameTheme.ACCENT if drag_placement_error().is_empty() else GameTheme.DANGER
			draw_colored_polygon(tile, Color(tint, 0.28))
			outline(tile, tint, 3.0)

func draw_kitchen() -> void:
	draw_rect(Rect2(0,0,1280,720), GameTheme.BG)
	draw_style_box(GameTheme.box(Color("0b1719"), 16), Rect2(BoardProjection.ORIGIN - Vector2(12, 6), BoardProjection.CANVAS_SIZE + Vector2(24, 18)))
	draw_style_box(GameTheme.box(Color("51625a"), 12), Rect2(BoardProjection.ORIGIN - Vector2(8, 8), BoardProjection.CANVAS_SIZE + Vector2(16, 16)))
	for row: int in range(RunState.ROWS):
		var center: Vector2 = projection.foot(-48,row) - Vector2(0,16)
		draw_circle(center,14,GameTheme.RAISED)
		text_at(center + Vector2(-4,5),str(row+1),GameTheme.MUTED,12)
		var entry: Vector2 = projection.foot(RunState.BOARD_WIDTH + 44,row) - Vector2(3,16)
		draw_line(entry + Vector2(-3,-5),entry + Vector2(-8,0),GameTheme.BORDER,2,true)
		draw_line(entry + Vector2(-8,0),entry + Vector2(-3,5),GameTheme.BORDER,2,true)

func outline(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func draw_board() -> void:
	var edge: PackedVector2Array = projection.polygon(Rect2(Vector2.ZERO, BoardProjection.LOGICAL_SIZE))
	var front: PackedVector2Array = PackedVector2Array([edge[3], edge[2], edge[2] + Vector2(0, 8), edge[3] + Vector2(0, 8)])
	draw_colored_polygon(front, Color("102a29"))
	draw_colored_polygon(edge, Color("697b6e"))
	outline(edge, Color("b7c4a755"), 1.5)
	var hover_cell: Vector2i = projection.cell_at(pointer)
	for row: int in range(RunState.ROWS):
		for col: int in range(RunState.COLS):
			var tile: PackedVector2Array = projection.tiles[row * RunState.COLS + col]
			draw_colored_polygon(tile, Color("c6cbb0") if (row + col) % 2 == 0 else Color("b6c2a8"))
			outline(tile, Color("e8ecce30"))
			if move_from == Vector2i(col, row):
				draw_colored_polygon(tile, Color("e7c07630"))
				outline(tile, Color("f8d482"), 2.0)
			elif hover_cell == Vector2i(col, row):
				draw_colored_polygon(tile, Color("9cdbc328"))
				outline(tile, Color("b4ded2"), 1.5)

func draw_food(unit: Dictionary) -> void:
	var scale_value: float = projection.depth_scale(unit.row)
	var foot: Vector2 = projection.foot(unit.col * 96 + 48, unit.row)
	var pose: Dictionary = animator.pose(unit, foot)
	foot = pose.foot
	draw_actor(art.food(unit.id), foot, Vector2(66, 76) * scale_value, unit.flash > 0, pose, scale_value)
	var fraction: float = unit.hp / run.board.max_hp(unit.id)
	draw_rect(Rect2(foot + Vector2(-28, 4) * scale_value, Vector2(56, 4) * scale_value), Color("633f46"))
	draw_rect(Rect2(foot + Vector2(-28, 4) * scale_value, Vector2(56 * fraction, 4) * scale_value), Color("ff817d") if fraction < 0.25 else Color("7fd29b"))

func draw_mouse(enemy: Dictionary) -> void:
	var scale_value: float = projection.depth_scale(enemy.row)
	var foot: Vector2 = projection.foot(enemy.x, enemy.row)
	var size: Vector2 = Vector2(58, 72)
	if enemy.id == "elite": size = Vector2(68, 82)
	if enemy.id == "boss": size = Vector2(82, 98)
	var pose: Dictionary = animator.pose(enemy, foot)
	draw_actor(art.mouse(enemy.id), foot, size * scale_value, enemy.flash > 0, pose, scale_value)
	var status_pos: Vector2 = foot - Vector2(22, size.y * 0.8) * scale_value
	if enemy.slow_time > 0: text_at(status_pos,"❄",Color("83e4f5"))
	if enemy.burn_time > 0: text_at(status_pos + Vector2(29, 0),"♨",Color("ffab69"))
	if enemy.id in ["boss", "elite"]: text_at(status_pos + Vector2(0, -14),run.data.enemies[enemy.id].title,Color("ffe1a1"),12)
	draw_rect(Rect2(foot + Vector2(-23, 4) * scale_value,Vector2(46 * enemy.hp / enemy.max_hp, 4) * scale_value),Color("ed8796"))

func draw_actor(texture: Texture2D, foot: Vector2, size: Vector2, hit: bool, pose: Dictionary, depth: float) -> void:
	if texture == null: return
	draw_set_transform(pose.shadow + Vector2(4, 0), -0.04, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, size.x * 0.34, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(foot + pose.offset * depth, pose.angle, pose.scale)
	draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y * 0.86), size), false, Color(1.7, 1.7, 1.7) if hit else Color.WHITE)
	draw_set_transform(Vector2.ZERO)

func panel_button(title: String, action: Callable, tip: String = "") -> Button:
	var node: Button = Button.new()
	node.text = title
	node.tooltip_text = tip
	node.custom_minimum_size = Vector2(246,36)
	node.pressed.connect(action)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(node)
	return node

func hovered_unit() -> Dictionary:
	if drag_active: return {}
	if shop_overlay.visible: return {}
	if panel.visible and PANEL_RECT.has_point(pointer): return {}
	var cell: Vector2i = projection.cell_at(pointer)
	if cell.x < 0: return {}
	return run.board.at(cell.y, cell.x)

func update_inspector() -> void:
	var unit: Dictionary = hovered_unit()
	inspect.text = ""
	if drag_active:
		var error: String = drag_placement_error()
		inspect.text = "松手放置 · 右键 / Esc 取消" if error.is_empty() else error
	elif feedback_remaining > 0:
		inspect.text = feedback_text
	elif heat_pickup_view.pickup_at(pointer) >= 0:
		inspect.text = "暂停中 · 恢复后点击火苗收取热量" if run.paused else "点击火苗 · 飞入左上角后获得热量"
	elif not unit.is_empty():
		inspect.text = "%s ★%d   生命 %.0f / %.0f\n伤害 %.1f · 间隔 %.2f秒 · 射程 %.1f格%s" % [run.data.foods[unit.id].title,run.state.star(unit.id),unit.hp,run.board.max_hp(unit.id),run.recipes.damage(unit),run.recipes.interval(unit),run.recipes.reach(unit.id)," · 面粉影响" if unit.flour > 0 else ""]
	elif debug_enabled and run.state.phase == "battle":
		inspect.text = "F3 开发面板 · 各行压力"
		for row: int in range(RunState.ROWS):
			var pressure: float = 0.0
			for enemy: Dictionary in run.combat.enemies:
				if enemy.row == row: pressure += enemy.hp
			inspect.text += " %d:%.0f" % [row+1,pressure]
	inspect.visible = not inspect.text.is_empty() and not shop_overlay.visible and not confirm.visible and not restart.visible
	inspect.size = Vector2(360, 0)
	inspect.position = Vector2(clampf(pointer.x + 16, 12, 908), clampf(pointer.y + 20, 180, 720 - inspect.size.y - 12))


func create_debug_panel() -> void:
	debug_window = AcceptDialog.new()
	debug_window.title = "开发工具（发行版禁用）"
	var box: VBoxContainer = VBoxContainer.new()
	var seed_input: LineEdit = LineEdit.new()
	seed_input.placeholder_text = "固定种子，例如 42"
	box.add_child(seed_input)
	var seed_button: Button = Button.new()
	seed_button.text = "以指定种子重开"
	seed_button.pressed.connect(func() -> void:
		if seed_input.text.is_valid_int(): run.new_run(int(seed_input.text)); rebuild())
	box.add_child(seed_button)
	var wave_input: SpinBox = SpinBox.new()
	wave_input.min_value = 1
	wave_input.max_value = 8
	box.add_child(wave_input)
	var wave_button: Button = Button.new()
	wave_button.text = "准备阶段切换关卡"
	wave_button.pressed.connect(func() -> void:
		if run.state.phase == "prepare": run.state.wave = int(wave_input.value); run.persist(); rebuild())
	box.add_child(wave_button)
	var money: Button = Button.new()
	money.text = "增加 50 金币 / 补满热量"
	money.pressed.connect(func() -> void:
		if not run.paused:
			run.state.coins += 50
			run.state.heat = run.data.rules.heat_cap
			run.persist()
			rebuild())
	box.add_child(money)
	debug_window.add_child(box)
	ui.add_child(debug_window)

func placement_modal_visible() -> bool:
	return shop_overlay.visible or confirm.visible or restart.visible or (debug_window != null and debug_window.visible)

func begin_card_drag(id: String) -> void:
	if placement_modal_visible(): return
	cancel_card_drag()
	selected = id
	shovel = false
	move_from = Vector2i(-1, -1)
	drag_card = id
	drag_origin = pointer
	drag_phase = run.state.phase
	drag_paused = run.paused
	drag_preview.texture = art.food(id)
	feedback_remaining = 0.0

func cancel_card_drag() -> void:
	if not drag_card.is_empty(): selected = ""
	drag_card = ""
	drag_active = false
	if drag_preview != null: drag_preview.visible = false

func drag_placement_error() -> String:
	var cell: Vector2i = projection.cell_at(pointer)
	if cell.x < 0 or (panel.visible and PANEL_RECT.has_point(pointer)):
		return "移到棋盘格子 · 在此松手取消"
	return run.board.placement_error(drag_card, cell.y, cell.x, run.paused)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: pointer = event.position
	if not drag_card.is_empty():
		if event.is_action_pressed("cancel_selection") or placement_modal_visible() or run.state.phase != drag_phase or run.paused != drag_paused:
			cancel_card_drag()
		elif event is InputEventMouseMotion:
			if pointer.distance_to(drag_origin) >= CARD_DRAG_THRESHOLD: drag_active = true
		elif event.is_action_released("board_select"):
			if drag_active:
				var id: String = drag_card
				var cell: Vector2i = projection.cell_at(pointer)
				cancel_card_drag()
				get_viewport().set_input_as_handled()
				if cell.x >= 0 and not (panel.visible and PANEL_RECT.has_point(pointer)):
					report(run.board.place(id, cell.y, cell.x, run.paused))
			else:
				# A click keeps selection; only a completed drag clears it.
				drag_card = ""
	if shop_overlay.visible and not confirm.visible and not restart.visible:
		if event.is_action_pressed("cancel_selection"):
			set_panel_open(false)
			get_viewport().set_input_as_handled()
			return
