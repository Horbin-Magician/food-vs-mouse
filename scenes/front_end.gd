extends Node

const GAME := preload("res://scenes/main.tscn")
var saves := SaveService.new()
var data := Catalog.new()
var art := ArtCatalog.new()
var game: Node2D
var page: Control
var notice: Label
var continue_button: Button
var overwrite: ConfirmationDialog
var showing_result: bool = false
var hub: CardHub
var sound: SoundService
var audio_settings: AudioSettings
var audio_button: Button
var current_page: String = "menu"
var quitting: bool = false

func _ready() -> void:
	get_viewport().gui_embed_subwindows = true
	if "--qa" in OS.get_cmdline_user_args() or "--qa-test" in OS.get_cmdline_user_args():
		saves.folder = "user://qa_automated/" if "--qa-test" in OS.get_cmdline_user_args() else "user://qa_visual/"
		DirAccess.make_dir_recursive_absolute(saves.folder)
	sound = SoundService.new()
	sound.settings_path = saves.folder.path_join("audio.cfg")
	add_child(sound)
	audio_settings = AudioSettings.new()
	add_child(audio_settings)
	audio_settings.setup(sound)
	audio_settings.menu_requested.connect(func() -> void: leave_settings("menu"))
	audio_settings.quit_requested.connect(func() -> void: leave_settings("quit"))
	var audio_layer := CanvasLayer.new()
	audio_layer.layer = 110
	add_child(audio_layer)
	audio_button = Button.new()
	audio_button.name = "SettingsButton"
	audio_button.text = "设置"
	audio_button.icon = preload("res://assets/ui/settings.svg")
	audio_button.add_theme_constant_override("icon_max_width", 20)
	audio_button.add_theme_constant_override("h_separation", 8)
	audio_button.size = Vector2(104, 38)
	audio_button.theme = GameTheme.create()
	audio_button.tooltip_text = "设置 / Esc · 声音与游戏选项"
	audio_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	audio_button.pressed.connect(open_settings)
	audio_layer.add_child(audio_button)
	show_menu()

func clear_page() -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.size = Vector2(1280, 720)
	page.theme = GameTheme.create()
	add_child(page)
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture = ArtCatalog.BACKGROUND
	background.size = page.size
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	var shade := ColorRect.new()
	shade.size = page.size
	shade.color = Color(0.025, 0.07, 0.055, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(shade)
	var surface := Panel.new()
	surface.position = Vector2(744, 84)
	surface.size = Vector2(452, 572)
	var surface_style := GameTheme.box(GameTheme.SURFACE, 20, GameTheme.BORDER)
	surface_style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	surface_style.shadow_size = 12
	surface.add_theme_stylebox_override("panel", surface_style)
	page.add_child(surface)
	divider(Vector2(792, 96), 356, GameTheme.GOLD)
	text_line("夜 间 限 定  /  MIDNIGHT KITCHEN", Vector2(84, 84), Vector2(610, 30), 15, GameTheme.GOLD)
	text_line("选好美食   →   布阵守夜   →   食谱构筑", Vector2(84, 650), Vector2(600, 28), 15, GameTheme.MUTED)

func divider(pos: Vector2, width: float, color: Color = GameTheme.BORDER) -> void:
	var line := ColorRect.new()
	line.position = pos
	line.size = Vector2(width, 2)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(line)

func result_stat(title: String, value: String, pos: Vector2, tint: Color = GameTheme.TEXT) -> void:
	var tile := Panel.new()
	tile.position = pos
	tile.size = Vector2(172, 82)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.BG, 10))
	page.add_child(tile)
	text_line(title, pos + Vector2(14, 9), Vector2(144, 22), 13, GameTheme.MUTED)
	text_line(value, pos + Vector2(14, 32), Vector2(144, 38), 28, tint)

