extends "res://tests/art_gallery.gd"

# Repeatable native visual inspection, isolated from player saves.
var preview_clock: float = 0.0
var preview_stage: int = -1
var capture: bool = false

func _ready() -> void:
	super._ready()
	animator.bind(run, projection)
	capture = "--capture-animation" in OS.get_cmdline_user_args()

func _process(delta: float) -> void:
	if not run.paused: preview_clock += delta
	var stage: int = int(preview_clock / 2.0) % 4
	if stage != preview_stage:
		preview_stage = stage
		if stage == 0:
			for index: int in range(run.combat.enemies.size()):
				run.combat.enemies[index].x = 96.0 * (index % 4 + 3) + 48.0
		for unit: Dictionary in run.state.units + run.combat.enemies:
			if stage == 1: animator.appear(unit)
			if stage == 2 and unit.id != "toast": animator.act(unit.uid)
		if stage == 3:
			run.board.move(0, 0, 1, 3)
		run.message = "动画验收：%s（每 2 秒切换）；准备阶段可鼠标调位" % ["待机", "放置 / 入场", "攻击 / 产热", "调位 / 行走"][stage]
	if stage == 3 and not run.paused:
		for enemy: Dictionary in run.combat.enemies: enemy.x -= delta * 20
	if stage == 2 and fmod(preview_clock, 0.7) < delta:
		for unit: Dictionary in run.state.units + run.combat.enemies:
			if unit.id != "toast": animator.act(unit.uid)
	super._process(delta)
	if capture and fmod(preview_clock, 2.0) >= 0.12 and fmod(preview_clock - delta, 2.0) < 0.12:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/food_animation_%d.png" % stage)
	if capture and preview_clock > 7.5: get_tree().quit()
