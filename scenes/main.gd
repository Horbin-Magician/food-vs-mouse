extends Node2D

const ORIGIN: Vector2 = Vector2(120, 150)
const CELL: Vector2 = Vector2(96, 78)
var run: RunController = RunController.new()
var selected: String = ""
var tile_styles: Array[StyleBoxFlat] = []
var pointer: Vector2 = Vector2(-1,-1)
var move_from: Vector2i = Vector2i(-1, -1)
var shovel: bool = false
var pending_remove: Vector2i
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
var colors: Dictionary = {"bun": Color("f4d8a5"), "toast": Color("d99954"), "pudding": Color("f4b558"), "tea": Color("85dbe9"), "pepper": Color("ef776b"), "popcorn": Color("f8e6a4"), "noodles": Color("deb3ef"), "garlic": Color("b1d987")}

func _ready() -> void:
	tile_styles = [tile_style(Color("2e4050")),tile_style(Color("283948"))]
	run.persistence = true
	debug_enabled = OS.is_debug_build() and "--dev" in OS.get_cmdline_user_args()
	if "--qa" in OS.get_cmdline_user_args() or "--qa-test" in OS.get_cmdline_user_args():
		run.saves.folder = "user://qa_automated/" if "--qa-test" in OS.get_cmdline_user_args() else "user://qa_visual/"
		DirAccess.make_dir_recursive_absolute(run.saves.folder)
	sound = SoundService.new()
	add_child(sound)
	RenderingServer.set_default_clear_color(Color("151e2c"))
	header = label(Vector2(30, 20), 24)
	notice = label(Vector2(30, 105), 18)
	button("开始鼠潮", Vector2(920, 25), func() -> void: run.start(); rebuild())
	button("暂停 / 继续", Vector2(1040, 25), func() -> void:
		if run.state.phase == "battle": run.paused = not run.paused)
	button("1× / 2×", Vector2(1170, 25), func() -> void: run.speed = 3.0 - run.speed)
	button("全场维修 · 4 金", Vector2(920, 75), func() -> void: report(run.board.repair()))
	button("铲除", Vector2(1080, 75), func() -> void: shovel = not shovel; selected = "")
	button("重新开局", Vector2(1160, 75), func() -> void: restart.popup_centered())
	cards = HBoxContainer.new()
	cards.position = Vector2(30, 580)
	cards.add_theme_constant_override("separation", 8)
	add_child(cards)
	panel = VBoxContainer.new()
	panel.position = Vector2(940, 155)
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
	inspect = label(Vector2(940,475),14)
	tutorial = label(Vector2(30,695),15)
	tutorial_skip = button("跳过引导",Vector2(1150,690),func() -> void: tutorial_step = mini(3,tutorial_step+1))
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
	var title: Label = Label.new()
	title.text = {"recipe":"食谱三选一","prepare":"打烊小铺","battle":"正在守卫粮仓","won":"胜利","lost":"失败"}.get(run.state.phase,"")
	panel.add_child(title)
	if run.state.phase == "recipe":
		for id: String in run.state.choices:
			panel_button(run.data.recipes[id].title,func() -> void: report(run.choose_recipe(id)),run.data.recipes[id].stats.description)
		if run.state.choices.is_empty(): panel_button("食谱已收集完 · 继续",func() -> void: run.skip_recipe())
	elif run.state.phase == "prepare":
		for index: int in range(run.state.offers.size()):
			var offer: Dictionary = run.state.offers[index]
			var sold: bool = offer.id.is_empty() or offer.bought or run.state.cards.get(offer.id,0) >= 6
			var item: Button = panel_button("售罄" if sold else "%s · %d 金" % [run.data.foods[offer.id].title,run.data.foods[offer.id].stats.price],func() -> void: report(run.shop.buy(index)))
			item.disabled = sold
		panel_button("刷新 · 2 金（%d/2）" % run.state.refreshes,func() -> void: report(run.shop.refresh()))
	if run.state.phase in ["won","lost"]:
		var summary: Label = Label.new()
		summary.text = "今夜战报\n战斗 %.1f 分钟\n击杀 %d · 漏粮 %d\n美食阵亡 %d" % [run.state.elapsed/60.0,run.state.metrics.kills,run.state.metrics.leaks,run.state.metrics.deaths]
		panel.add_child(summary)
	var owned: Label = Label.new()
	owned.text = "已选食谱："
	for id: String in run.state.recipes: owned.text += "\n" + run.data.recipes[id].title
	owned.add_theme_font_size_override("font_size",16)
	panel.add_child(owned)
	for id: String in run.state.cards:
		var node: Button = Button.new()
		var stats: Dictionary = run.data.foods[id].stats
		node.text = "%s ★%d\n热量 %d · %d/6" % [run.data.foods[id].title, run.state.star(id), stats.cost, run.state.cards[id]]
		node.custom_minimum_size = Vector2(142, 80)
		node.tooltip_text = "生命 %.0f · 伤害 %.0f\n间隔 %.2f 秒 · 射程 %.1f 格\n放置冷却 %.0f 秒" % [run.board.max_hp(id), stats.damage * run.data.rules.star_hp[run.state.star(id) - 1], stats.interval, run.recipes.reach(id), stats.cooldown]
		node.pressed.connect(func() -> void: selected = id; shovel = false; move_from = Vector2i(-1,-1))
		cards.add_child(node)

