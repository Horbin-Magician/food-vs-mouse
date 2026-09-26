class_name AudioSettings
extends AcceptDialog

signal menu_requested
signal quit_requested

var sound: SoundService
var sliders: Dictionary[String, HSlider] = {}
var percentages: Dictionary[String, Label] = {}
var mute_button: CheckButton
var note: Label
var menu_button: Button
var quit_button: Button
var leave_confirmation: ConfirmationDialog
var status_label: Label
var _status_detail: Label
var _backdrop_layer: CanvasLayer
var _run: RunController
var _opened_state: RunState
var _opened_phase: String = ""
var _was_paused: bool = false
var _paused_for_session: bool = false
var _session_open: bool = false
var _session_error: String = ""
var _pending_action: String = ""
var _nested_cancel_frame: int = -1

func _ready() -> void:
	title = "设置"
	name = "AudioSettings"
	theme = GameTheme.create()
	theme.set_stylebox("embedded_unfocused_border", "Window", theme.get_stylebox("embedded_border", "Window").duplicate())
	exclusive = true
	unresizable = true
	dialog_hide_on_ok = false
	min_size = Vector2i(520, 480)
	get_ok_button().text = "返回"
	get_ok_button().custom_minimum_size = Vector2(220, 42)
	GameTheme.primary(get_ok_button())
	for state: String in ["normal", "hover", "pressed"]:
		var button_style := get_ok_button().get_theme_stylebox(state).duplicate() as StyleBox
		button_style.content_margin_left = 70
		button_style.content_margin_right = 70
		button_style.content_margin_top = 10
		button_style.content_margin_bottom = 10
		get_ok_button().add_theme_stylebox_override(state, button_style)
	_backdrop_layer = CanvasLayer.new()
	_backdrop_layer.name = "SettingsBackdrop"
	_backdrop_layer.layer = 120
	_backdrop_layer.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.05, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.size = Vector2(1280, 720)
	_backdrop_layer.add_child(shade)
	get_parent().add_child.call_deferred(_backdrop_layer)
	confirmed.connect(_resume_or_return)
	visibility_changed.connect(_on_visibility_changed)
	close_requested.connect(_close_settings)
	canceled.connect(_close_settings)
	focus_exited.connect(_restore_embedded_focus, CONNECT_DEFERRED)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_right", 20)
	margins.add_theme_constant_override("margin_top", 8)
	margins.add_theme_constant_override("margin_bottom", 8)
	add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)
	var status_panel := PanelContainer.new()
	var status_style := GameTheme.box(GameTheme.RAISED, 12, GameTheme.BORDER)
	status_style.content_margin_top = 8
	status_style.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", status_style)
	column.add_child(status_panel)
	var status_column := VBoxContainer.new()
	status_column.add_theme_constant_override("separation", 5)
	status_panel.add_child(status_column)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", GameTheme.ACCENT)
	status_column.add_child(status_label)
	_status_detail = Label.new()
	_status_detail.add_theme_font_size_override("font_size", 14)
	_status_detail.add_theme_color_override("font_color", GameTheme.MUTED)
	status_column.add_child(_status_detail)
	var audio_title := Label.new()
	audio_title.text = "声音"
	audio_title.add_theme_font_size_override("font_size", 17)
	audio_title.add_theme_color_override("font_color", GameTheme.GOLD)
	column.add_child(audio_title)
	var volume_column := VBoxContainer.new()
	volume_column.add_theme_constant_override("separation", 8)
	column.add_child(volume_column)
	var labels: Dictionary[String, String] = {"Master": "总音量", "Music": "背景音乐", "SFX": "游戏音效"}
	for bus: String in SoundService.BUS_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		volume_column.add_child(row)
		var label := Label.new()
		label.text = labels[bus]
		label.custom_minimum_size.x = 80
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = bus + "Volume"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(230, 30)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.add_theme_stylebox_override("slider", GameTheme.box(GameTheme.BG, 4, GameTheme.BORDER))
		slider.add_theme_stylebox_override("grabber_area", GameTheme.box(GameTheme.ACCENT, 4))
		slider.add_theme_stylebox_override("grabber_area_highlight", GameTheme.box(GameTheme.GOLD, 4))
		slider.value_changed.connect(func(value: float) -> void:
			if is_instance_valid(sound): sound.set_level(bus, value / 100.0))
		row.add_child(slider)
		sliders[bus] = slider
		var percent := Label.new()
		percent.custom_minimum_size.x = 48
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		percent.add_theme_color_override("font_color", GameTheme.ACCENT)
		row.add_child(percent)
		percentages[bus] = percent
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 20)
	column.add_child(controls)
	mute_button = CheckButton.new()
	mute_button.name = "Mute"
	mute_button.text = "全部静音"
	mute_button.custom_minimum_size.y = 38
	mute_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_button.toggled.connect(func(value: bool) -> void:
		if is_instance_valid(sound): sound.set_muted(value))
	controls.add_child(mute_button)
	var preview := Button.new()
	preview.name = "PreviewSound"
	preview.text = "试听音效"
	preview.custom_minimum_size = Vector2(124, 38)
	preview.pressed.connect(func() -> void:
		if is_instance_valid(sound): sound.cue("purchase"))
	controls.add_child(preview)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(420, 36)
	note.add_theme_font_size_override("font_size", 14)
	column.add_child(note)
	var divider := HSeparator.new()
	var divider_style := StyleBoxFlat.new()
	divider_style.bg_color = GameTheme.BORDER
	divider_style.content_margin_top = 1
	divider.add_theme_stylebox_override("separator", divider_style)
	column.add_child(divider)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	column.add_child(navigation)
	menu_button = Button.new()
	menu_button.name = "ReturnToMenu"
	menu_button.text = "返回主菜单"
	menu_button.custom_minimum_size.y = 42
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button.pressed.connect(func() -> void: _request_leave("menu"))
	navigation.add_child(menu_button)
	quit_button = Button.new()
	quit_button.name = "QuitGame"
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size.y = 42
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_button.add_theme_color_override("font_color", GameTheme.DANGER)
	quit_button.pressed.connect(func() -> void: _request_leave("quit"))
	navigation.add_child(quit_button)
	leave_confirmation = ConfirmationDialog.new()
	leave_confirmation.name = "LeaveConfirmation"
	leave_confirmation.theme = theme
	leave_confirmation.exclusive = true
	leave_confirmation.unresizable = true
	leave_confirmation.dialog_hide_on_ok = false
	leave_confirmation.min_size = Vector2i(470, 170)
	leave_confirmation.get_cancel_button().text = "留在游戏"
	leave_confirmation.get_ok_button().custom_minimum_size = Vector2(140, 38)
	leave_confirmation.get_cancel_button().custom_minimum_size = Vector2(140, 38)
	for control: Button in [leave_confirmation.get_ok_button(), leave_confirmation.get_cancel_button()]:
		for state: String in ["normal", "hover", "pressed"]:
			var style := theme.get_stylebox(state, "Button").duplicate() as StyleBox
			style.content_margin_left = 28
			style.content_margin_right = 28
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			control.add_theme_stylebox_override(state, style)
	leave_confirmation.confirmed.connect(_confirm_leave)
	leave_confirmation.canceled.connect(_cancel_leave)
	leave_confirmation.close_requested.connect(_cancel_leave)
	leave_confirmation.focus_exited.connect(_restore_embedded_focus, CONNECT_DEFERRED)
	add_child(leave_confirmation)
	_refresh()

