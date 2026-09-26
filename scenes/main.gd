extends Node2D

var projection: BoardProjection = BoardProjection.new()
var art: ArtCatalog = ArtCatalog.new()
var animator: UnitAnimator = UnitAnimator.new()
var battle_art: BattleArt = BattleArt.new()
var shovel_feedback: ShovelFeedback = ShovelFeedback.new()
var damage_feedback: DamageFeedback = DamageFeedback.new()
var status_feedback: StatusFeedback = StatusFeedback.new()
const TOP_RECT := Rect2(12, -16, 1256, 100)
const SHOP_RECT := Rect2(220, 82, 840, 556)
const PANEL_RECT := Rect2(974, 180, 282, 444)
const CARD_DRAG_THRESHOLD := 6.0
const FOOD_ROLES := {"bun":"蒸汽输出", "toast":"前排守卫", "pudding":"热量生产", "tea":"冰霜减速", "pepper":"近距爆发", "popcorn":"范围清群", "noodles":"穿透输出", "garlic":"相邻增益"}
var shop_overlay: Control
var shop_surface: Panel
var shop_items: HBoxContainer
var shop_refresh: Button
var save_retry_overlay: Control
var save_retry_message: Label
var ui: Control
var settings_button: Button
var speed_button: Button
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
		if shovel_button != null: shovel_button.set_pressed_no_signal(value)
		if is_node_ready(): update_shovel_cursor()
var shovel_cursor: TextureRect
var shovel_cursor_active: bool = false
var pointer_in_window: bool = true
var window_focused: bool = true
var heat_label: Label
var heat_pickup_view: HeatPickupView
var inspiration_label: Label
var first_clear_inspiration: int = 0
var inspiration_pickup_view: InspirationPickupView
var shovel_button: Button
var panel_open: bool = true
var layout_phase: String = ""
var header: Label
var operation_hint: Label
var recipe_hint: Label
var cards: HBoxContainer
var panel: VBoxContainer
var sound: SoundService
var audio_settings: AudioSettings
var inspect: Label
var feedback_text: String = ""
var feedback_remaining: float = 0.0
var debug_window: AcceptDialog
var debug_enabled: bool = false
var quitting: bool = false

func _ready() -> void:
	# Own the node before the first frame: menus can release this scene immediately.
	add_child(damage_feedback)
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
	if run.state == null and ("--qa" in OS.get_cmdline_user_args() or "--qa-test" in OS.get_cmdline_user_args()):
		run.saves.folder = "user://qa_automated/" if "--qa-test" in OS.get_cmdline_user_args() else "user://qa_visual/"
		DirAccess.make_dir_recursive_absolute(run.saves.folder)
	if sound == null:
		sound = SoundService.new()
		sound.settings_path = run.saves.folder.path_join("audio.cfg")
		add_child(sound)
		audio_settings = AudioSettings.new()
		add_child(audio_settings)
		audio_settings.setup(sound)
		audio_settings.menu_requested.connect(func() -> void: leave_settings("menu"))
		audio_settings.quit_requested.connect(func() -> void: leave_settings("quit"))
	var settings_layer := CanvasLayer.new()
	settings_layer.layer = 110
	add_child(settings_layer)
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "设置"
	settings_button.icon = preload("res://assets/ui/settings.svg")
	settings_button.add_theme_constant_override("icon_max_width", 20)
	settings_button.add_theme_constant_override("h_separation", 8)
	settings_button.position = Vector2(1104, 22)
	settings_button.size = Vector2(96, 38)
	settings_button.theme = ui.theme
	settings_button.tooltip_text = "设置 / Esc · 暂停、声音与离开游戏"
	settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_button.pressed.connect(open_settings)
	settings_layer.add_child(settings_button)
	RenderingServer.set_default_clear_color(GameTheme.BG)
	heat_label = label(Vector2(70, 8), 26)
	heat_label.add_theme_color_override("font_color", GameTheme.GOLD)
	inspiration_label = label(Vector2(1008, 35), 21)
	inspiration_label.size = Vector2(80, 30)
	inspiration_label.add_theme_color_override("font_color", InspirationPickupView.LIGHT)
	inspiration_label.mouse_filter = Control.MOUSE_FILTER_STOP
	inspiration_label.tooltip_text = "本局已赚灵感，跨局保留，用于局外购卡与刷新。\n点击鼠群掉落的紫色灵感即可收集；过关自动收取余下灵感。"
	header = label(Vector2(948, 674), 12)
	header.size = Vector2(306, 38)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.tooltip_text = "进度表示计划鼠潮的生成比例；全部生成后仍需清除剩余敌人。"
	operation_hint = label(Vector2(184, 684), 13)
	operation_hint.size = Vector2(514, 24)
	operation_hint.add_theme_color_override("font_color", GameTheme.MUTED)
	operation_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_hint = label(Vector2(728, 684), 13)
	recipe_hint.size = Vector2(202, 24)
	recipe_hint.add_theme_color_override("font_color", GameTheme.GOLD)
	recipe_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	speed_button = button("1× 速度", Vector2(34, 47), func() -> void:
		if run.state.phase == "battle" and not placement_modal_visible(): run.speed = 3.0 - run.speed)
	speed_button.name = "SpeedButton"
	speed_button.custom_minimum_size = Vector2(124, 28)
	speed_button.add_theme_font_size_override("font_size", 13)
	speed_button.toggle_mode = true
	speed_button.tooltip_text = "切换 1× / 2× 战斗速度"
	var cursor_layer := CanvasLayer.new()
	cursor_layer.layer = 100
	add_child(cursor_layer)
	shovel_cursor = TextureRect.new()
	shovel_cursor.texture = preload("res://assets/ui/spatula.svg")
	shovel_cursor.size = Vector2(48, 48)
	shovel_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shovel_cursor.hide()
	cursor_layer.add_child(shovel_cursor)
	visibility_changed.connect(update_shovel_cursor)
	get_window().mouse_exited.connect(func() -> void:
		pointer_in_window = false
		update_shovel_cursor())
	get_window().mouse_entered.connect(func() -> void:
		if not is_inside_tree(): return
		pointer_in_window = true
		pointer = get_global_mouse_position()
		update_shovel_cursor())
	get_window().focus_exited.connect(func() -> void:
		window_focused = false
		update_shovel_cursor())
	get_window().focus_entered.connect(func() -> void:
		if not is_inside_tree(): return
		window_focused = true
		pointer = get_global_mouse_position()
		update_shovel_cursor())
	shovel_button = button("", Vector2(1206, 14), func() -> void:
		shovel = not shovel
		selected = ""
		move_from = Vector2i(-1,-1))
	shovel_button.custom_minimum_size = Vector2(52, 52)
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
	shovel_button.tooltip_text = "拿起锅铲后点击美食铲除；左键点击原处或右键放回。Esc 打开设置。立即铲除，无返还。"
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
	inspiration_pickup_view = InspirationPickupView.new()
	inspiration_pickup_view.run = run
	inspiration_pickup_view.projection = projection
	inspiration_pickup_view.target = inspiration_label
	ui.add_child(inspiration_pickup_view)
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
			# Shopping ends only through the explicit completion button.
	)
	shop_surface = Panel.new()
	shop_surface.position = SHOP_RECT.position
	shop_surface.size = SHOP_RECT.size
	shop_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_surface.add_theme_stylebox_override("panel", panel_style)
	shop_overlay.add_child(shop_surface)
	build_save_retry()
	if debug_enabled: create_debug_panel()
	run.changed.connect(rebuild)
	if run.state == null and not run.resume_run():
		var save_error: String = run.message
		run.new_run(int(Time.get_unix_time_from_system()))
		if not save_error.is_empty(): run.message = save_error
	if run.state == null:
		ui.hide()
		settings_button.hide()
		var failure := Label.new()
		failure.text = run.message
		failure.position = Vector2(80,260)
		failure.size = Vector2(1120,180)
		failure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(failure)
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	run.advance(0.0)
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
	node.pressed.connect(func() -> void: sound.cue("ui_click"))
	node.pressed.connect(action)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ui.add_child(node)
	return node

