extends "res://scenes/main.gd"

var frames: Array[float] = []
var wall_start: int

func _ready() -> void:
	super._ready()
	run.persistence = false
	run.new_run(400100)
	for id: String in run.data.foods: run.state.cards[id] = 6
	run.state.wave = 8
	run.start()
	run.director.cursor = run.director.events.size()
	var food_ids: Array[String] = ["bun","tea","pepper","popcorn","noodles","garlic","bun","tea"]
	for row: int in range(5):
		for col: int in range(8):
			run.state.heat = 350
			run.state.cooldowns.clear()
			run.board.place(food_ids[col],row,col,false)
	for i: int in range(100):
		run.combat.spawn("gray",i%5,run.data.waves[7])
		var enemy: Dictionary = run.combat.enemies.back()
		enemy.x = 760.0 + (i/5)*4
		enemy.hp = 1000000.0
		enemy.max_hp = enemy.hp
	wall_start = Time.get_ticks_msec()
	rebuild()

func _process(delta: float) -> void:
	for unit: Dictionary in run.state.units: unit.hp = run.board.max_hp(unit.id)
	for enemy: Dictionary in run.combat.enemies:
		if enemy.x < 760: enemy.x = 760
	super._process(delta)
	var elapsed: float = (Time.get_ticks_msec()-wall_start)/1000.0
	if elapsed > 3: frames.append(delta)
	if elapsed >= 23:
		frames.sort()
		var total: float = 0.0
		for value: float in frames: total += value
		var report_data: Dictionary = {"renderer":RenderingServer.get_video_adapter_name(),"resolution":"1280x720","units":run.state.units.size(),"enemies":run.combat.enemies.size(),"seconds":total,"frames":frames.size(),"average_fps":frames.size()/total,"p95_ms":frames[int(frames.size()*0.95)]*1000,"p99_ms":frames[int(frames.size()*0.99)]*1000}
		var file: FileAccess = FileAccess.open("user://qa_visual/stress.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report_data,"  "))
		file.close()
		print("STRESS ",JSON.stringify(report_data))
		get_tree().quit()
