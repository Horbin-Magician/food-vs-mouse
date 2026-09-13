class_name RunController
extends RefCounted

signal changed
var data: Catalog = Catalog.new()
var state: RunState
var board: BoardController
var combat: CombatController
var director: WaveDirector = WaveDirector.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var paused: bool = false
var speed: float = 1.0
var accumulator: float = 0.0
var message: String = "选择开战，再选卡放置；准备阶段可调位。"

func new_run(seed_value: int = 1) -> void:
	state = RunState.new()
	state.seed_value = seed_value
	rng.seed = seed_value
	board = BoardController.new(state, data)
	combat = CombatController.new(state, data, board)
	director = WaveDirector.new()
	paused = false
	accumulator = 0.0
	changed.emit()

func start() -> void:
	if state.phase != "prepare": return
	state.phase = "battle"
	state.heat = data.rules.heat_start
	state.cooldowns.clear()
	state.leaks = 0
	combat.clear()
	director.begin(data.waves[state.wave - 1], rng)
	message = "鼠潮来袭！左键选卡再点格子，右键取消。"
	changed.emit()

func advance(delta: float) -> void:
	if state.phase != "battle" or paused: return
	accumulator += minf(delta, 0.25) * speed
	while accumulator >= 1.0 / 60.0 and state.phase == "battle":
		accumulator -= 1.0 / 60.0
		state.elapsed += 1.0 / 60.0
		for event: Dictionary in director.advance(1.0 / 60.0):
			combat.spawn(event.id, event.row, data.waves[state.wave - 1])
		combat.step(1.0 / 60.0)
		if state.pantry <= 0:
			state.phase = "lost"
			message = "粮仓失守。调整阵型，再试一次。"
		elif director.finished() and combat.enemies.is_empty():
			finish_wave()
		if state.phase != "battle":
			combat.clear()
			changed.emit()

func finish_wave() -> void:
	if state.phase != "battle": return
	state.metrics.passed = state.wave
	board.heal(data.rules.heal)
	if state.wave == data.waves.size():
		state.phase = "won"
		message = "今夜粮仓守住了！"
		return
	state.coins += data.rules.rewards[state.wave - 1] + (data.rules.bonus if state.leaks <= 1 else 0)
	state.wave += 1
	state.phase = "prepare"
	state.repaired = false
	state.heat = data.rules.heat_start
	message = "通关奖励已到账。可免费调位、交换、移除，或维修一次。"