func setup(service: SoundService) -> void:
	if _session_open: hide()
	if is_instance_valid(sound) and sound.settings_changed.is_connected(_refresh): sound.settings_changed.disconnect(_refresh)
	sound = service
	if is_instance_valid(sound): sound.settings_changed.connect(_refresh)
	_refresh()

func open(run: RunController = null, allow_menu: bool = false) -> void:
	if visible or not is_instance_valid(sound): return
	_run = run
	_opened_state = run.state if run != null else null
	_opened_phase = _opened_state.phase if _opened_state != null else ""
	_was_paused = run.paused if run != null else false
	_paused_for_session = _opened_phase == "battle"
	_session_error = ""
	_pending_action = ""
	_session_open = true
	menu_button.visible = allow_menu
	if run != null: run.changed.connect(_on_run_changed)
	if _paused_for_session:
		run.paused = true
		sound.set_game_paused(true)
	sound.cue("ui_click")
	_refresh()
	popup_centered_clamped(Vector2i(560, 490), 0.9)

func handle_escape() -> void:
	if not visible: return
	if leave_confirmation.visible: _cancel_leave()
	else: _close_settings()

func _restore_embedded_focus() -> void:
	# Embedded windows can lose keyboard focus to an outside click while remaining
	# exclusive. Restore the active modal locally without activating the OS window.
	if not is_inside_tree() or not visible or not is_embedded(): return
	if leave_confirmation.visible: leave_confirmation.grab_focus()
	else: grab_focus()

func show_error(message: String) -> void:
	_session_error = message
	_refresh()

func _resume_or_return() -> void:
	if is_instance_valid(leave_confirmation) and leave_confirmation.visible: return
	if _paused_for_session: _was_paused = false
	hide()

