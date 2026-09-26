extends "res://tests/art_gallery.gd"

# Repeatable native visual inspection, isolated from player saves.
class PreviewRun extends RunController:
	func advance(_delta: float) -> void:
		pass

var preview_clock: float = 0.0
var preview_stage: int = -1
var capture: bool = false
var captured_reaction: int = -1

func _ready() -> void:
	run = PreviewRun.new()
	super._ready()
	run.automatic_start_pending = false
	run.state.phase = "battle"
	rebuild()
	animator.bind(run, projection)
	capture = "--capture-animation" in OS.get_cmdline_user_args()

func _process(delta: float) -> void:
	delta = minf(delta, 0.25) * run.speed
	if not run.paused: preview_clock += delta
	var stage: int = int(preview_clock / 2.0) % 5
	if stage != preview_stage:
		preview_stage = stage
		if stage == 0:
			for index: int in range(run.combat.enemies.size()):
				run.combat.enemies[index].x = 96.0 * (index % 4 + 3) + 48.0
		for unit: Dictionary in run.state.units + run.combat.enemies:
			if stage == 1: animator.appear(unit)
			if stage == 2 and unit.id != "toast": animator.act(unit.uid)
		if stage == 3:
			run.state.phase = "prepare"
			run.board.move(0, 0, 1, 3)
			run.state.phase = "battle"
		run.message = "动画验收：%s（每 2 秒切换）；设置可暂停，左上可切换倍速" % ["待机", "放置 / 入场", "攻击 / 产热", "调位 / 行走", "连续受击（每 0.08 秒）"][stage]
	if stage in [3, 4] and not run.paused:
		for enemy: Dictionary in run.combat.enemies: enemy.x -= delta * 20
	if stage == 2 and not run.paused and fmod(preview_clock, 0.7) < delta:
		for unit: Dictionary in run.state.units + run.combat.enemies:
			if unit.id != "toast": animator.act(unit.uid)
	if stage == 4 and not run.paused and fmod(preview_clock, 0.08) < delta:
		for unit: Dictionary in run.state.units: animator.food_hurt(unit)
		for enemy: Dictionary in run.combat.enemies: animator.hurt(enemy)
	# PreviewRun freezes gameplay; presentation still uses the real battle UI.
	animator.advance(0.0 if run.paused else delta, run.combat.enemies)
	super._process(0.0)
	if capture and fmod(preview_clock, 2.0) >= 0.12 and fmod(preview_clock - delta, 2.0) < 0.12:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/food_animation_%d.png" % stage)
	if capture and stage == 4:
		var sample: int = int((preview_clock - 8.0) / 0.05)
		if sample > captured_reaction and sample < 12:
			captured_reaction = sample
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/food_reaction_%02d.png" % sample)
	if capture and preview_clock > 9.5: get_tree().quit()