func text_line(value: String, pos: Vector2, bounds: Vector2, font_size: int, color: Color = GameTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = bounds
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(label)
	return label

func action(title: String, pos: Vector2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.position = pos
	button.size = Vector2(356, 54)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void: sound.cue("ui_click"))
	button.pressed.connect(callback)
	if primary: GameTheme.primary(button)
	page.add_child(button)
	return button

func portrait(texture: Texture2D, pos: Vector2, bounds: Vector2) -> void:
	var view := TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.texture = texture
	view.position = pos
	view.size = bounds
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(view)

func show_menu() -> void:
	if audio_settings.visible: audio_settings.hide()
	sound.bind_run(null)
	sound.set_context("menu")
	audio_button.position = Vector2(1120, 20)
	audio_button.show()
	current_page = "menu"
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
	showing_result = false
	clear_page()
	text_line("深夜食堂", Vector2(80, 148), Vector2(640, 85), 66)
	text_line("鼠潮来袭", Vector2(84, 235), Vector2(580, 60), 38, GameTheme.GOLD)
	text_line("打烊之后，守住这一餐。", Vector2(88, 318), Vector2(580, 40), 22, GameTheme.MUTED)
	portrait(art.food_portrait("toast"), Vector2(90, 434), Vector2(170, 170))
	portrait(art.food_portrait("bun"), Vector2(250, 382), Vector2(260, 240))
	portrait(art.mouse("gray"), Vector2(500, 460), Vector2(160, 150))
	text_line("今夜，开张", Vector2(792, 124), Vector2(360, 48), 32)
	text_line("深夜厨房 · 五大关连续守卫 40 小关", Vector2(792, 186), Vector2(356, 36), 17, GameTheme.MUTED)
	var snapshot: Dictionary = saves.load_run(data)
	var load_error: String = saves.error
	var has_run: bool = not snapshot.is_empty()
	var resume_text: String = "暂无可继续的对局"
	var resume_hint: String = "开始一局后，会自动保存关前准备进度。"
	if has_run:
		var chapter: ChapterDef = data.chapters[snapshot.get("chapter_id", "kitchen_1")]
		var wave: int = int(snapshot.get("wave", 1))
		var overall: int = (chapter.order - 1) * 8 + wave
		resume_text = "继续 · %d-%d · 总 %02d/%d  →" % [chapter.order,wave,overall,data.scene_wave_count(snapshot.get("scene_id", "kitchen"))]
		resume_hint = "%s · 第 %d 大关：%s\n继续第 %d 小关开战前的准备进度。" % [data.scenes[snapshot.get("scene_id", "kitchen")].title,chapter.order,chapter.title,wave]
	continue_button = action(resume_text, Vector2(792, 246 if has_run else 350), continue_run, has_run)
	continue_button.name = "ContinueRun"
	continue_button.disabled = snapshot.is_empty()
	continue_button.tooltip_text = resume_hint
	var new_button := action("新的一局 · 选择场景与阵容 →", Vector2(792, 350 if has_run else 246), request_new, not has_run)
	new_button.name = "NewRun"
	text_line("回到本关开战前，已赚灵感保留。" if has_run else "选 1～5 种美食，搭配你的守卫阵容。", Vector2(796, 307), Vector2(350, 28), 14, GameTheme.MUTED)
	text_line("结束旧局，重新搭配美食与难度。" if has_run else "关前自动保存，随时回来接着守夜。", Vector2(796, 411), Vector2(350, 28), 14, GameTheme.MUTED)
	var collection := action("美食卡册  ·  购卡与强化", Vector2(792, 450), func() -> void: show_hub("shop"))
	collection.name = "OpenCardHub"
	text_line("用灵感添新菜，让美食永久成长。", Vector2(796, 511), Vector2(350, 26), 14, GameTheme.MUTED)
	var quit_button := action("打烊离开", Vector2(792, 558), quit_game)
	quit_button.size.y = 40
	quit_button.add_theme_font_size_override("font_size", 15)
	notice = text_line(load_error if not load_error.is_empty() else "鼠群从右侧来袭，守住左侧粮仓。", Vector2(792, 608), Vector2(356, 40), 13, GameTheme.DANGER if not load_error.is_empty() else GameTheme.MUTED)
	overwrite = ConfirmationDialog.new()
	overwrite.title = "开始新的一局？"
	overwrite.dialog_text = "现有守卫进度将结束，阵地和热量将重置。\n已赚灵感与食谱解锁保留，卡店刷新。"
	overwrite.ok_button_text = "开始新局"
	overwrite.cancel_button_text = "返回"
	overwrite.confirmed.connect(prepare_new)
	overwrite.canceled.connect(func() -> void: sound.cue("ui_cancel"))
	page.add_child(overwrite)

func controller() -> RunController:
	var run := RunController.new()
	run.saves = saves
	run.persistence = true
	return run

func continue_run() -> void:
	if is_instance_valid(game): return
	var run := controller()
	if not run.resume_run():
		sound.cue("ui_error")
		notice.text = run.message
		return
	enter_game(run)

func request_new() -> void:
	if not saves.load_run(data).is_empty():
		overwrite.popup_centered(Vector2i(480, 190))
	else:
		prepare_new()

func prepare_new() -> void:
	var snapshot: Dictionary = saves.load_run(data)
	if not snapshot.is_empty():
		if not saves.settle(saves.restore(snapshot),data):
			sound.cue("ui_error")
			notice.text = saves.error
			return
	elif not saves.error.is_empty():
		var profile: Dictionary = saves.load_profile(data)
		if profile.is_empty():
			sound.cue("ui_error")
			notice.text = saves.error
			return
		profile.run = {}
		if not saves.commit_profile(profile,int(profile.revision)):
			sound.cue("ui_error")
			notice.text = saves.error
			return
	show_hub("loadout")

func show_hub(initial_tab: String = "shop") -> void:
	if audio_settings.visible: audio_settings.hide()
	sound.set_context("shop")
	audio_button.position = Vector2(930, 32)
	audio_button.show()
	current_page = "hub"
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.size = Vector2(1280,720)
	add_child(page)
	hub = CardHub.new()
	hub.sound = sound
	page.add_child(hub)
	hub.back_requested.connect(show_menu)
	hub.launch_requested.connect(start_new)
	hub.setup(saves,data,initial_tab)

func start_new(selected: Array = [], difficulty: String = "easy", scene_id: String = "kitchen") -> void:
	if is_instance_valid(game): return
	var run := controller()
	if not saves.load_run(data).is_empty() and not run.resume_run():
		sound.cue("ui_error")
		notice.text = run.message
		return
	var previous: RunState = run.state
	run.new_run(int(Time.get_unix_time_from_system()), selected, difficulty, scene_id)
	if run.state == previous or not saves.error.is_empty():
		sound.cue("ui_error")
		if is_instance_valid(hub) and hub.is_inside_tree():
			hub.feedback = run.message
			hub.rebuild()
		elif is_instance_valid(notice): notice.text = run.message
		return
	enter_game(run)

func enter_game(run: RunController) -> void:
	game = GAME.instantiate()
	game.run = run
	game.sound = sound
	game.audio_settings = audio_settings
	add_child(game)
	audio_button.hide()
	current_page = "game"
	page.hide()
	showing_result = false

func _process(_delta: float) -> void:
	if is_instance_valid(game) and not showing_result and game.run.state.phase in ["won", "lost"]:
		show_result()

func show_result() -> void:
	showing_result = true
	if audio_settings.visible: audio_settings.hide()
	sound.sync_run()
	audio_button.position = Vector2(1120, 20)
	audio_button.show()
	current_page = "result"
	game.settings_button.hide()
	game.cancel_card_drag()
	game.shovel = false
	game.update_shovel_cursor()
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	clear_page()
	var state: RunState = game.run.state
	var won: bool = state.phase == "won"
	text_line("今夜，守住了" if won else "明晚，再来", Vector2(80, 166), Vector2(650, 88), 58, GameTheme.GOLD if won else GameTheme.DANGER)
	var total: int = data.scene_wave_count(state.scene_id)
	var result_description: String = "%s，五大关全部告捷。" % data.scenes[state.scene_id].title if won else "%s · %d-%d 粮仓失守。\n本局抵达第 %d / %d 小关。" % [data.chapters[state.chapter_id].title,data.chapters[state.chapter_id].order,state.wave,state.global_wave(),total]
	if state.start_wave > 1:
		result_description = ("%s，接续守卫完成。" % data.scenes[state.scene_id].title if won else "%s · %d-%d 粮仓失守。" % [data.chapters[state.chapter_id].title,data.chapters[state.chapter_id].order,state.wave]) + "\n旧档第 %d 关接续 · 场景进度 %d/%d" % [state.start_wave,state.global_wave(),total]
	text_line(result_description, Vector2(88, 280), Vector2(585, 68), 22, GameTheme.MUTED)
	portrait(art.food_portrait("bun") if won else art.mouse("boss"), Vector2(178, 362), Vector2(380, 264))
	text_line("今夜战报", Vector2(792, 114), Vector2(360, 42), 28)
	result_stat("本局通过", "%d / %d" % [maxi(0,int(state.metrics.passed)-state.start_wave+1),total-state.start_wave+1], Vector2(792, 172), GameTheme.GOLD)
	result_stat("击退鼠群", str(state.metrics.kills), Vector2(976, 172))
	result_stat("守卫时间", "%02d:%02d" % [int(state.elapsed) / 60, int(state.elapsed) % 60], Vector2(792, 266))
	result_stat("本局灵感 · 跨局保留", "+%d" % run_inspiration(state), Vector2(976, 266), GameTheme.ACCENT)
	text_line("粮仓损失 %d   ·   美食阵亡 %d   ·   食谱 %d" % [state.metrics.leaks, state.metrics.deaths, state.recipes.size()], Vector2(792, 360), Vector2(356, 30), 14, GameTheme.MUTED)
	divider(Vector2(792, 400), 356)
	action("再守一夜  ·  调整阵容  →", Vector2(792, 420), func() -> void: leave_result("new"), true).name = "PlayAgain"
	action("美食卡册  ·  购卡与强化", Vector2(792, 484), func() -> void: leave_result("cards")).name = "ResultCardHub"
	var back := action("返回主菜单", Vector2(792, 550), func() -> void: leave_result("menu"))
	back.size.y = 40
	back.add_theme_font_size_override("font_size", 15)
	var clear_reward: int = int(saves.load_meta(data).get("ledger", {}).get(state.run_id, {}).get("first_clear_reward", 0))
	var report_message: String = game.run.message
	if clear_reward > 0:
		report_message += " 本局大关首通共 +%d 灵感。" % clear_reward
	notice = text_line(report_message, Vector2(792, 606), Vector2(356, 42), 13, GameTheme.MUTED)

func leave_result(destination: String) -> void:
	if not is_instance_valid(game) or not showing_result: return
	# Idempotent settlement also retries a failed write before discarding the run.
	if not saves.settle(game.run.state, data):
		sound.cue("ui_error")
		notice.text = saves.error
		return
	if destination == "quit":
		quit_game()
		return
	show_menu()
	if destination == "new": prepare_new()
	elif destination == "cards": show_hub("shop")

func run_inspiration(state: RunState) -> int:
	var amount: int = state.collected_inspiration()
	if state.rewards_enabled:
		for index: int in range(state.reward_floor,mini(int(state.metrics.passed),data.scene_wave_count(state.scene_id))):
			amount += state.inspiration_for_wave(index, data)
	amount += int(saves.load_meta(data).get("ledger", {}).get(state.run_id, {}).get("first_clear_reward", 0))
	return amount

func open_settings() -> void:
	if audio_settings.visible: return
	if is_instance_valid(game) and not showing_result:
		game.open_settings()
	else:
		audio_settings.open(game.run if is_instance_valid(game) else null, current_page != "menu")

func _input(event: InputEvent) -> void:
	# Active games own selection cleanup; menu and result pages have no board input.
	if is_instance_valid(game) and not showing_result: return
	if event.is_action_pressed("open_settings") and not event.is_echo():
		if audio_settings.visible: audio_settings.handle_escape()
		else: open_settings()
		get_viewport().set_input_as_handled()

func leave_settings(destination: String) -> void:
	if quitting or destination not in ["menu", "quit"]: return
	if is_instance_valid(game):
		if showing_result:
			if not saves.settle(game.run.state, data):
				audio_settings.show_error(saves.error)
				return
		elif not game.run.persist():
			audio_settings.show_error(game.run.message)
			return
	if destination == "quit":
		quit_game()
	else:
		show_menu()

func quit_game() -> void:
	if quitting: return
	quitting = true
	set_process(false)
	set_process_input(false)
	if is_instance_valid(game): game.process_mode = Node.PROCESS_MODE_DISABLED
	if audio_settings.visible: audio_settings.hide()
	audio_button.disabled = true
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.process_mode = Node.PROCESS_MODE_DISABLED
	await sound.shutdown()
	get_tree().quit()