func report(error: String, success_cue: String = "") -> void:
	if not error.is_empty(): sound.cue("ui_error")
	elif not success_cue.is_empty(): sound.cue(success_cue)
	feedback_text = error
	feedback_remaining = 0.0 if error.is_empty() else 3.0
	run.message = "操作完成" if error.is_empty() else error
	if error.is_empty(): run.persist()
	rebuild()

func rebuild() -> void:
	if not is_inside_tree(): return
	# Refresh the persisted chapter bonus with UI state changes, never from the frame loop.
	first_clear_inspiration = 0
	if run.persistence and run.state != null:
		first_clear_inspiration = int(run.saves.load_meta(run.data).get("ledger", {}).get(run.state.run_id, {}).get("first_clear_reward", 0))
	if sound != null: sound.bind_run(run)
	shovel_feedback.bind(run, projection, art)
	status_feedback.bind(run, projection)
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
	var victory_caption: String = "接续守卫完成 · 食堂安然无恙" if run.state.start_wave > 1 else "五大关告捷 · 食堂安然无恙"
	panel_label({"prepare":"购买食谱，强化本局携带阵容", "battle":"已获得的加成持续生效", "won":victory_caption, "lost":"粮仓失守 · 换个阵容再试试"}.get(run.state.phase,""), 13, GameTheme.MUTED)
	if run.shop.is_open():
		build_shop()
	save_retry_message.text = run.message
	if run.state.phase in ["won","lost"]:
		panel_label("今 夜 战 报", 13, GameTheme.GOLD)
		for line: String in ["守卫时长        %.1f 分钟" % (run.state.elapsed/60.0), "击退鼠群        %d" % run.state.metrics.kills, "粮仓损失        %d" % run.state.metrics.leaks, "美食阵亡        %d" % run.state.metrics.deaths]:
			panel_label(line, 18, GameTheme.TEXT)
	var owned: Label = panel_label("已购食谱 %02d  ·  悬停查看" % run.state.recipes.size(), 13, GameTheme.MUTED)
	owned.mouse_filter = Control.MOUSE_FILTER_STOP
	owned.tooltip_text = "尚未购买食谱；在小铺用热量购买。" if run.state.recipes.is_empty() else "本局食谱\n"
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
		var level := card_label(badge, str(run.state.star(id)) if run.state.legacy_stars else "+%d" % run.state.level(id), Vector2(0, 5), Vector2(24, 16), 11, Color("#fff7ec"))
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
		var cooldown_time := card_label(node, "", Vector2(14, 20), Vector2(44, 28), 20, GameTheme.TEXT)
		cooldown_time.name = "CooldownTime"
		cooldown_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown_time.add_theme_color_override("font_shadow_color", Color("102023"))
		cooldown_time.add_theme_constant_override("shadow_offset_x", 1)
		cooldown_time.add_theme_constant_override("shadow_offset_y", 2)
		cooldown_time.visible = false
		var selection := Panel.new()
		selection.name = "Selection"
		selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var selection_style := GameTheme.box(Color.TRANSPARENT, 6, GameTheme.GOLD)
		selection_style.set_border_width_all(2)
		selection.add_theme_stylebox_override("panel", selection_style)
		selection.visible = false
		node.add_child(selection)
		selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.tooltip_text = "%s · %s · 永久强化 +%d\n生命 %.0f · 伤害 %.1f\n间隔 %.2f 秒 · 射程 %.1f 格\n放置冷却 %.0f 秒 · 本局只通过食谱成长" % [run.data.foods[id].title, FOOD_ROLES.get(id,"美食"), run.state.level(id), run.board.max_hp(id), stats.damage * run.state.stat_multiplier(id,run.data), stats.interval, run.recipes.reach(id), stats.cooldown]
		node.set_meta("details", node.tooltip_text)
		node.gui_input.connect(func(event: InputEvent) -> void:
			if event.is_action_pressed("board_select"): begin_card_drag(id))
		cards.add_child(node)
	cards.position.x = 190 + (632 - (run.state.cards.size() * 80 - 8)) * 0.5
	sync_panel_visibility()

