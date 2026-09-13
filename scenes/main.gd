extends Node2D

var projection: BoardProjection = BoardProjection.new()
var art: ArtCatalog = ArtCatalog.new()
var animator: UnitAnimator = UnitAnimator.new()
const PANEL_RECT := Rect2(974, 180, 282, 444)
const FOOD_ROLES := {"bun":"蒸汽输出", "toast":"前排守卫", "pudding":"热量生产", "tea":"冰霜减速", "pepper":"近距爆发", "popcorn":"范围清群", "noodles":"穿透输出", "garlic":"相邻增益"}
var modal_shade: ColorRect
var ui: Control
var start_button: Button
var pause_button: Button
var speed_button: Button
var repair_button: Button
var toggle_button: Button
var context_title: Label
var context_body: Label
var phase_label: Label
var panel_style: StyleBoxFlat
var run: RunController = RunController.new()
var selected: String = ""
var pointer: Vector2 = Vector2(-1,-1)
var move_from: Vector2i = Vector2i(-1, -1)
var shovel: bool = false
var pending_remove: Vector2i
var heat_label: Label
var shovel_button: Button
var panel_open: bool = true
var layout_phase: String = ""
var header: Label
var notice: Label
var cards: HBoxContainer
var panel: VBoxContainer
var confirm: ConfirmationDialog
var sound: SoundService
var tutorial_step: int = 0
var tutorial_skip: Button
var tutorial: Label
var inspect: Label
var restart: ConfirmationDialog
var debug_window: AcceptDialog
var debug_enabled: bool = false
var old_phase: String = ""
var old_pantry: int = 10
var old_units: int = 0

func _ready() -> void:
	panel_style = GameTheme.box(GameTheme.SURFACE, 16, GameTheme.BORDER)
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
	heat_label = label(Vector2(38, 38), 30)
	heat_label.add_theme_color_override("font_color", GameTheme.GOLD)
	header = label(Vector2(948, 656), 14)
	header.tooltip_text = "进度表示计划鼠潮的生成比例；全部生成后仍需清除剩余敌人。"
	notice = label(Vector2(42, 153), 13)
	notice.size = Vector2(1080, 23)
	notice.clip_text = true
	notice.add_theme_color_override("font_color", GameTheme.MUTED)
	start_button = button("开始鼠潮  →", Vector2(24, 118), func() -> void: run.start(); rebuild())
	start_button.custom_minimum_size = Vector2(160, 30)
	GameTheme.primary(start_button)
	pause_button = button("暂停", Vector2(196, 118), func() -> void:
		if run.state.phase == "battle": run.paused = not run.paused)
	pause_button.custom_minimum_size = Vector2(82, 30)
	speed_button = button("1× 速度", Vector2(288, 118), func() -> void: run.speed = 3.0 - run.speed)
	speed_button.custom_minimum_size = Vector2(96, 30)
	repair_button = button("维修 · 4 金", Vector2(396, 118), func() -> void: report(run.board.repair()))
	repair_button.custom_minimum_size = Vector2(132, 30)
	toggle_button = button("收起小铺", Vector2(1014, 118), func() -> void: panel_open = not panel_open)
	toggle_button.custom_minimum_size = Vector2(116, 30)
	shovel_button = button("锅铲", Vector2(1150, 20), func() -> void:
		shovel = not shovel
		selected = ""
		move_from = Vector2i(-1,-1))
	shovel_button.custom_minimum_size = Vector2(98, 86)
	shovel_button.toggle_mode = true
	shovel_button.icon = preload("res://assets/ui/spatula.svg")
	shovel_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	shovel_button.expand_icon = true
	shovel_button.add_theme_constant_override("icon_max_width", 34)
	shovel_button.tooltip_text = "选中锅铲后点击美食铲除；右键或 Esc 取消。战斗中需确认，无返还。"
	button("重新开局", Vector2(1142, 118), func() -> void: restart.popup_centered(Vector2i(460, 190)))
	cards = HBoxContainer.new()
	cards.position = Vector2(190, 20)
	cards.add_theme_constant_override("separation", 6)
	ui.add_child(cards)
	panel = VBoxContainer.new()
	panel.position = PANEL_RECT.position + Vector2(18, 18)
	panel.size.x = 246
	panel.add_theme_constant_override("separation", 10)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(panel)
	phase_label = label(Vector2(42, 322), 14)
	phase_label.add_theme_color_override("font_color", GameTheme.ACCENT)
	context_title = label(Vector2(42, 364), 22)
	context_body = label(Vector2(42, 403), 15)
	context_body.size = Vector2(222, 154)
	context_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_body.add_theme_color_override("font_color", GameTheme.MUTED)
	context_body.add_theme_constant_override("line_spacing", 7)
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
		run.new_run(int(Time.get_unix_time_from_system()))
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
		tutorial_step = 0
		rebuild())
	inspect = label(Vector2.ZERO,15)
	inspect.visible = false
	tutorial = label(Vector2.ZERO,14)
	tutorial.visible = false
	tutorial_skip = button("跳过引导",Vector2(1150,151),func() -> void: tutorial_step = mini(3,tutorial_step+1))
	tutorial_skip.add_theme_font_size_override("font_size", 12)
	tutorial_skip.add_theme_stylebox_override("normal", GameTheme.box(Color.TRANSPARENT, 6))
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
	run.message = "操作完成" if error.is_empty() else error
	if error.is_empty(): run.persist()
	rebuild()

