extends "res://scenes/main.gd"

# A visual fixture only: no persistence and no changes to normal game rules.
func _ready() -> void:
	run.saves.folder = "user://qa_art_gallery/"
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	super._ready()
	run.persistence = false
	run.new_run(42)
	run.state.coins = 99
	for id: String in ArtCatalog.FOOD_IDS: run.state.cards[id] = 1
	for index: int in range(8):
		run.state.heat = 350
		run.state.phase = "battle"
		run.board.place(ArtCatalog.FOOD_IDS[index], index / 4, index % 4, false)
	run.state.phase = "prepare"
	for index: int in range(8):
		run.combat.spawn(ArtCatalog.MOUSE_IDS[index], 2 + index / 4, run.data.waves[0])
		run.combat.enemies[-1].x = 96.0 * (index % 4 + 3) + 48.0
	run.combat.enemies[0].slow_time = 10
	run.combat.enemies[1].burn_time = 10
	run.message = "美术验收：8 美食 / 8 鼠群；按 R 查看食谱，P 查看小铺"
	rebuild()

func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			run.state.phase = "prepare"
			run.state.choices = ["pressure", "ice", "breakfast"]
			rebuild()
		if event.keycode == KEY_P:
			run.state.phase = "prepare"
			rebuild()
