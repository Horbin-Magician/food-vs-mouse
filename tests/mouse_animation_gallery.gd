extends Node2D

var art: ArtCatalog = ArtCatalog.new()
var clock: float = 0.0
var paused: bool = false
var speed: float = 1.0
var manual_frame: int = -1
var capture: bool = false

func _ready() -> void:
	capture = "--capture-mice" in OS.get_cmdline_user_args()
	DisplayServer.window_set_title("鼠群逐帧验收 — Space 暂停 / → 逐帧 / 2 倍速")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			paused = not paused
			manual_frame = -1
		if event.keycode == KEY_RIGHT:
			paused = true
			manual_frame = (manual_frame + 1) % 6
		if event.keycode == KEY_2: speed = 2.0 if speed == 1.0 else 1.0
		queue_redraw()

func _process(delta: float) -> void:
	if not paused: clock += delta * speed
	queue_redraw()
	if capture and clock > 1.0:
		set_process(false)
		for frame: int in range(6):
			manual_frame = frame
			queue_redraw()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/mouse_frames_%d.png" % frame)
		get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("203a3c"))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(20, 28), "鼠群动作帧 | Space 暂停 · → 单步 · 2 切换倍速 | %.0f×" % speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	for index: int in range(8):
		draw_string(font, Vector2(95 + index * 148, 60), ArtCatalog.MOUSE_IDS[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	for row: int in range(4):
		var frame: int = manual_frame if manual_frame >= 0 else int(clock / [0.12, 0.08, 0.05, 0.12][row]) % 6
		draw_string(font, Vector2(8, 126 + row * 156), ["移动", "攻击", "受伤", "死亡"][row], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, Vector2(14, 149 + row * 156), "%d/6" % (frame + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		for index: int in range(8):
			var rect := Rect2(75 + index * 148, 72 + row * 156, 142, 142)
			draw_rect(rect, Color("b6c2a8"))
			draw_texture_rect(art.mouse_frame(ArtCatalog.MOUSE_IDS[index], Vector2i(frame, row)), rect, false)
