extends "res://tests/stress.gd"

class NoStatusDrawing extends StatusFeedback:
	func draw_ground(_canvas: Node2D, _unit: Dictionary, _foot: Vector2) -> void: pass
	func draw_status(_canvas: Node2D, _unit: Dictionary, _foot: Vector2, _height: float) -> void: pass
	func draw_effects(_canvas: Node2D) -> void: pass

func _ready() -> void:
	super._ready()
	run.state.recipes.assign(["breakfast", "crust", "pressure", "burn", "cold_spice", "wide"])
	for unit: Dictionary in run.state.units: unit.flour = 60.0
	run.combat.enemies.clear()
	for i: int in range(100):
		run.combat.spawn("drummer" if i % 10 == 0 else "lid", i % 5, run.data.waves[7])
		var enemy: Dictionary = run.combat.enemies[-1]
		enemy.x = 760.0 + (i / 5) * 4
		enemy.hp = 1000000.0
		enemy.max_hp = enemy.hp
		# Keep the required 40 actors alive throughout this presentation stress case.
		enemy.dps = 0.0
		enemy.slow = 0.4
		enemy.slow_time = 60.0
		enemy.burn_time = 60.0
	assert(run.state.units.size() == 40 and run.combat.enemies.size() == 100)
	if "--without-status-drawing" in OS.get_cmdline_user_args():
		run.combat.skill_used.disconnect(status_feedback.on_skill)
		run.board.healed.disconnect(status_feedback.on_heal)
		status_feedback = NoStatusDrawing.new()
		status_feedback.bind(run, projection)
