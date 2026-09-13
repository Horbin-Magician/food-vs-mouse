class_name RunController
extends RefCounted

signal changed
var saves: SaveService = SaveService.new()
var persistence: bool = false
var data: Catalog = Catalog.new()
var state: RunState
var board: BoardController
var combat: CombatController
var shop: ShopController
var recipes: RecipeSystem
var unlocked: Array = []
var director: WaveDirector = WaveDirector.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var paused: bool = false
var speed: float = 1.0
var accumulator: float = 0.0
var message: String = "选择开战，再选卡放置；准备阶段可调位。"

func new_run(seed_value: int = 1) -> void:
	if persistence and state != null and state.phase not in ["won","lost"]:
		if not saves.settle(state,data):
			message = saves.error
			return
	state = RunState.new()
	state.run_id = "%d_%d" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	if persistence:
		var meta: Dictionary = saves.load_meta(data)
		unlocked = meta.unlocked
	state.seed_value = seed_value
	rng.seed = seed_value
	board = BoardController.new(state, data)
	recipes = RecipeSystem.new(state,data)
	shop = ShopController.new(state,data,board,rng)
	shop.open()
	combat = CombatController.new(state, data, board, recipes, rng)
	director = WaveDirector.new()
	paused = false
	accumulator = 0.0
	message = "准备就绪；开战后用热量布阵。"
	persist()
	changed.emit()

func start() -> void:
	if state.phase != "prepare": return
	if not persist(): return
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
			settle()
		elif director.finished() and combat.enemies.is_empty():
			finish_wave()
		if state.phase != "battle":
			combat.clear()
			persist()
			changed.emit()

func finish_wave() -> void:
	if state.phase != "battle": return
	state.metrics.passed = state.wave
	board.heal(recipes.value("reheat","heal",data.rules.heal))
	if state.wave == data.waves.size():
		state.phase = "won"
		message = "今夜粮仓守住了！"
		settle()
		return
	state.coins += data.rules.rewards[state.wave - 1] + (data.rules.bonus if state.leaks <= 1 else 0)
	state.wave += 1
	state.phase = "recipe"
	recipes.offer(rng,unlocked)
	state.repaired = false
	state.heat = data.rules.heat_start
	message = "通关奖励已到账。可免费调位、交换、移除，或维修一次。"

func choose_recipe(id: String) -> String:
	var error: String = recipes.choose(id)
	if not error.is_empty(): return error
	enter_shop()
	return ""

func skip_recipe() -> void:
	if state.phase == "recipe" and state.choices.is_empty(): enter_shop()

func enter_shop() -> void:
	state.phase = "prepare"
	shop.open()
	message = "选谱完成，购买卡牌并调整阵地后开始下一关。"
	persist()
	changed.emit()

func persist() -> bool:
	if not persistence or state.phase not in ["prepare","recipe"]: return true
	if saves.save_run(state,rng): return true
	message = saves.error
	return false

func settle() -> void:
	if persistence and not saves.settle(state,data): message += " " + saves.error

func resume_run() -> bool:
	var meta: Dictionary = saves.load_meta(data)
	unlocked = meta.unlocked
	var meta_error: String = saves.error
	var payload: Dictionary = saves.load_run(data)
	if payload.is_empty():
		message = saves.error if not saves.error.is_empty() else meta_error
		return false
	state = saves.restore(payload)
	rng.seed = state.seed_value
	rng.state = int(payload.rng)
	board = BoardController.new(state,data)
	recipes = RecipeSystem.new(state,data)
	shop = ShopController.new(state,data,board,rng)
	combat = CombatController.new(state,data,board,recipes,rng)
	director = WaveDirector.new()
	paused = false
	accumulator = 0.0
	message = "已恢复准备快照；战斗中退出会回到本关开战前。 " + meta_error
	changed.emit()
	return true