func set_panel_open(value: bool) -> void:
	panel_open = value
	sync_panel_visibility()


func sync_panel_visibility() -> void:
	panel.visible = false
	var show_shop: bool = run.shop.is_open()
	var show_retry: bool = run.state.phase == "prepare" and not show_shop and not run.automatic_start_pending
	if show_shop or show_retry:
		cancel_card_drag()
		selected = ""
		shovel = false
		move_from = Vector2i(-1, -1)
	var was_visible: bool = shop_overlay.visible
	shop_overlay.visible = show_shop
	var retry_was_visible: bool = save_retry_overlay.visible
	save_retry_overlay.visible = show_retry
	if show_retry and not retry_was_visible:
		save_retry_overlay.get_node("Surface/Retry").grab_focus()
	if show_shop and not was_visible:
		shop_surface.get_node("Done").grab_focus()

func build_save_retry() -> void:
	save_retry_overlay = Control.new()
	save_retry_overlay.size = Vector2(1280, 720)
	save_retry_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	save_retry_overlay.hide()
	ui.add_child(save_retry_overlay)
	var shade := ColorRect.new()
	shade.size = save_retry_overlay.size
	shade.color = Color(0.01, 0.015, 0.025, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_retry_overlay.add_child(shade)
	var surface := Panel.new()
	surface.name = "Surface"
	surface.position = Vector2(350, 214)
	surface.size = Vector2(580, 292)
	surface.add_theme_stylebox_override("panel", panel_style)
	save_retry_overlay.add_child(surface)
	card_label(surface, "保存未完成", Vector2(28, 24), Vector2(524, 40), 28, GameTheme.TEXT)
	card_label(surface, "保存成功后继续下一小关", Vector2(28, 76), Vector2(524, 26), 16, GameTheme.MUTED)
	save_retry_message = card_label(surface, "", Vector2(28, 116), Vector2(524, 84), 16, GameTheme.ACCENT, true)
	var retry := Button.new()
	retry.name = "Retry"
	retry.text = "重试保存并开战"
	retry.position = Vector2(302, 222)
	retry.size = Vector2(250, 42)
	retry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	retry.pressed.connect(func() -> void:
		run.start()
		if run.state.phase == "prepare": sound.cue("ui_error")
		rebuild())
	surface.add_child(retry)

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
	var definition: DifficultyDef = run.data.difficulties[run.state.difficulty]
	card_label(shop_surface, "%s · %d-%d · 总 %02d/%d · %s" % [run.data.chapters[run.state.chapter_id].title,run.data.chapters[run.state.chapter_id].order,run.state.wave,run.state.global_wave(),run.data.scene_wave_count(run.state.scene_id),definition.title], Vector2(24, 18), Vector2(520, 20), 12, GameTheme.GOLD).name = "SceneProgress"
	card_label(shop_surface, "打烊小铺", Vector2(24, 42), Vector2(420, 36), 28, GameTheme.TEXT)
	var wave: Resource = run.data.chapter_waves(run.state.chapter_id)[run.state.wave - 1]
	var threats: Array[String] = []
	for id: String in wave.stats.composition:
		if run.data.enemies[id].title not in threats: threats.append(run.data.enemies[id].title)
	var preview := card_label(shop_surface, "下关 · %s · %s" % [wave.title, " / ".join(threats)], Vector2(24, 80), Vector2(530, 22), 12, GameTheme.MUTED)
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview.mouse_filter = Control.MOUSE_FILTER_STOP
	preview.tooltip_text = "即将迎战：%s\n%s\n购物与布阵共用热量，预留补位预算。" % [wave.title, " / ".join(threats)]
	if wave.stats.has("boss"):
		var boss: Dictionary = wave.stats.boss
		preview.tooltip_text += "\n%s：第 %d、%d 行增援，预警 %.1f 秒；常态 %s，狂暴 %s，半血 %s。" % [boss.title, int(boss.rows[0])+1, int(boss.rows[1])+1, boss.warning_seconds, run.data.enemies[boss.normal_id].title, run.data.enemies[boss.rage_id].title, run.data.enemies[boss.burst_id].title]
	var budget := card_label(shop_surface, "%d 热量" % run.state.heat, Vector2(572, 35), Vector2(244, 36), 26, GameTheme.GOLD)
	budget.name = "Budget"
	budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var budget_note := card_label(shop_surface, "购物 / 布阵共用 · 准备时不恢复", Vector2(566, 79), Vector2(250, 22), 12, GameTheme.MUTED)
	budget_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shop_items = HBoxContainer.new()
	shop_items.position = Vector2(24, 96)
	shop_items.size = Vector2(792, 222)
	shop_items.add_theme_constant_override("separation", 12)
	shop_surface.add_child(shop_items)
	var focus_buttons: Array[Button] = []
	if run.state.choices.is_empty():
		var has_candidates: bool = false
		for id: String in run.data.recipes:
			if run.recipes.eligible(id, run.shop.unlocked): has_candidates = true
		var empty_title := card_label(shop_surface, "本轮食谱已售罄" if has_candidates else "本关暂无可购食谱", Vector2(72, 210), Vector2(696, 40), 24, GameTheme.TEXT)
		empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var empty_text := card_label(shop_surface, "可刷新选购，也可以保留热量直接开战。" if has_candidates else "当前阵容没有已解锁、尚未购买的食谱。\n保留热量，完成购物即可开战。", Vector2(72, 262), Vector2(696, 72), 16, GameTheme.MUTED, true)
		empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index: int in range(run.state.choices.size()):
		var id: String = run.state.choices[index]
		var item := shop_button("", Vector2(24 + index * 268, 128), Vector2(256, 284), func() -> void: report(run.shop.buy_recipe(id), "purchase"))
		item.name = "Recipe_" + id
		item.disabled = run.state.heat < run.data.rules.recipe_price
		var required: String = run.data.recipes[id].stats.requires
		var target: String = run.data.foods[required].title if run.data.foods.has(required) else ("范围美食" if required == "area" else "全阵容")
		item.tooltip_text = "%s · %s\n%s\n购买立即生效，持续至本局结束。" % [run.data.recipes[id].title, target, run.data.recipes[id].stats.description]
		card_label(item, target + " · 本局加成", Vector2(18, 13), Vector2(220, 22), 12, GameTheme.ACCENT)
		var portrait := TextureRect.new()
		portrait.texture = art.recipe(id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(86, 39)
		portrait.size = Vector2(84, 80)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(portrait)
		card_label(item, run.data.recipes[id].title, Vector2(20, 122), Vector2(216, 30), 22, GameTheme.TEXT)
		card_label(item, run.data.recipes[id].stats.description, Vector2(20, 160), Vector2(216, 56), 15, GameTheme.MUTED, true)
		card_label(item, "%d 热量  ·  %s" % [run.data.rules.recipe_price, "热量不足" if item.disabled else "购买"], Vector2(20, 226), Vector2(216, 26), 17, GameTheme.GOLD)
		var after_purchase: int = floori(run.state.heat) - run.data.rules.recipe_price
		var purchase_note := card_label(item, "还差 %d 热量" % -after_purchase if item.disabled else "买后余 %d 热量布阵" % after_purchase, Vector2(20, 253), Vector2(216, 22), 13, GameTheme.DANGER if item.disabled else GameTheme.ACCENT)
		purchase_note.name = "PurchaseNote"
		focus_buttons.append(item)
	var start_budget := card_label(shop_surface, "开战可用 %d 热量  ·  余额跨关保留" % run.state.heat, Vector2(24, 429), Vector2(480, 26), 16, GameTheme.TEXT)
	start_budget.name = "StartBudget"
	start_budget.tooltip_text = "食谱购买、刷新和美食布阵使用同一份热量。难度 %s 在整局固定。" % definition.title
	start_budget.mouse_filter = Control.MOUSE_FILTER_STOP
	var owned := card_label(shop_surface, "已购食谱 %02d  ·  悬停查看" % run.state.recipes.size(), Vector2(562, 431), Vector2(254, 24), 13, GameTheme.GOLD)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	owned.mouse_filter = Control.MOUSE_FILTER_STOP
	owned.tooltip_text = owned_recipe_tooltip()
	var shop_message: String = run.message
	if run.state.heat < run.data.rules.recipe_price and run.message == "购买食谱，购物完成后立即开战。":
		shop_message = "先开战积攒热量；食谱可留到后续关卡选购。"
	var feedback := card_label(shop_surface, shop_message, Vector2(24, 465), Vector2(792, 22), 13, GameTheme.ACCENT)
	feedback.clip_text = true
	feedback.tooltip_text = shop_message
	feedback.mouse_filter = Control.MOUSE_FILTER_STOP
	var refresh_left: int = maxi(0, run.data.rules.refresh_limit - run.state.refreshes)
	var refresh_text: String = "换一批 · %d 热量  /  余 %d 次" % [run.data.rules.refresh_cost, refresh_left]
	if refresh_left == 0: refresh_text = "本关刷新已用完"
	elif run.state.heat < run.data.rules.refresh_cost: refresh_text = "刷新还差 %d 热量 · 余 %d 次" % [ceili(run.data.rules.refresh_cost - run.state.heat), refresh_left]
	shop_refresh = shop_button(refresh_text, Vector2(24, 500), Vector2(280, 36), func() -> void: report(run.shop.refresh(), "refresh"))
	shop_refresh.add_theme_font_size_override("font_size", 14)
	shop_refresh.disabled = run.state.refreshes >= run.data.rules.refresh_limit or run.state.heat < run.data.rules.refresh_cost
	shop_refresh.tooltip_text = "刷新次数已用完" if run.state.refreshes >= run.data.rules.refresh_limit else ("热量不足" if shop_refresh.disabled else "更换食谱商品，消耗 %d 热量" % run.data.rules.refresh_cost)
	card_label(shop_surface, "食谱整局生效", Vector2(332, 507), Vector2(238, 24), 13, GameTheme.MUTED)
	var done := shop_button("购物完成 · 开战  →", Vector2(620, 500), Vector2(196, 36), finish_shopping)
	done.add_theme_font_size_override("font_size", 15)
	done.name = "Done"
	done.tooltip_text = "完成购物并立即开始本关；准备状态自动保存。"
	GameTheme.primary(done)
	focus_buttons.append_array([shop_refresh, done])
	# Keep keyboard focus within the modal, including after a purchase rebuild.
	var enabled: Array[Button] = []
	for node: Button in focus_buttons:
		if not node.disabled: enabled.append(node)
	for index: int in range(enabled.size()):
		enabled[index].focus_next = enabled[index].get_path_to(enabled[(index + 1) % enabled.size()])
		enabled[index].focus_previous = enabled[index].get_path_to(enabled[(index - 1 + enabled.size()) % enabled.size()])
	if shop_overlay.visible: done.grab_focus()

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
	if damage_feedback.get_parent() == null:
		add_child(damage_feedback)
		move_child(damage_feedback, 0)
	damage_feedback.bind(run, projection)
	status_feedback.bind(run, projection)
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
	damage_feedback.advance(visual_delta)
	status_feedback.advance(visual_delta)
	shovel_feedback.advance(visual_delta)
	heat_label.text = "%03d" % run.state.heat
	heat_label.tooltip_text = "热量上限 %.0f；每秒恢复 %.0f，准备阶段不恢复。\n用于布阵、购买食谱与刷新，剩余量跨关保留。\n点击布丁冒出的火苗，飞入此处后获得热量。" % [run.data.rules.heat_cap, run.data.rules.heat_rate]
	heat_pickup_view.queue_redraw()
	inspiration_label.text = "%02d" % earned_inspiration()
	inspiration_pickup_view.queue_redraw()
	header.text = wave_status()
	header.tooltip_text = "进度表示计划鼠潮的生成比例；满条后仍需清除全部余鼠。\n战斗中退出会回到本关开战前。\n" + owned_recipe_tooltip()
	operation_hint.text = operation_status()
	operation_hint.add_theme_color_override("font_color", GameTheme.GOLD if shovel or not selected.is_empty() else GameTheme.MUTED)
	recipe_hint.text = "食谱 %02d · 悬停查看" % run.state.recipes.size()
	recipe_hint.tooltip_text = owned_recipe_tooltip()
	update_controls()
	feedback_remaining = maxf(0.0, feedback_remaining - delta)
	update_inspector()
	queue_redraw()

func earned_inspiration() -> int:
	var amount: int = run.state.collected_inspiration() + first_clear_inspiration
	if run.state.rewards_enabled:
		for index: int in range(run.state.reward_floor, mini(int(run.state.metrics.passed), run.data.scene_wave_count(run.state.scene_id))):
			amount += run.state.inspiration_for_wave(index, run.data)
	return amount

func owned_recipe_tooltip() -> String:
	if run.state.recipes.is_empty(): return "尚未购买食谱。大关通关后可在小铺用热量购买，持续至本局结束。"
	var text: String = "本局已购食谱 · 对现有与后续美食生效"
	for id: String in run.state.recipes:
		text += "\n%s · %s" % [run.data.recipes[id].title, run.data.recipes[id].stats.description]
	return text

func operation_status() -> String:
	if run.shop.is_open(): return "大关通关 · 选购食谱，留足布阵热量"
	if run.state.phase == "prepare": return "保存进度后继续下一小关"
	if run.state.phase != "battle": return "今夜收摊 · 灵感跨局保留"
	if run.paused: return "已暂停 · 从设置继续游戏"
	if shovel: return "锅铲已拿起 · 点击立即铲除，无返还 · 右键放回"
	if not selected.is_empty():
		return "%s · %d 热量 · %s" % [run.data.foods[selected].title, run.data.foods[selected].stats.cost, card_status(selected)]
	return "选美食，守住粮仓  ·  点击火苗与灵感收取"

func wave_progress() -> float:
	if run.state.phase == "prepare": return 0.0
	if run.state.phase == "won": return 1.0
	return clampf(float(run.director.cursor) / maxi(1, run.director.events.size()), 0.0, 1.0)

func wave_status() -> String:
	var status: String = {"prepare":"大关间购物" if run.shop.is_open() else "准备开战", "won":"守卫成功", "lost":"粮仓失守"}.get(run.state.phase, "")
	if run.state.phase == "battle":
		status = "清理余鼠 %d" % run.combat.enemies.size() if wave_progress() >= 1.0 else "鼠潮 %d%% · 余鼠 %d" % [roundi(wave_progress() * 100), run.combat.enemies.size()]
		if run.paused: status = "暂停 · " + status
	return "%d-%d · 总 %02d/%d · %s\n%s" % [run.data.chapters[run.state.chapter_id].order,run.state.wave,run.state.global_wave(),run.data.scene_wave_count(run.state.scene_id),run.data.difficulties[run.state.difficulty].title,status]

func draw_wave_progress() -> void:
	var bar := Rect2(948, 714, 300, 3)
	draw_style_box(GameTheme.box(GameTheme.RAISED, 3), bar)
	var fill_width: float = bar.size.x * wave_progress()
	if fill_width > 0:
		draw_style_box(GameTheme.box(GameTheme.DANGER if run.state.phase == "lost" else GameTheme.ACCENT, 3), Rect2(bar.position, Vector2(fill_width,bar.size.y)))
	for index: int in range(1,8):
		var x: float = bar.position.x + bar.size.x * index / 8.0
		draw_line(Vector2(x,bar.position.y),Vector2(x,bar.end.y),GameTheme.BG,2)
	draw_circle(Vector2(bar.end.x,bar.get_center().y),3,GameTheme.GOLD)

func update_controls() -> void:
	var phase: String = run.state.phase
	sync_panel_visibility()
	speed_button.text = "%.0f× 速度" % run.speed
	speed_button.disabled = phase != "battle" or placement_modal_visible()
	speed_button.set_pressed_no_signal(run.speed == 2.0)
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
		card.tooltip_text = "" if drag_active else "%s\n%s\n按住拖到格子放置 · 右键取消 · Esc 设置" % [card.get_meta("details"), card_status(id)]
		card.material.set_shader_parameter("unaffordable", run.state.heat < run.data.foods[id].stats.cost)
		var cooldown: ColorRect = card.get_node("Cooldown")
		var duration: float = run.data.foods[id].stats.cooldown
		var ratio: float = clampf(remaining / duration, 0, 1) if duration > 0 else 0.0
		cooldown.visible = phase == "battle" and ratio > 0
		cooldown.material.set_shader_parameter("remaining_ratio", ratio)
		cooldown.material.set_shader_parameter("card_size", card.size)
		var cooldown_time: Label = card.get_node("CooldownTime")
		cooldown_time.visible = cooldown.visible
		cooldown_time.text = "%d" % ceili(remaining)

func update_shovel_cursor() -> void:
	if shop_overlay == null or run.state == null: return
	var pickup_hovered: bool = inspiration_pickup_view != null and inspiration_pickup_view.pickup_at(pointer) >= 0 and not placement_modal_visible() and not run.paused and pointer_in_window and window_focused and is_visible_in_tree()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if pickup_hovered else Input.CURSOR_ARROW)
	var active: bool = shovel and run.state.phase in ["prepare", "battle"] and not run.paused and not placement_modal_visible() and not pickup_hovered and pointer_in_window and window_focused and is_visible_in_tree()
	shovel_cursor.position = pointer - Vector2(30, 8)
	shovel_cursor.visible = active
	if active == shovel_cursor_active: return
	shovel_cursor_active = active
	# Keep tool artwork in CanvasLayer: native custom cursors can fail with
	# ERR_FAIL_NULL(imgrep) on macOS (Godot 4.6.3). See doc/art/ui.md.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if active else Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	# A queued old scene must not bind the persistent audio service to its run.
	if run.changed.is_connected(rebuild): run.changed.disconnect(rebuild)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not shovel_cursor_active: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shovel_cursor_active = false

func card_status(id: String) -> String:
	if run.shop.is_open(): return "选购食谱，购物完成后可放置美食"
	if run.state.phase == "prepare": return "保存进度后开战"
	if run.state.phase in ["won", "lost"]: return "本局已结束"
	if run.state.phase != "battle": return "等待下一关"
	if run.paused: return "已暂停"
	var remaining: float = run.state.cooldowns.get(id,0.0)
	if remaining > 0: return "冷却 %.1f 秒" % remaining
	if run.state.heat < run.data.foods[id].stats.cost: return "热量不足"
	return "已选中 · 可放置" if selected == id else "可放置"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		if not selected.is_empty() or not drag_card.is_empty() or shovel: sound.cue("ui_cancel")
		cancel_card_drag()
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
	if debug_enabled and event.is_action_pressed("debug_panel"): debug_window.popup_centered()
	if event.is_action_pressed("board_select"):
		if placement_modal_visible(): return
		if panel.visible and PANEL_RECT.has_point(event.position): return
		if collect_inspiration_at(event.position): return
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
			report(run.board.remove(row, col, run.paused))
		elif run.state.phase == "prepare":
			if move_from.x < 0: move_from = Vector2i(col,row)
			else:
				report(run.board.move(move_from.y,move_from.x,row,col))
				move_from = Vector2i(-1,-1)
		elif not selected.is_empty(): report(run.board.place(selected,row,col,run.paused))

func collect_inspiration_at(pos: Vector2) -> bool:
	if placement_modal_visible(): return false
	var pickup_uid: int = inspiration_pickup_view.pickup_at(pos)
	if pickup_uid < 0: return false
	report(run.collect_inspiration(pickup_uid))
	get_viewport().set_input_as_handled()
	return true

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
		for corpse: Dictionary in animator.food_corpses:
			if corpse.row == row: draw_food(corpse)
		for unit: Dictionary in run.state.units:
			if unit.row == row: draw_food(unit)
		for corpse: Dictionary in animator.corpses:
			if corpse.row == row: draw_mouse(corpse)
		for enemy: Dictionary in run.combat.enemies:
			if enemy.row == row: draw_mouse(enemy)
		for shot: Dictionary in run.combat.projectiles:
			if shot.row == row:
				var pos: Vector2 = projection.foot(shot.x, row) - Vector2(0, 27 * projection.depth_scale(row))
				ProjectileArt.draw_shot(self, shot, pos, projection.depth_scale(row))
	if run.state.phase == "battle":
		for row: int in run.director.warning_rows():
			text_at(projection.foot(RunState.BOARD_WIDTH + 7, row) + Vector2(0, -8),"◀",Color("ffbe75"), 20)
		for warning: Dictionary in run.combat.warning_summons:
			for row: int in warning.rows:
				var tile: PackedVector2Array = projection.polygon(Rect2((RunState.COLS - 1) * 96, row * 96, 96, 96))
				draw_colored_polygon(tile, Color(1.0, 0.55, 0.2, 0.22))
				text_at(projection.foot(RunState.BOARD_WIDTH + 7, row) + Vector2(0, -12), "增援 %.1fs" % maxf(0, warning.remaining), Color("ffce83"), 13)
	shovel_feedback.draw(self)
	status_feedback.draw_effects(self)
	battle_art.hud(self, run.state, run.paused)
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
	battle_art.background(self, run.data.chapters[run.state.chapter_id].background_tint)

func outline(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func draw_board() -> void:
	var edge: PackedVector2Array = projection.polygon(Rect2(Vector2.ZERO, BoardProjection.LOGICAL_SIZE))
	var front: PackedVector2Array = PackedVector2Array([edge[3], edge[2], edge[2] + Vector2(0, 8), edge[3] + Vector2(0, 8)])
	draw_colored_polygon(front, Color("102a29"))
	draw_colored_polygon(edge, Color("718975"))
	outline(edge, Color("b7c4a755"), 1.5)
	var hover_cell: Vector2i = projection.cell_at(pointer)
	for row: int in range(RunState.ROWS):
		for col: int in range(RunState.COLS):
			var tile: PackedVector2Array = projection.tiles[row * RunState.COLS + col]
			battle_art.tile(self, Rect2(tile[0], tile[2] - tile[0]), (row + col) % 2 == 0)
			if move_from == Vector2i(col, row):
				draw_colored_polygon(tile, Color("e7c07630"))
				outline(tile, Color("f8d482"), 2.0)
			elif hover_cell == Vector2i(col, row):
				draw_colored_polygon(tile, Color("9cdbc328"))
				outline(tile, Color("b4ded2"), 1.5)

func draw_food(unit: Dictionary) -> void:
	var scale_value: float = projection.depth_scale(unit.row)
	var foot: Vector2 = projection.foot(unit.col * 96 + 48, unit.row)
	var pose: Dictionary = animator.bun_pose(unit, foot) if unit.id == "bun" else animator.pose(unit, foot)
	foot = pose.foot
	status_feedback.draw_ground(self, unit, pose.shadow)
	if unit.id == "bun":
		draw_actor(art.bun_frame(animator.bun_frame(unit)), foot, Vector2(76, 76) * scale_value, unit.uid, pose, scale_value)
	else:
		draw_actor(art.food(unit.id), foot, Vector2(66, 76) * scale_value, unit.uid, pose, scale_value)
	if unit.has("death_age"): return
	var fraction: float = unit.hp / run.board.max_hp(unit.id)
	draw_rect(Rect2(foot + Vector2(-28, 4) * scale_value, Vector2(56, 4) * scale_value), Color("633f46"))
	draw_rect(Rect2(foot + Vector2(-28, 4) * scale_value, Vector2(56 * fraction, 4) * scale_value), Color("ff817d") if fraction < 0.25 else Color("7fd29b"))
	status_feedback.draw_status(self, unit, foot, 76 * scale_value)

func draw_mouse(enemy: Dictionary) -> void:
	var scale_value: float = projection.depth_scale(enemy.row)
	var foot: Vector2 = projection.foot(enemy.x, enemy.row)
	var size: Vector2 = Vector2(58, 72)
	if enemy.id == "elite": size = Vector2(68, 82)
	if enemy.id == "boss": size = Vector2(82, 98)
	status_feedback.draw_ground(self, enemy, foot)
	draw_mouse_frame(enemy, foot, size, scale_value)
	if enemy.has("death_age"): return
	var status_pos: Vector2 = foot - Vector2(22, size.y * 0.8) * scale_value
	if enemy.id in ["boss", "elite"]:
		var caption: String = run.combat.enemy_title(enemy.id)
		var label_pos: Vector2 = status_pos + Vector2(0, -14)
		draw_string_outline(ThemeDB.fallback_font, label_pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("26392f"))
		text_at(label_pos, caption, Color("ffe1a1"), 12)
	draw_rect(Rect2(foot + Vector2(-23, 4) * scale_value,Vector2(46 * enemy.hp / enemy.max_hp, 4) * scale_value),Color("ed8796"))
	status_feedback.draw_status(self, enemy, foot, size.y * scale_value)

func draw_mouse_frame(enemy: Dictionary, foot: Vector2, size: Vector2, scale_value: float) -> void:
	# Articulated frames already contain anticipation, weight and recoil.
	var pose: Dictionary = animator.mouse_pose(enemy, foot)
	if not enemy.has("death_age"): pose = status_feedback.cast_pose(enemy, pose)
	size.x = size.y
	draw_actor(art.mouse_frame(enemy.id, animator.mouse_frame(enemy)), foot, size * scale_value, enemy.uid, pose, scale_value)

func draw_actor(texture: Texture2D, foot: Vector2, size: Vector2, uid: int, pose: Dictionary, depth: float) -> void:
	if texture == null: return
	draw_set_transform(pose.shadow + Vector2(4, 0), -0.04, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, size.x * 0.34, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(foot + pose.offset * depth, pose.angle, pose.scale)
	draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y * 0.86), size), false)
	damage_feedback.capture_actor(uid, texture, foot, size, pose, depth)
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
	var inspected_enemy: Dictionary = hovered_enemy()
	inspect.text = ""
	if drag_active:
		var error: String = drag_placement_error()
		inspect.text = "松手放置 · 右键 / Esc 取消" if error.is_empty() else error
	elif feedback_remaining > 0:
		inspect.text = feedback_text
	elif inspiration_pickup_view.pickup_at(pointer) >= 0:
		inspect.text = "暂停中 · 恢复后点击收集灵感" if run.paused else "点击紫色灵感 · 跨局保留，用于局外购卡"
	elif heat_pickup_view.pickup_at(pointer) >= 0:
		inspect.text = "暂停中 · 恢复后点击火苗收取热量" if run.paused else "点击火苗 · 飞入左上角后获得热量"
	elif not unit.is_empty():
		inspect.text = "%s +%d   生命 %.0f / %.0f\n伤害 %.1f · 间隔 %.2f秒 · 射程 %.1f格" % [run.data.foods[unit.id].title,run.state.level(unit.id),unit.hp,run.board.max_hp(unit.id),run.recipes.damage(unit),run.recipes.interval(unit),run.recipes.reach(unit.id)]
		var description: String = status_feedback.description(unit)
		if not description.is_empty(): inspect.text += "\n" + description
	elif not inspected_enemy.is_empty():
		inspect.text = "%s   生命 %.0f / %.0f\n%s" % [run.combat.enemy_title(inspected_enemy.id), inspected_enemy.hp, inspected_enemy.max_hp, status_feedback.description(inspected_enemy)]
	elif debug_enabled and run.state.phase == "battle":
		inspect.text = "F3 开发面板 · 各行压力"
		for row: int in range(RunState.ROWS):
			var pressure: float = 0.0
			for enemy: Dictionary in run.combat.enemies:
				if enemy.row == row: pressure += enemy.hp
			inspect.text += " %d:%.0f" % [row+1,pressure]
	inspect.visible = not inspect.text.is_empty() and not placement_modal_visible()
	inspect.size = Vector2(360, 0)
	inspect.position = Vector2(clampf(pointer.x + 16, 12, 908), clampf(pointer.y + 20, 180, 720 - inspect.size.y - 12))

