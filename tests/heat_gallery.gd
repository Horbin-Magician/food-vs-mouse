extends "res://scenes/main.gd"

# Isolated visual fixture: normal production/collection, delayed enemies, no player save writes.
var captured_flight: bool = false

func _ready() -> void:
	super._ready()
	run.persistence = false
	run.new_run(42)
	run.start()
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(4, 3), Vector2i(8, 6)]:
		run.state.heat = 350
		run.state.cooldowns.clear()
		run.board.place("pudding", cell.y, cell.x, false)
		run.state.units[-1].timer = 9.5
	run.state.heat = 100
	for event: Dictionary in run.director.events: event.time += 3600
	rebuild()

func _process(delta: float) -> void:
	super._process(delta)
	if not captured_flight:
		for pickup: Dictionary in run.combat.heat_pickups:
			if pickup.flight > 0.15 and pickup.flight < 0.3:
				captured_flight = true
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("/tmp/food_heat_flight.png")
				break