func _close_settings() -> void:
	if is_instance_valid(leave_confirmation) and leave_confirmation.visible: return
	# The same Esc that dismisses the nested confirmation must not dismiss settings.
	if _nested_cancel_frame == Engine.get_process_frames(): return
	hide()

func _on_run_changed() -> void:
	if not _session_open or _run == null: return
	if _run.state != _opened_state or _run.state == null or _run.state.phase != _opened_phase:
		hide()

func _on_visibility_changed() -> void:
	if is_instance_valid(_backdrop_layer): _backdrop_layer.visible = visible
	if visible or not _session_open: return
	_release_session()
	if is_instance_valid(sound): sound.cue("ui_cancel")

func _release_session() -> void:
	if not _session_open: return
	_session_open = false
	if is_instance_valid(leave_confirmation): leave_confirmation.hide()
	_pending_action = ""
	if _run != null and _run.changed.is_connected(_on_run_changed): _run.changed.disconnect(_on_run_changed)
	# Only the exact active battle paused by this window may be resumed.
	if _paused_for_session and _run != null and is_instance_valid(sound) and sound.bound_run == _run and _run.state == _opened_state and _run.state.phase == "battle":
		_run.paused = _was_paused
		sound.set_game_paused(_was_paused)
	_run = null
	_opened_state = null
	_opened_phase = ""
	_paused_for_session = false

func _exit_tree() -> void:
	_release_session()
	if is_instance_valid(_backdrop_layer): _backdrop_layer.queue_free()
	if is_instance_valid(sound) and sound.settings_changed.is_connected(_refresh): sound.settings_changed.disconnect(_refresh)

func _request_leave(action: String) -> void:
	if not visible or not _session_open or leave_confirmation.visible: return
	if action == "menu" and not menu_button.visible: return
	_session_error = ""
	_refresh()
	if is_instance_valid(sound): sound.cue("ui_click")
	if _run != null and _run.state == _opened_state and _opened_phase in ["prepare", "battle"]:
		_pending_action = action
		leave_confirmation.title = "返回主菜单？" if action == "menu" else "退出游戏？"
		leave_confirmation.get_ok_button().text = "返回主菜单" if action == "menu" else "退出游戏"
		if _opened_phase == "battle":
			leave_confirmation.dialog_text = "继续游戏将回到本关开战前。\n已赚取的灵感会保留。"
		else:
			leave_confirmation.dialog_text = "将保存当前准备进度和已购买食谱。\n下次可从主菜单继续游戏。"
		leave_confirmation.popup_centered_clamped(Vector2i(480, 180), 0.9)
		return
	_emit_leave(action)

func _cancel_leave() -> void:
	_pending_action = ""
	_nested_cancel_frame = Engine.get_process_frames()
	leave_confirmation.hide()
	if is_instance_valid(sound): sound.cue("ui_cancel")

func _confirm_leave() -> void:
	var action: String = _pending_action
	_pending_action = ""
	leave_confirmation.hide()
	if not _session_open or _run == null or _run.state != _opened_state or _run.state.phase != _opened_phase: return
	_emit_leave(action)

func _emit_leave(action: String) -> void:
	if action == "menu": menu_requested.emit()
	elif action == "quit": quit_requested.emit()

func _refresh() -> void:
	if not is_instance_valid(sound) or not is_instance_valid(mute_button): return
	for bus: String in sliders:
		var value: int = roundi(sound.get_level(bus) * 100.0)
		sliders[bus].set_value_no_signal(value)
		percentages[bus].text = "%d%%" % value
	mute_button.set_pressed_no_signal(sound.muted)
	get_ok_button().text = "继续游戏" if _paused_for_session else "返回"
	if _paused_for_session:
		status_label.text = "游戏已暂停"
		_status_detail.text = "调整声音后，继续守住这一餐。"
	elif _opened_phase == "prepare":
		status_label.text = "关前准备"
		_status_detail.text = "返回后继续选购食谱，购物进度保留。"
	elif _opened_phase in ["won", "lost"]:
		status_label.text = "战报与设置"
		_status_detail.text = "查看战报，或返回主菜单。"
	else:
		status_label.text = "声音与游戏"
		_status_detail.text = "按你的喜好，调整食堂的声音。"
	var error: String = _session_error if not _session_error.is_empty() else sound.settings_error
	note.text = error if not error.is_empty() else "音量设置即时生效并自动保存。Esc 返回原页面。"
	note.add_theme_color_override("font_color", GameTheme.DANGER if not error.is_empty() else GameTheme.MUTED)