func hovered_enemy() -> Dictionary:
	if drag_active or shop_overlay.visible or (panel.visible and PANEL_RECT.has_point(pointer)): return {}
	for enemy: Dictionary in run.combat.enemies:
		var foot: Vector2 = projection.foot(enemy.x, enemy.row)
		var height: float = (98 if enemy.id == "boss" else 82 if enemy.id == "elite" else 72) * projection.depth_scale(enemy.row)
		if Rect2(foot - Vector2(height * 0.5, height * 0.86), Vector2(height, height)).has_point(pointer): return enemy
	return {}


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
	var heat: Button = Button.new()
	heat.text = "补满热量"
	heat.pressed.connect(func() -> void:
		if not run.paused:
			run.state.heat = run.data.rules.heat_cap
			run.persist()
			rebuild())
	box.add_child(heat)
	debug_window.add_child(box)
	ui.add_child(debug_window)
	debug_window.visibility_changed.connect(update_shovel_cursor)

func placement_modal_visible() -> bool:
	return shop_overlay.visible or save_retry_overlay.visible or (debug_window != null and debug_window.visible) or (audio_settings != null and audio_settings.visible)

func begin_card_drag(id: String) -> void:
	if placement_modal_visible(): return
	sound.cue("ui_click")
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
	if event.is_action_pressed("open_settings") and not event.is_echo():
		if debug_window != null and debug_window.visible: return
		if audio_settings.visible: audio_settings.handle_escape()
		else: open_settings()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		pointer = event.position
		update_shovel_cursor()
	# A flying pickup can cross card controls; consume it before GUI selection.
	if event is InputEventMouseButton and event.is_action_pressed("board_select"):
		if collect_inspiration_at(event.position): return
	# Cancel before a hovered Control can consume right-click.
	if shovel and event.is_action_pressed("cancel_selection") and not placement_modal_visible():
		sound.cue("ui_cancel")
		shovel = false
		selected = ""
		move_from = Vector2i(-1, -1)
		get_viewport().set_input_as_handled()
		return
	if not drag_card.is_empty():
		if event.is_action_pressed("cancel_selection") or placement_modal_visible() or run.state.phase != drag_phase or run.paused != drag_paused:
			if event.is_action_pressed("cancel_selection"): sound.cue("ui_cancel")
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
	if shop_overlay.visible and event.is_action_pressed("cancel_selection"):
		get_viewport().set_input_as_handled()

func finish_shopping() -> void:
	if not run.shop.is_open(): return
	run.start()
	if run.state.phase == "prepare": sound.cue("ui_error")
	rebuild()

func open_settings() -> void:
	if audio_settings.visible or run.state == null: return
	cancel_card_drag()
	selected = ""
	shovel = false
	move_from = Vector2i(-1, -1)
	feedback_remaining = 0.0
	audio_settings.open(run, true)
	update_controls()
	update_inspector()

func leave_settings(destination: String) -> void:
	# Standalone scene entry uses the same snapshot rules as the front end.
	if quitting or destination not in ["menu", "quit"]: return
	if not run.persist():
		audio_settings.show_error(run.message)
		return
	if run.state.phase in ["won", "lost"] and run.persistence and not run.saves.settle(run.state, run.data):
		audio_settings.show_error(run.saves.error)
		return
	if destination == "quit":
		quitting = true
		process_mode = Node.PROCESS_MODE_DISABLED
		audio_settings.hide()
		await sound.shutdown()
		get_tree().quit()
	else:
		audio_settings.hide()
		get_tree().change_scene_to_file("res://scenes/front_end.tscn")
