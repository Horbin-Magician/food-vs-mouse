extends Node2D

var art := ArtCatalog.new()
var clock: float = 0.0
var paused: bool = false
var speed: float = 1.0
var frame_override: int = -1
var capture: bool = false

func _ready() -> void:
	capture = "--capture-bun" in OS.get_cmdline_user_args()
	DisplayServer.window_set_title("F 小笼包 — Space 暂停 / → 逐帧 / 2 倍速")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			paused = not paused
			frame_override = -1
		if event.keycode == KEY_RIGHT:
			paused = true
			frame_override = (frame_override + 1) % 6
		if event.keycode == KEY_2: speed = 2.0 if speed == 1.0 else 1.0

func _process(delta: float) -> void:
	if not paused: clock += delta * speed
	queue_redraw()
	if capture and clock >= 0.5:
		set_process(false)
		for frame: int in range(6):
			frame_override = frame
			queue_redraw()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/f_bun_%d.png" % frame)
		get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("203a3c"))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 32), "F 小笼包六动作 | Space 暂停 · → 单步 · 2 倍速 | %.0f×" % speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	for row: int in range(6):
		var frame: int = frame_override if frame_override >= 0 else int(clock / ([1.2, 0.38, 0.25, 0.30, 0.72, 0.32][row] / 6.0)) % 6
		draw_string(font, Vector2(24, 106 + row * 100), ["待机", "放置", "攻击", "受击", "退场", "调位"][row], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		for col: int in range(6):
			var rect := Rect2(180 + col * 170, 56 + row * 100, 94, 94)
			draw_rect(rect, Color("b6c2a8"))
			draw_texture_rect(art.bun_frame(Vector2i(col, row)), rect, false)
			if col == frame: draw_rect(rect, Color("ffdd99"), false, 3.0)
		draw_texture_rect(art.bun_frame(Vector2i(frame, row)), Rect2(1130, 56 + row * 100, 94, 94), false)
