extends Node2D

var projection: BoardProjection = BoardProjection.new()
var art: ArtCatalog = ArtCatalog.new()
var animator: UnitAnimator = UnitAnimator.new()
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
	panel_style = tile_style(Color("132524ed"))
	panel_style.border_color = Color("a47a49")
	panel_style.set_border_width_all(1)
	run.persistence = true
	debug_enabled = OS.is_debug_build() and "--dev" in OS.get_cmdline_user_args()
	if "--qa" in OS.get_cmdline_user_args() or "--qa-test" in OS.get_cmdline_user_args():
		run.saves.folder = "user://qa_automated/" if "--qa-test" in OS.get_cmdline_user_args() else "user://qa_visual/"
		DirAccess.make_dir_recursive_absolute(run.saves.folder)
	sound = SoundService.new()
	add_child(sound)
	RenderingServer.set_default_clear_color(Color("151e2c"))
	heat_label = label(Vector2(34, 25), 29)
	header = label(Vector2(930, 652), 14)
	header.tooltip_text = "进度表示计划鼠潮的生成比例；全部生成后仍需清除剩余敌人。"
	notice = label(Vector2(32, 145), 16)
	notice.size = Vector2(1180, 26)
	notice.clip_text = true
	button("开始鼠潮", Vector2(30, 117), func() -> void: run.start(); rebuild())
	button("暂停 / 继续", Vector2(154, 117), func() -> void:
		if run.state.phase == "battle": run.paused = not run.paused)
	button("1× / 2×", Vector2(290, 117), func() -> void: run.speed = 3.0 - run.speed)
	button("全场维修 · 4 金", Vector2(390, 117), func() -> void: report(run.board.repair()))
	button("小铺 / 食谱", Vector2(1020, 117), func() -> void: panel_open = not panel_open)
	shovel_button = button("铲除", Vector2(1150, 20), func() -> void:
		shovel = not shovel
		selected = ""
		move_from = Vector2i(-1,-1))
	shovel_button.custom_minimum_size = Vector2(98, 82)
	shovel_button.icon = preload("res://assets/ui/spatula.svg")
	shovel_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	shovel_button.expand_icon = true
	shovel_button.add_theme_constant_override("icon_max_width", 40)
	shovel_button.tooltip_text = "选中锅铲后点击美食铲除；右键或 Esc 取消。战斗中需确认，无返还。"
	button("重新开局", Vector2(1160, 117), func() -> void: restart.popup_centered())
	cards = HBoxContainer.new()
	cards.position = Vector2(190, 18)
	cards.add_theme_constant_override("separation", 6)
	add_child(cards)
	panel = VBoxContainer.new()
	panel.position = Vector2(924, 196)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	confirm = ConfirmationDialog.new()
	confirm.dialog_text = "战斗中铲除不返还热量，确认移除？"
	confirm.confirmed.connect(func() -> void: report(run.board.remove(pending_remove.y, pending_remove.x, run.paused, true)))
	add_child(confirm)
	restart = ConfirmationDialog.new()
	restart.dialog_text = "结束当前局并重新开局？本局达成的解锁将结算。"
	restart.confirmed.connect(func() -> void:
		run.new_run(int(Time.get_unix_time_from_system()))
		selected = ""
		tutorial_step = 0
		rebuild())
	add_child(restart)
	inspect = label(Vector2.ZERO,15)
	inspect.visible = false
	tutorial = label(Vector2.ZERO,14)
	tutorial.visible = false
	tutorial_skip = button("跳过引导",Vector2(1150,145),func() -> void: tutorial_step = mini(3,tutorial_step+1))
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
	add_child(node)
	return node