func rebuild() -> void:
	if cards == null: return
	for child: Node in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	for child: Node in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	if layout_phase != run.state.phase:
		panel_open = run.state.phase != "battle"
		layout_phase = run.state.phase
	panel_label({"recipe":"灵感菜单", "prepare":"打烊小铺", "battle":"本局食谱", "won":"今夜，守住了", "lost":"明晚，再来"}.get(run.state.phase,""), 24, GameTheme.TEXT)
	panel_label({"recipe":"选择一道食谱 · 效果持续整局", "prepare":"补充阵容，为下一波做准备", "battle":"已获得的加成持续生效", "won":"八关告捷 · 食堂安然无恙", "lost":"粮仓失守 · 换个阵容再试试"}.get(run.state.phase,""), 13, GameTheme.MUTED)
	if run.state.phase == "recipe":
		for id: String in run.state.choices:
			var choice: Button = panel_button("",func() -> void: report(run.choose_recipe(id)),run.data.recipes[id].stats.description)
			choice.custom_minimum_size.y = 92
			row_content(choice, art.recipe(id), run.data.recipes[id].title, run.data.recipes[id].stats.description)
		if run.state.choices.is_empty(): panel_button("食谱已收集完 · 继续 →",func() -> void: run.skip_recipe())
	elif run.state.phase == "prepare":
		for index: int in range(run.state.offers.size()):
			var offer: Dictionary = run.state.offers[index]
			var sold: bool = offer.id.is_empty() or offer.bought or run.state.cards.get(offer.id,0) >= 6
			var item: Button = panel_button("",func() -> void: report(run.shop.buy(index)))
			item.custom_minimum_size.y = 76
			item.disabled = sold or run.state.coins < run.data.foods[offer.id].stats.price
			if offer.id.is_empty():
				item.text = "已收集全部美食"
			else:
				var count: int = run.state.cards.get(offer.id,0)
				var details: String = "%s · %s" % [FOOD_ROLES.get(offer.id,"美食"), "解锁新美食" if count == 0 else "持有 %d/6" % count]
				var price: String = "已售罄" if sold else "%d 金" % run.data.foods[offer.id].stats.price
				row_content(item, art.food(offer.id), run.data.foods[offer.id].title, details, price)
				item.tooltip_text = "本商品已售罄" if sold else ("金币不足" if item.disabled else "购买后自动解锁或累积升星进度；累计 3 张二星，6 张三星。")
		var refresh: Button = panel_button("刷新 · %d 金     %d/%d" % [run.data.rules.refresh_cost,run.state.refreshes,run.data.rules.refresh_limit],func() -> void: report(run.shop.refresh()))
		refresh.disabled = run.state.refreshes >= run.data.rules.refresh_limit or run.state.coins < run.data.rules.refresh_cost
		refresh.tooltip_text = "刷新次数已用完" if run.state.refreshes >= run.data.rules.refresh_limit else ("金币不足" if run.state.coins < run.data.rules.refresh_cost else "更换三个商品，消耗 %d 金币" % run.data.rules.refresh_cost)
	if run.state.phase in ["won","lost"]:
		panel_label("今 夜 战 报", 13, GameTheme.GOLD)
		for line: String in ["守卫时长        %.1f 分钟" % (run.state.elapsed/60.0), "击退鼠群        %d" % run.state.metrics.kills, "粮仓损失        %d" % run.state.metrics.leaks, "美食阵亡        %d" % run.state.metrics.deaths]:
			panel_label(line, 18, GameTheme.TEXT)
		var again: Button = panel_button("再守一夜  →",func() -> void: restart.popup_centered(Vector2i(460,190)))
		GameTheme.primary(again)
	var owned: Label = panel_label("已选食谱 %02d  ·  悬停查看" % run.state.recipes.size(), 13, GameTheme.MUTED)
	owned.mouse_filter = Control.MOUSE_FILTER_STOP
	owned.tooltip_text = "尚未选择食谱；通过关卡后获得。" if run.state.recipes.is_empty() else "本局食谱\n"
	for id: String in run.state.recipes: owned.tooltip_text += run.data.recipes[id].title + " · " + run.data.recipes[id].stats.description + "\n"
	for id: String in run.state.cards:
		var node: Button = Button.new()
		var stats: Dictionary = run.data.foods[id].stats
		node.custom_minimum_size = Vector2(110, 86)
		node.toggle_mode = true
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = art.food(id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(8,2)
		portrait.size = Vector2(40,37)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(portrait)
		card_label(node, "★%d" % run.state.star(id), Vector2(66,7), Vector2(38,24), 13, GameTheme.GOLD)
		card_label(node, run.data.foods[id].title, Vector2(8,35), Vector2(98,21), 14, GameTheme.TEXT)
		card_label(node, "%d 热 · %d/6" % [stats.cost,run.state.cards[id]], Vector2(8,55), Vector2(98,16), 11, GameTheme.MUTED)
		var status: Label = card_label(node, "", Vector2(8,71), Vector2(98,15), 10, GameTheme.ACCENT)
		status.name = "Status"
		var cooldown: ColorRect = ColorRect.new()
		cooldown.position = Vector2(8,84)
		cooldown.size = Vector2(94,2)
		cooldown.color = GameTheme.GOLD
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown.name = "Cooldown"
		node.add_child(cooldown)
		node.tooltip_text = "%s · %s\n生命 %.0f · 伤害 %.0f\n间隔 %.2f 秒 · 射程 %.1f 格\n放置冷却 %.0f 秒 · 累计 3/6 张升星" % [run.data.foods[id].title, FOOD_ROLES.get(id,"美食"), run.board.max_hp(id), stats.damage * run.data.rules.star_hp[run.state.star(id) - 1], stats.interval, run.recipes.reach(id), stats.cooldown]
		node.pressed.connect(func() -> void: selected = id; shovel = false; move_from = Vector2i(-1,-1))
		cards.add_child(node)
	cards.position.x = 190 + (922 - (run.state.cards.size() * 116 - 6)) * 0.5

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
	portrait.size = Vector2(38, 38)
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
	var visual_delta: float = 0.0
	if not run.paused:
		visual_delta = run.state.elapsed - before if run.state.phase == "battle" else (minf(delta, 0.25) if run.state.phase == "prepare" else 0.0)
	animator.advance(visual_delta, run.combat.enemies)
	heat_label.text = "%03d" % run.state.heat
	heat_label.tooltip_text = "每关上限 350；每秒恢复 5，准备阶段不恢复。"
	header.text = wave_status()
	update_controls()
	notice.text = run.message
	if run.state.phase != old_phase and run.state.phase in ["recipe","won"]: sound.cue("clear")
	if run.state.pantry < old_pantry: sound.cue("danger")
	if run.state.units.size() > old_units: sound.cue("place")
	old_phase = run.state.phase
	old_pantry = run.state.pantry
	old_units = run.state.units.size()
	update_inspector()
	if tutorial_step == 0 and run.state.metrics.puddings > 0: tutorial_step = 1
	if tutorial_step == 1:
		for unit: Dictionary in run.state.units:
			if unit.id == "bun": tutorial_step = 2
	if tutorial_step == 2:
		for unit: Dictionary in run.state.units:
			if unit.id == "toast": tutorial_step = 3
	var tips: Array[String] = ["① 热量每秒恢复；放置布丁每10秒生产热量。","② 选择小笼包，再点入口提示所在行的格子，向右攻击。","③ 把吐司放在输出右侧阻挡鼠群，留意每张卡的共享冷却。"]
	tutorial_skip.visible = tutorial_step < 3 and run.state.wave == 1
	tutorial.text = tips[tutorial_step] if tutorial_step < 3 and run.state.wave == 1 else ""
	notice.text = inspect.text if not inspect.text.is_empty() else (run.message if not run.message.is_empty() else tutorial.text)
	notice.tooltip_text = tutorial.text + "\n战斗中退出将回到本关开战前；准备操作自动保存。"
	notice.size.x = 1080 if tutorial_skip.visible else 1200
	queue_redraw()

func wave_progress() -> float:
	if run.state.phase == "prepare": return 0.0
	if run.state.phase in ["recipe", "won"]: return 1.0
	return clampf(float(run.director.cursor) / maxi(1, run.director.events.size()), 0.0, 1.0)

func wave_status() -> String:
	var status: String = {"prepare":"等待开战", "recipe":"选择食谱", "won":"守卫成功", "lost":"粮仓失守"}.get(run.state.phase, "")
	if run.state.phase == "battle":
		status = "清理余鼠 %d" % run.combat.enemies.size() if wave_progress() >= 1.0 else "鼠潮 %d%% · 余鼠 %d" % [roundi(wave_progress() * 100), run.combat.enemies.size()]
		if run.paused: status = "暂停 · " + status
	return "第 %02d / 08 关 · %s" % [run.state.wave, status]

func draw_wave_progress() -> void:
	var bar := Rect2(948, 687, 300, 5)
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
	modal_shade.visible = confirm.visible or restart.visible
	start_button.disabled = phase != "prepare"
	start_button.text = "开始鼠潮  →" if phase == "prepare" else {"battle":"守卫进行中", "recipe":"请先选择食谱", "won":"守卫完成", "lost":"守卫结束"}.get(phase, "")
	pause_button.disabled = phase != "battle"
	pause_button.text = "继续" if run.paused else "暂停"
	pause_button.tooltip_text = "暂停时可查看信息，不能执行战斗操作。"
	speed_button.text = "%.0f× 速度" % run.speed
	repair_button.disabled = phase != "prepare" or run.state.repaired or run.state.coins < run.data.rules.repair_cost
	repair_button.text = "本关已维修" if run.state.repaired else "维修 · %d 金" % run.data.rules.repair_cost
	repair_button.tooltip_text = "仅准备阶段可用" if phase != "prepare" else ("本关维修次数已用完" if run.state.repaired else ("金币不足" if run.state.coins < run.data.rules.repair_cost else "恢复场上美食 30% 最大生命；每个准备阶段一次。"))
	var panel_name: String = {"recipe":"食谱", "prepare":"小铺", "battle":"食谱", "won":"战报", "lost":"战报"}.get(phase, "面板")
	toggle_button.text = ("收起" if panel_open else "打开") + panel_name
	shovel_button.set_pressed_no_signal(shovel)
	for index: int in range(cards.get_child_count()):
		var id: String = run.state.cards.keys()[index]
		var card: Button = cards.get_child(index)
		card.set_pressed_no_signal(id == selected)
		var remaining: float = run.state.cooldowns.get(id,0.0)
		var status: Label = card.get_node("Status")
		status.text = card_status(id)
		status.add_theme_color_override("font_color", GameTheme.GOLD if remaining > 0 and phase == "battle" else (GameTheme.DANGER if phase == "battle" and run.state.heat < run.data.foods[id].stats.cost else GameTheme.ACCENT))
		var cooldown: ColorRect = card.get_node("Cooldown")
		cooldown.visible = phase == "battle" and remaining > 0
		cooldown.size.x = 94.0 * clampf(remaining / run.data.foods[id].stats.cooldown, 0, 1)
	phase_label.text = "第 %02d / 08 关    ·    %s" % [run.state.wave, "已暂停" if run.paused else {"prepare":"准备营业", "battle":"鼠潮来袭", "recipe":"灵感时刻", "won":"守卫成功", "lost":"粮仓失守"}.get(phase, "")]
	context_title.text = {"prepare":"布好阵，再开战", "battle":"守住每一条路", "recipe":"为阵容加点灵感", "won":"热气未散，天已亮", "lost":"下一夜，会更好"}.get(phase, "")
	context_body.text = {"prepare":"在小铺购买美食。\n点击场上美食，再点目标格移动或交换。\n开战后消耗热量放置。", "battle":"美食向右攻击，鼠群向左来袭。\n留意空路，及时补上防线。", "recipe":"从右侧选一道食谱。\n效果立即生效，并持续到本局结束。", "won":"你守住了整个夜晚。\n查看右侧战报，再尝试不同的美食搭配。", "lost":"别让空路暴露在鼠群面前。\n试试生产、输出与守卫的组合。"}.get(phase, "")
	if run.paused:
		context_title.text = "稍歇片刻"
		context_body.text = "战斗与热量恢复已暂停。\n可以查看美食信息；点击「继续」返回守卫。"
	elif shovel:
		context_title.text = "腾出一个位置"
		context_body.text = "点击场上美食进行铲除。\n不返还热量。\n右键或 Esc 取消。"
	elif move_from.x >= 0:
		context_title.text = "选择新的位置"
		context_body.text = "点击目标格移动美食。\n目标已有美食时交换位置，生命保持不变。"
	elif not selected.is_empty():
		context_title.text = run.data.foods[selected].title
		context_body.text = "%s · ★%d\n%d 热量 / 放置\n%s" % [FOOD_ROLES.get(selected,"美食"), run.state.star(selected),run.data.foods[selected].stats.cost, "开战后点击格子放置。" if phase == "prepare" else "点击空格放置，右键取消。"]

func card_status(id: String) -> String:
	if run.state.phase == "prepare": return "开战后放置"
	if run.state.phase in ["won", "lost"]: return "本局已结束"
	if run.state.phase != "battle": return "等待下一关"
	if run.paused: return "已暂停"
	var remaining: float = run.state.cooldowns.get(id,0.0)
	if remaining > 0: return "冷却 %.1f 秒" % remaining
	if run.state.heat < run.data.foods[id].stats.cost: return "热量不足"
	return "已选中 · 可放置" if selected == id else "可放置"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
	if debug_enabled and event.is_action_pressed("debug_panel"): debug_window.popup_centered()
	if event.is_action_pressed("board_select"):
		if confirm.visible or restart.visible: return
		if panel.visible and PANEL_RECT.has_point(event.position): return
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
	draw_style_box(panel_style, Rect2(24, 12, 1232, 100))
	text_at(Vector2(38, 32), "热量 / HEAT", GameTheme.MUTED, 11)
	text_at(Vector2(38, 92), "粮仓 %d/10   金 %d" % [run.state.pantry,run.state.coins], GameTheme.TEXT, 13)
	draw_line(Vector2(178,30),Vector2(178,94),GameTheme.BORDER)
	text_at(Vector2(554, 138), "右键 / Esc  取消选择", GameTheme.MUTED, 12)
	if panel.visible: draw_style_box(panel_style, PANEL_RECT)
	draw_circle(Vector2(31,165),3,GameTheme.ACCENT)
	draw_wave_progress()

func draw_kitchen() -> void:
	draw_rect(Rect2(0,0,1280,720), GameTheme.BG)
	# Quiet bistro surfaces frame the board without competing with the actors.
	draw_style_box(GameTheme.box(Color("18292b"), 24), Rect2(24,180,270,444))
	text_at(Vector2(42, 217), "M I D N I G H T   K I T C H E N", GameTheme.MUTED, 10)
	text_at(Vector2(40, 272), "深夜食堂", GameTheme.TEXT, 40)
	text_at(Vector2(42, 298), "鼠 潮 来 袭", GameTheme.GOLD, 14)
	draw_line(Vector2(42,352),Vector2(272,352),GameTheme.BORDER)
	draw_line(Vector2(42,557),Vector2(272,557),GameTheme.BORDER)
	text_at(Vector2(42,583), "粮仓耐久", GameTheme.MUTED, 12)
	for index: int in range(10):
		var color: Color = GameTheme.ACCENT if run.state.pantry > 3 else GameTheme.DANGER
		draw_style_box(GameTheme.box(color if index < run.state.pantry else GameTheme.RAISED, 2), Rect2(42 + index * 23,596,18,4))
	draw_style_box(GameTheme.box(Color("0b1719"), 16), Rect2(340,174,582,452))
	draw_style_box(GameTheme.box(Color("51625a"), 12), Rect2(344,172,574,450))
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
	if panel.visible and PANEL_RECT.has_point(pointer): return {}
	var cell: Vector2i = projection.cell_at(pointer)
	if cell.x < 0: return {}
	return run.board.at(cell.y, cell.x)

func update_inspector() -> void:
	var unit: Dictionary = hovered_unit()
	inspect.text = ""
	panel.visible = panel_open
	inspect.position = Vector2(32,640)
	if not unit.is_empty():
		inspect.text = "%s ★%d   生命 %.0f / %.0f   伤害 %.1f · 间隔 %.2f秒 · 射程 %.1f格%s" % [run.data.foods[unit.id].title,run.state.star(unit.id),unit.hp,run.board.max_hp(unit.id),run.recipes.damage(unit),run.recipes.interval(unit),run.recipes.reach(unit.id)," · 面粉影响" if unit.flour > 0 else ""]
	elif debug_enabled and run.state.phase == "battle":
		inspect.text = "F3 开发面板 · 各行压力"
		for row: int in range(RunState.ROWS):
			var pressure: float = 0.0
			for enemy: Dictionary in run.combat.enemies:
				if enemy.row == row: pressure += enemy.hp
			inspect.text += " %d:%.0f" % [row+1,pressure]

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: pointer = event.position