func _process(delta: float) -> void:
	run.advance(delta)
	header.text = "深夜食堂   |   第 %d 关   粮仓 %d/10   金币 %d   热量 %d/350   %s %s" % [run.state.wave, run.state.pantry, run.state.coins, run.state.heat, "暂停" if run.paused else {"prepare":"准备","battle":"战斗","recipe":"选谱","won":"胜利","lost":"失败"}.get(run.state.phase,run.state.phase), "%.0f×" % run.speed]
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
	tutorial.text = tips[tutorial_step] if tutorial_step < 3 and run.state.wave == 1 else "战斗中退出将回到本关开战前；准备操作自动保存。"
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
	if debug_enabled and event.is_action_pressed("debug_panel"): debug_window.popup_centered()
	if event.is_action_pressed("board_select"):
		var local: Vector2 = event.position - ORIGIN
		var col: int = floori(local.x / CELL.x)
		var row: int = floori(local.y / CELL.y)
		if col < 0 or col >= 8 or row < 0 or row >= 5: return
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
	for row: int in range(5):
		text_at(ORIGIN + Vector2(-75, row * CELL.y + 45), "粮仓 ◀", Color("c6d2df"))
		for col: int in range(8):
			var rect: Rect2 = Rect2(ORIGIN + Vector2(col,row) * CELL, CELL - Vector2(3,3))
			draw_style_box(tile_styles[(row + col) % 2], rect)
			if move_from == Vector2i(col,row): draw_rect(rect, Color("f8d482"),false,3)
	var hovered: Dictionary = hovered_unit()
	if not hovered.is_empty():
		var range_start: Vector2 = ORIGIN + Vector2(hovered.col*96+48,hovered.row*78)
		draw_rect(Rect2(range_start,Vector2(minf(run.recipes.reach(hovered.id)*96,768-hovered.col*96-48),75)),Color(0.5,0.85,0.9,0.12))
	for unit: Dictionary in run.state.units:
		var pos: Vector2 = ORIGIN + Vector2(unit.col * CELL.x + 48, unit.row * CELL.y + 39)
		var color: Color = colors.get(unit.id,Color("81c9af"))
		draw_circle(pos, 25, Color.WHITE if unit.flash > 0 else color)
		match unit.id:
			"toast": draw_rect(Rect2(pos-Vector2(24,22),Vector2(48,44)),color)
			"tea":
				draw_rect(Rect2(pos-Vector2(17,25),Vector2(34,49)),color)
				draw_line(pos+Vector2(8,-18),pos+Vector2(15,-35),Color("effaff"),3)
			"popcorn":
				for offset: Vector2 in [Vector2(-16,-18),Vector2(0,-25),Vector2(16,-18)]: draw_circle(pos+offset,11,Color("fff2c2"))
			"noodles": draw_arc(pos+Vector2(0,-8),23,0,PI,16,Color("fff1cc"),5)
			"pepper": draw_line(pos+Vector2(3,-22),pos+Vector2(13,-34),Color("a8d77e"),5)
		draw_circle(pos + Vector2(-8,-3), 2,Color("302e34"))
		draw_circle(pos + Vector2(8,-3), 2,Color("302e34"))
		text_at(pos + Vector2(-28,8), run.data.foods[unit.id].title, Color("302e34"),13)
		draw_rect(Rect2(pos + Vector2(-30,29),Vector2(60,5)),Color("633f46"))
		draw_rect(Rect2(pos + Vector2(-30,29),Vector2(60 * unit.hp / run.board.max_hp(unit.id),5)),Color("ff817d") if unit.hp / run.board.max_hp(unit.id) < 0.25 else Color("7fd29b"))
	for enemy: Dictionary in run.combat.enemies:
		var pos: Vector2 = ORIGIN + Vector2(enemy.x,enemy.row * CELL.y + 39)
		draw_circle(pos + Vector2(-12,-17),10,Color("acacbb"))
		draw_circle(pos + Vector2(12,-17),10,Color("acacbb"))
		draw_circle(pos,32 if enemy.id == "boss" else (27 if enemy.id == "elite" else 20),Color.WHITE if enemy.flash > 0 else Color("8d91a3"))
		match enemy.id:
			"lid", "elite": draw_arc(pos+Vector2(0,-16),23,PI,TAU,16,Color("d4e3df"),8)
			"boss":
				draw_rect(Rect2(pos+Vector2(-24,-39),Vector2(48,18)),Color("faf4df"))
				for dx: int in [-16,0,16]: draw_circle(pos+Vector2(dx,-41),12,Color("faf4df"))
			"drummer": draw_circle(pos+Vector2(0,15),13,Color("db9c76"))
			"flour": draw_rect(Rect2(pos+Vector2(-13,5),Vector2(26,20)),Color("e3dbc7"))
			"gnawer": draw_line(pos+Vector2(-17,13),pos+Vector2(17,13),Color("eee3cc"),5)
			"runner": draw_line(pos+Vector2(8,19),pos+Vector2(29,22),Color("edb068"),5)
		if enemy.slow_time > 0: text_at(pos + Vector2(-22,-28),"❄",Color("83e4f5"))
		if enemy.burn_time > 0: text_at(pos + Vector2(7,-28),"♨",Color("ffab69"))
		text_at(pos + Vector2(-19,5),run.data.enemies[enemy.id].title,Color("202431"),12)
		draw_rect(Rect2(pos + Vector2(-23,24),Vector2(46 * enemy.hp / enemy.max_hp,4)),Color("ed8796"))
	for shot: Dictionary in run.combat.projectiles:
		draw_circle(ORIGIN + Vector2(shot.x,shot.row * CELL.y + 39),5,Color("fff1b5"))
	if run.state.phase == "battle":
		for i: int in range(run.director.cursor,mini(run.director.cursor + 3,run.director.events.size())):
			var event: Dictionary = run.director.events[i]
			if event.time - run.director.elapsed <= 5:
				text_at(ORIGIN + Vector2(775,event.row * CELL.y + 40),"◀ 来袭",Color("ffbe75"))
	text_at(Vector2(30,555),"选中：%s   %s   鼠潮 %d/%d · 场上 %d" % [run.data.foods[selected].title if selected != "" else "无", "铲除模式" if shovel else "右键 / Esc 取消", run.director.cursor,run.director.events.size(),run.combat.enemies.size()])
	for i: int in range(run.state.cards.size()):
		var id: String = run.state.cards.keys()[i]
		text_at(Vector2(35 + i * 150,682),"冷却 %.1f 秒" % run.state.cooldowns.get(id,0.0),Color("a9bac9"),14)

