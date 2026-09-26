class_name AudioSettings
extends AcceptDialog

var sound: SoundService
var sliders: Dictionary[String, HSlider] = {}
var percentages: Dictionary[String, Label] = {}
var mute_button: CheckButton
var note: Label
var _run: RunController
var _opened_state: RunState
var _was_paused: bool = false
var _session_open: bool = false

func _ready() -> void:
	title = "声音设置"
	name = "AudioSettings"
	theme = GameTheme.create()
	exclusive = true
	unresizable = true
	min_size = Vector2i(480, 340)
	get_ok_button().text = "完成"
	visibility_changed.connect(_on_visibility_changed)
	close_requested.connect(hide)
	canceled.connect(hide)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 24)
	margins.add_theme_constant_override("margin_right", 24)
	margins.add_theme_constant_override("margin_top", 18)
	margins.add_theme_constant_override("margin_bottom", 16)
	add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margins.add_child(column)
	var labels: Dictionary[String, String] = {"Master": "总音量", "Music": "背景音乐", "SFX": "游戏音效"}
	for bus: String in SoundService.BUS_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		column.add_child(row)
		var label := Label.new()
		label.text = labels[bus]
		label.custom_minimum_size.x = 84
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = bus + "Volume"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(200, 30)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value: float) -> void:
			if is_instance_valid(sound): sound.set_level(bus, value / 100.0))
		row.add_child(slider)
		sliders[bus] = slider
		var percent := Label.new()
		percent.custom_minimum_size.x = 46
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(percent)
		percentages[bus] = percent
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 24)
	column.add_child(controls)
	mute_button = CheckButton.new()
	mute_button.name = "Mute"
	mute_button.text = "静音"
	mute_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_button.toggled.connect(func(value: bool) -> void:
		if is_instance_valid(sound): sound.set_muted(value))
	controls.add_child(mute_button)
	var preview := Button.new()
	preview.name = "PreviewSound"
	preview.text = "试听音效"
	preview.pressed.connect(func() -> void:
		if is_instance_valid(sound): sound.cue("purchase"))
	controls.add_child(preview)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(390, 42)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", GameTheme.MUTED)
	column.add_child(note)
	_refresh()

func setup(service: SoundService) -> void:
	if is_instance_valid(sound) and sound.settings_changed.is_connected(_refresh): sound.settings_changed.disconnect(_refresh)
	sound = service
	if is_instance_valid(sound): sound.settings_changed.connect(_refresh)
	_refresh()

func open(run: RunController = null) -> void:
	if visible or not is_instance_valid(sound): return
	_run = run
	_opened_state = run.state if run != null else null
	_was_paused = run.paused if run != null else false
	_session_open = true
	if run != null and run.state != null and run.state.phase == "battle":
		run.paused = true
		sound.set_game_paused(true)
	sound.cue("ui_click")
	_refresh()
	popup_centered_clamped(Vector2i(500, 340), 0.9)

func _on_visibility_changed() -> void:
	if visible or not _session_open: return
	_session_open = false
	if _run != null and is_instance_valid(sound) and sound.bound_run == _run and _run.state == _opened_state and _run.state.phase == "battle":
		_run.paused = _was_paused
		sound.set_game_paused(_was_paused)
	_run = null
	_opened_state = null
	if is_instance_valid(sound): sound.cue("ui_cancel")

func _refresh() -> void:
	if not is_instance_valid(sound) or not is_instance_valid(mute_button): return
	for bus: String in sliders:
		var value: int = roundi(sound.get_level(bus) * 100.0)
		sliders[bus].set_value_no_signal(value)
		percentages[bus].text = "%d%%" % value
	mute_button.set_pressed_no_signal(sound.muted)
	note.text = sound.settings_error if not sound.settings_error.is_empty() else "设置自动保存。战斗中打开此面板会暂停游戏。"
