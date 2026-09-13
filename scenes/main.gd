extends Node2D

const ORIGIN: Vector2 = Vector2(120, 150)
const CELL: Vector2 = Vector2(96, 78)
var run: RunController = RunController.new()
var selected: String = ""
var move_from: Vector2i = Vector2i(-1, -1)
var shovel: bool = false
var pending_remove: Vector2i
var header: Label
var notice: Label
var cards: HBoxContainer
var panel: VBoxContainer
var confirm: ConfirmationDialog
var refresh_timer: float = 0.0
var colors: Dictionary = {"bun": Color("f4d8a5"), "toast": Color("d99954"), "pudding": Color("f4b558"), "tea": Color("85dbe9"), "pepper": Color("ef776b"), "popcorn": Color("f8e6a4"), "noodles": Color("deb3ef"), "garlic": Color("b1d987")}

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("151e2c"))
	header = label(Vector2(30, 20), 24)
	notice = label(Vector2(30, 105), 18)
	button("开始鼠潮", Vector2(920, 25), func() -> void: run.start(); rebuild())
	button("暂停 / 继续", Vector2(1040, 25), func() -> void:
		if run.state.phase == "battle": run.paused = not run.paused)
	button("1× / 2×", Vector2(1170, 25), func() -> void: run.speed = 3.0 - run.speed)
	button("全场维修 · 4 金", Vector2(920, 75), func() -> void: report(run.board.repair()))
	button("铲除", Vector2(1080, 75), func() -> void: shovel = not shovel; selected = "")
	button("重新开局", Vector2(1160, 75), func() -> void: run.new_run(int(Time.get_unix_time_from_system())); rebuild())
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
	run.changed.connect(rebuild)
	run.new_run(int(Time.get_unix_time_from_system()))
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
	title.text = "食谱三选一" if run.state.phase == "recipe" else "打烊小铺"
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
		node.tooltip_text = "生命 %.0f · 伤害 %.0f\n间隔 %.2f 秒 · 射程 %.1f 格\n放置冷却 %.0f 秒" % [run.board.max_hp(id), stats.damage * run.data.rules.star_hp[run.state.star(id) - 1], stats.interval, stats.reach, stats.cooldown]
		node.pressed.connect(func() -> void: selected = id; shovel = false; move_from = Vector2i(-1,-1))
		cards.add_child(node)

func _process(delta: float) -> void:
	run.advance(delta)
	header.text = "深夜食堂   |   第 %d 关   粮仓 %d/10   金币 %d   热量 %d/350   %s %s" % [run.state.wave, run.state.pantry, run.state.coins, run.state.heat, "暂停" if run.paused else run.state.phase, "%.0f×" % run.speed]
	notice.text = run.message
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		selected = ""
		shovel = false
		move_from = Vector2i(-1,-1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_mouse_position() - ORIGIN
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
			draw_style_box(tile_style(Color("2e4050") if (row + col) % 2 == 0 else Color("283948")), rect)
			if move_from == Vector2i(col,row): draw_rect(rect, Color("f8d482"),false,3)
	for unit: Dictionary in run.state.units:
		var pos: Vector2 = ORIGIN + Vector2(unit.col * CELL.x + 48, unit.row * CELL.y + 39)
		var color: Color = colors.get(unit.id,Color("81c9af"))
		draw_circle(pos, 25, Color.WHITE if unit.flash > 0 else color)
		draw_circle(pos + Vector2(-8,-3), 2,Color("302e34"))
		draw_circle(pos + Vector2(8,-3), 2,Color("302e34"))
		text_at(pos + Vector2(-28,8), run.data.foods[unit.id].title, Color("302e34"),13)
		draw_rect(Rect2(pos + Vector2(-30,29),Vector2(60,5)),Color("633f46"))
		draw_rect(Rect2(pos + Vector2(-30,29),Vector2(60 * unit.hp / run.board.max_hp(unit.id),5)),Color("7fd29b"))
	for enemy: Dictionary in run.combat.enemies:
		var pos: Vector2 = ORIGIN + Vector2(enemy.x,enemy.row * CELL.y + 39)
		draw_circle(pos + Vector2(-12,-17),10,Color("acacbb"))
		draw_circle(pos + Vector2(12,-17),10,Color("acacbb"))
		draw_circle(pos,32 if enemy.id == "boss" else (27 if enemy.id == "elite" else 20),Color.WHITE if enemy.flash > 0 else Color("8d91a3"))
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