func tile_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style

func panel_button(title: String, action: Callable, tip: String = "") -> Button:
	var node: Button = Button.new()
	node.text = title
	node.tooltip_text = tip
	node.custom_minimum_size = Vector2(280,40)
	node.pressed.connect(action)
	panel.add_child(node)
	return node

func hovered_unit() -> Dictionary:
	var local: Vector2 = pointer-ORIGIN
	if local.x < 0 or local.y < 0 or local.x >= 768 or local.y >= 390: return {}
	return run.board.at(floori(local.y/78),floori(local.x/96))

func update_inspector() -> void:
	var unit: Dictionary = hovered_unit()
	inspect.text = ""
	panel.visible = unit.is_empty()
	inspect.position = Vector2(940,155) if not unit.is_empty() else Vector2(940,540)
	if not unit.is_empty():
		inspect.text = "%s ★%d\n生命 %.0f / %.0f\n伤害 %.1f · 间隔 %.2f秒\n射程 %.1f格%s" % [run.data.foods[unit.id].title,run.state.star(unit.id),unit.hp,run.board.max_hp(unit.id),run.recipes.damage(unit),run.recipes.interval(unit),run.recipes.reach(unit.id)," · 面粉影响" if unit.flour > 0 else ""]
	elif debug_enabled and run.state.phase == "battle":
		inspect.text = "F3 开发面板 · 各行压力"
		for row: int in range(5):
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
