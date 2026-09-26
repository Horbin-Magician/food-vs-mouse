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
	var audio_layer := CanvasLayer.new()
	audio_layer.layer = 110
	add_child(audio_layer)
	audio_button = Button.new()
	audio_button.name = "AudioButton"
	audio_button.text = "声音"
	audio_button.size = Vector2(104, 32)
	audio_button.theme = GameTheme.create()
	audio_button.tooltip_text = "音乐、音效与总音量"
	audio_button.pressed.connect(func() -> void:
		if is_instance_valid(game) and not showing_result:
			game.cancel_card_drag()
			audio_settings.open(game.run)
		else: audio_settings.open())
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
	shade.color = Color(0.025, 0.07, 0.075, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(shade)
	var surface := Panel.new()
	surface.position = Vector2(744, 80)
	surface.size = Vector2(452, 560)
	surface.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.SURFACE, 24, GameTheme.BORDER))
	page.add_child(surface)
	text_line("MIDNIGHT KITCHEN  /  深夜营业", Vector2(84, 84), Vector2(610, 30), 16, GameTheme.GOLD)
	text_line("美食守卫 · 八关鼠潮", Vector2(84, 652), Vector2(600, 28), 15, GameTheme.MUTED)

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
	text_line("今夜，开张", Vector2(792, 124), Vector2(360, 56), 32)
	text_line("布置美食阵地，抵御八关鼠潮。\n关间购买食谱，打造你的守卫阵容。", Vector2(792, 196), Vector2(356, 66), 17, GameTheme.MUTED)
	var snapshot: Dictionary = saves.load_run(data)
	var load_error: String = saves.error
	continue_button = action("继续游戏  ·  第 %d 关" % int(snapshot.get("wave", 1)), Vector2(792, 296), continue_run, true)
	continue_button.disabled = snapshot.is_empty()
	action("新的一局", Vector2(792, 366), request_new, snapshot.is_empty())
	action("美食卡册 · 购卡与强化", Vector2(792, 430), func() -> void: show_hub("shop"))
	action("退出游戏", Vector2(792, 494), func() -> void: get_tree().quit())
	notice = text_line(load_error if not load_error.is_empty() else ("暂无可继续的守卫，开始新的一局吧。" if snapshot.is_empty() else "准备阶段自动保存。战斗中退出后，\n继续游戏会回到本关开战前。"), Vector2(792, 558), Vector2(356, 66), 15, GameTheme.MUTED)
	overwrite = ConfirmationDialog.new()
	overwrite.title = "开始新的一局？"
	overwrite.dialog_text = "现有守卫进度将结束，阵地和金币将重置。\n已赚灵感与食谱解锁保留，卡店刷新。"
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
	sound.set_context("shop")
	audio_button.position = Vector2(930, 32)
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

func start_new(selected: Array = [], difficulty: String = "easy") -> void:
	if is_instance_valid(game): return
	var run := controller()
	if not saves.load_run(data).is_empty() and not run.resume_run():
		sound.cue("ui_error")
		notice.text = run.message
		return
	var previous: RunState = run.state
	run.new_run(int(Time.get_unix_time_from_system()), selected, difficulty)
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
	audio_button.position = Vector2(234, 678)
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
	game.cancel_card_drag()
	game.shovel = false
	game.update_shovel_cursor()
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	clear_page()
	var state: RunState = game.run.state
	var won: bool = state.phase == "won"
	text_line("今夜，守住了" if won else "明晚，再来", Vector2(80, 166), Vector2(650, 88), 58, GameTheme.GOLD if won else GameTheme.DANGER)
	text_line("八关告捷，食堂安然无恙。" if won else "第 %d 关粮仓失守。换个阵容，再试一次。" % state.wave, Vector2(88, 280), Vector2(585, 68), 22, GameTheme.MUTED)
	portrait(art.food_portrait("bun") if won else art.mouse("boss"), Vector2(178, 362), Vector2(380, 264))
	text_line("今 夜 战 报", Vector2(792, 112), Vector2(360, 44), 28)
	text_line("通过关卡       %d / 8\n守卫时长       %02d:%02d\n击退鼠群       %d\n粮仓损失       %d\n美食阵亡       %d\n已购食谱       %d\n本夜灵感       +%d" % [state.metrics.passed, int(state.elapsed) / 60, int(state.elapsed) % 60, state.metrics.kills, state.metrics.leaks, state.metrics.deaths, state.recipes.size(), run_inspiration(state)], Vector2(792, 170), Vector2(356, 244), 21)
	action("再守一夜  →", Vector2(792, 424), func() -> void: leave_result("new"), true)
	action("返回主菜单", Vector2(792, 488), func() -> void: leave_result("menu"))
	action("退出游戏", Vector2(792, 552), func() -> void: leave_result("quit"))
	notice = text_line(game.run.message, Vector2(792, 612), Vector2(356, 44), 13, GameTheme.MUTED)

func leave_result(destination: String) -> void:
	if not is_instance_valid(game) or not showing_result: return
	# Idempotent settlement also retries a failed write before discarding the run.
	if not saves.settle(game.run.state, data):
		sound.cue("ui_error")
		notice.text = saves.error
		return
	if destination == "quit":
		get_tree().quit()
		return
	show_menu()
	if destination == "new": prepare_new()

func run_inspiration(state: RunState) -> int:
	var amount: int = 0
	if state.rewards_enabled:
		for index: int in range(state.reward_floor,mini(int(state.metrics.passed),8)):
			amount += state.inspiration_for_wave(index, data)
	return amount