func button(title: String, position_value: Vector2, action: Callable) -> Button:
	var node: Button = Button.new()
	node.text = title
	node.position = position_value
	node.pressed.connect(action)
	add_child(node)
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
	var title: Label = Label.new()
	title.text = {"recipe":"食谱三选一","prepare":"打烊小铺","battle":"正在守卫粮仓","won":"胜利","lost":"失败"}.get(run.state.phase,"")
	panel.add_child(title)
	if run.state.phase == "recipe":
		for id: String in run.state.choices:
			var choice: Button = panel_button(run.data.recipes[id].title,func() -> void: report(run.choose_recipe(id)),run.data.recipes[id].stats.description)
			decorate_button(choice, art.recipe(id), 42)
		if run.state.choices.is_empty(): panel_button("食谱已收集完 · 继续",func() -> void: run.skip_recipe())
	elif run.state.phase == "prepare":
		for index: int in range(run.state.offers.size()):
			var offer: Dictionary = run.state.offers[index]
			var sold: bool = offer.id.is_empty() or offer.bought or run.state.cards.get(offer.id,0) >= 6
			var item: Button = panel_button("售罄" if sold else "%s · %d 金" % [run.data.foods[offer.id].title,run.data.foods[offer.id].stats.price],func() -> void: report(run.shop.buy(index)))
			item.disabled = sold
			if not sold: decorate_button(item, art.food(offer.id), 38)
		panel_button("刷新 · 2 金（%d/2）" % run.state.refreshes,func() -> void: report(run.shop.refresh()))
	if run.state.phase in ["won","lost"]:
		var summary: Label = Label.new()
		summary.text = "今夜战报\n战斗 %.1f 分钟\n击杀 %d · 漏粮 %d\n美食阵亡 %d" % [run.state.elapsed/60.0,run.state.metrics.kills,run.state.metrics.leaks,run.state.metrics.deaths]
		panel.add_child(summary)
	var owned: Label = Label.new()
	owned.text = "已选食谱 %d · 悬停查看" % run.state.recipes.size()
	for id: String in run.state.recipes: owned.tooltip_text += run.data.recipes[id].title + "\n"
	owned.add_theme_font_size_override("font_size",16)
	panel.add_child(owned)
	for id: String in run.state.cards:
		var node: Button = Button.new()
		var stats: Dictionary = run.data.foods[id].stats
		var card_text: String = "%s ★%d\n%d 热量 · %d/6" % [run.data.foods[id].title, run.state.star(id), stats.cost, run.state.cards[id]]
		node.custom_minimum_size = Vector2(110, 78)
		node.add_theme_font_size_override("font_size", 14)
		decorate_button(node, art.food(id), 32)
		node.icon = null
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = art.food(id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(37,2)
		portrait.size = Vector2(36,36)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(portrait)
		var caption: Label = Label.new()
		caption.text = card_text
		caption.position = Vector2(0,38)
		caption.size = Vector2(110,38)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size",13)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(caption)
		node.tooltip_text = "生命 %.0f · 伤害 %.0f\n间隔 %.2f 秒 · 射程 %.1f 格\n放置冷却 %.0f 秒" % [run.board.max_hp(id), stats.damage * run.data.rules.star_hp[run.state.star(id) - 1], stats.interval, run.recipes.reach(id), stats.cooldown]
		node.pressed.connect(func() -> void: selected = id; shovel = false; move_from = Vector2i(-1,-1))
		cards.add_child(node)
	cards.position.x = 190 + (922 - (run.state.cards.size() * 116 - 6)) * 0.5

func _process(delta: float) -> void:
	animator.bind(run, projection)
	var before: float = run.state.elapsed
	run.advance(delta)
	var visual_delta: float = 0.0
	if not run.paused:
		visual_delta = run.state.elapsed - before if run.state.phase == "battle" else (minf(delta, 0.25) if run.state.phase == "prepare" else 0.0)
	animator.advance(visual_delta, run.combat.enemies)
	heat_label.text = "热量 %d\n" % run.state.heat
	heat_label.tooltip_text = "每关上限 350；每秒恢复 5，准备阶段不恢复。"
	header.text = wave_status()
	shovel_button.modulate = Color("ffd38c") if shovel else Color.WHITE
	for index: int in range(cards.get_child_count()):
		cards.get_child(index).modulate = Color("ffd38c") if run.state.cards.keys()[index] == selected else Color.WHITE
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
	notice.size.x = 1100 if tutorial_skip.visible else 1180
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
	var bar: Rect2 = Rect2(930, 680, 316, 14)
	var frame: StyleBoxFlat = tile_style(Color("142c32"))
	frame.set_corner_radius_all(7)
	frame.border_color = Color("b99c69")
	frame.set_border_width_all(2)
	draw_style_box(frame, bar.grow(3))
	var fill_width: float = bar.size.x * wave_progress()
	if fill_width > 0:
		draw_rect(Rect2(bar.position,Vector2(fill_width,bar.size.y)),Color("68bcc2"))
		draw_rect(Rect2(bar.position,Vector2(fill_width,4)),Color("c3eeeb"))
	for index: int in range(1,8):
		var x: float = bar.position.x + bar.size.x * index / 8.0
		draw_line(Vector2(x,bar.position.y + 2),Vector2(x,bar.end.y - 2),Color("254a5266"),2)
	draw_line(Vector2(bar.end.x,bar.position.y - 11),Vector2(bar.end.x,bar.end.y + 2),Color("e5ce9e"),2)
	draw_colored_polygon(PackedVector2Array([Vector2(bar.end.x,bar.position.y-11),Vector2(bar.end.x-13,bar.position.y-11),Vector2(bar.end.x-10,bar.position.y-3),Vector2(bar.end.x,bar.position.y-3)]),Color("e2a36e"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
	if debug_enabled and event.is_action_pressed("debug_panel"): debug_window.popup_centered()
	if event.is_action_pressed("board_select"):
		if panel.visible and Rect2(910,180,346,426).has_point(event.position): return
		var cell: Vector2i = projection.cell_at(event.position)
		var col: int = cell.x
		var row: int = cell.y
		if col < 0 or col >= RunState.COLS or row < 0 or row >= RunState.ROWS: return
		if shovel:
			if run.state.phase == "battle" and not run.paused:
				pending_remove = Vector2i(col,row)
				confirm.popup_centered()
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
	draw_style_box(panel_style, Rect2(18, 12, 1244, 100))
	text_at(Vector2(34, 80), "粮仓 %d/10 · 金币 %d" % [run.state.pantry,run.state.coins], Color("f2dab2"), 14)
	text_at(Vector2(580, 138), "%s · %.0f×" % ["锅铲已选中" if shovel else (run.data.foods[selected].title if selected != "" else "选择美食 / 调整阵地"), run.speed], Color("f3dbb8"), 15)
	if panel.visible:
		draw_style_box(panel_style, Rect2(910, 180, 346, 426))
	draw_wave_progress()
	for i: int in range(run.state.cards.size()):
		var id: String = run.state.cards.keys()[i]
		var remaining: float = run.state.cooldowns.get(id,0.0)
		text_at(Vector2(cards.position.x + 8 + i * 116,107), "冷却 %.1fs" % remaining if remaining > 0 else "可放置", Color("f0cea0") if remaining > 0 else Color("a8d5b5"),12)

func draw_kitchen() -> void:
	draw_rect(Rect2(0,0,1280,720), Color("233c38"))
	# Flat backsplash and wooden worktop, aligned with the board and HUD.
	for y: int in range(3):
		for x: int in range(16):
			draw_rect(Rect2(x * 84 + 2, y * 62 + 2,80,58), Color("304e46"))
	draw_style_box(tile_style(Color("78543b")), Rect2(18,166,1244,458))
	for y: int in range(178,624,24):
		draw_line(Vector2(24,y),Vector2(1256,y),Color("8a624442"),1)
	draw_style_box(tile_style(Color("392e25")), Rect2(340,170,582,456))
	for row: int in range(RunState.ROWS):
		var center: Vector2 = projection.foot(-51,row) - Vector2(0,18)
		draw_circle(center,25,Color("d8c7a2"))
		draw_circle(center,20,Color("ede1c0"))
		draw_arc(center,17,0,TAU,32,Color("baa986"),2,true)
		var entry: Vector2 = projection.foot(RunState.BOARD_WIDTH + 44,row) - Vector2(16,40)
		draw_style_box(tile_style(Color("433e32")),Rect2(entry,Vector2(44,48)))
		text_at(entry + Vector2(10,32),"◀",Color("c5a779"),22)

func outline(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func draw_board() -> void:
	var edge: PackedVector2Array = projection.polygon(Rect2(Vector2.ZERO, BoardProjection.LOGICAL_SIZE))
	var front: PackedVector2Array = PackedVector2Array([edge[3], edge[2], edge[2] + Vector2(0, 8), edge[3] + Vector2(0, 8)])
	draw_colored_polygon(front, Color("102a29"))
	draw_colored_polygon(edge, Color("c8c59b"))
	outline(edge, Color("c5a56b85"), 1.5)
	var hover_cell: Vector2i = projection.cell_at(pointer)
	for row: int in range(RunState.ROWS):
		var exit_pos: Vector2 = projection.foot(-46, row)
		text_at(exit_pos + Vector2(-22, 0), "◀", Color("d6c6a0"), 18)
		for col: int in range(RunState.COLS):
			var tile: PackedVector2Array = projection.tiles[row * RunState.COLS + col]
			draw_colored_polygon(tile, Color("d7cdab") if (row + col) % 2 == 0 else Color("9fae89"))
			outline(tile, Color("f0e1b555"))
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

func decorate_button(node: Button, texture: Texture2D, width: int) -> void:
	node.icon = texture
	node.expand_icon = true
	node.add_theme_constant_override("icon_max_width", width)
	var normal: StyleBoxFlat = tile_style(Color("29413e"))
	normal.border_color = Color("a88652")
	normal.set_border_width_all(1)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	node.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("42615a")
	node.add_theme_stylebox_override("hover", hover)

func tile_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style

func panel_button(title: String, action: Callable, tip: String = "") -> Button:
	var node: Button = Button.new()
	node.text = title
	node.tooltip_text = tip
	node.custom_minimum_size = Vector2(308,40)
	node.pressed.connect(action)
	panel.add_child(node)
	return node

func hovered_unit() -> Dictionary:
	if panel.visible and Rect2(910,180,346,426).has_point(pointer): return {}
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
	add_child(debug_window)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: pointer = event.position
