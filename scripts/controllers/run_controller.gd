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
var message: String = "购物完成后自动开战，再选卡放置。"

func new_run(seed_value: int = 1, selected: Array = [], difficulty: String = "easy") -> void:
	if not data.difficulties.has(difficulty):
		message = "未知难度"
		return
	if persistence and state != null:
		if not saves.settle(state,data):
			message = saves.error
			return
	var meta: Dictionary = MetaProgression.initial(data)
	if persistence:
		var profile: Dictionary = saves.load_profile(data)
		if profile.is_empty() or not saves.error.is_empty():
			message = saves.error
			return
		meta = profile.meta
	var chosen: Array = selected if not selected.is_empty() else meta.loadout
	if chosen.is_empty(): chosen = ["card_1","card_2","card_3"]
	var selection_error: String = MetaProgression.loadout_error(meta, chosen, data)
	if not selection_error.is_empty():
		message = selection_error
		return
	state = RunState.new()
	state.difficulty = difficulty
	state.run_id = "%d_%d" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	state.cards.clear()
	state.levels.clear()
	for uid: String in chosen:
		var item: Dictionary = MetaProgression.card(meta, uid)
		state.cards[item.id] = 1
		state.levels[item.id] = int(item.level)
		state.loadout.append({"uid":uid, "id":item.id, "level":int(item.level)})
	state.rewards_enabled = not (OS.is_debug_build() and "--dev" in OS.get_cmdline_user_args())
	unlocked = meta.unlocked
	state.seed_value = seed_value
	rng.seed = seed_value
	board = BoardController.new(state, data)
	recipes = RecipeSystem.new(state,data)
	shop = ShopController.new(state,data,board,rng,recipes,unlocked)
	shop.open()
	combat = CombatController.new(state, data, board, recipes, rng)
	director = WaveDirector.new()
	paused = false
	speed = 1.0
	accumulator = 0.0
	message = "购买食谱，购物完成后立即开战。"
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

func collect_heat(uid: int) -> String:
	if state.phase != "battle": return "仅战斗中可收取火苗"
	if paused: return "暂停时不能收取火苗"
	combat.collect_heat(uid)
	return ""

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
	combat.heat_pickups.clear()
	state.metrics.passed = state.wave
	var difficulty: DifficultyDef = data.difficulties[state.difficulty]
	state.inspiration_earned[str(state.wave)] = difficulty.reward(data.progression.inspiration_rewards[state.wave - 1]) if state.rewards_enabled else 0
	board.heal(recipes.value("reheat","heal",data.rules.heal))
	if state.wave == data.waves.size():
		state.phase = "won"
		message = "今夜粮仓守住了！"
		settle()
		return
	state.coins += difficulty.reward(data.rules.rewards[state.wave - 1] + (data.rules.bonus if state.leaks <= 1 else 0))
	state.wave += 1
	state.phase = "prepare"
	shop.open()
	state.heat = data.rules.heat_start
	message = "本关灵感 +%d，金币与免费恢复已到账。" % state.inspiration_for_wave(state.wave - 2, data)
	persist()

func persist() -> bool:
	if not persistence or state.phase != "prepare": return true
	if saves.save_run(state,rng): return true
	message = saves.error
	return false

func settle() -> void:
	if persistence and not saves.settle(state,data): message += " " + saves.error

func resume_run() -> bool:
	var meta: Dictionary = saves.load_meta(data)
	unlocked = meta.unlocked
	var meta_error: String = saves.error
	if not meta_error.is_empty():
		message = meta_error
		return false
	var payload: Dictionary = saves.load_run(data)
	if payload.is_empty():
		message = saves.error if not saves.error.is_empty() else meta_error
		return false
	state = saves.restore(payload)
	rng.seed = state.seed_value
	rng.state = int(payload.rng)
	board = BoardController.new(state,data)
	recipes = RecipeSystem.new(state,data)
	shop = ShopController.new(state,data,board,rng,recipes,unlocked)
	if state.phase == "recipe":
		var legacy_choices: Array = state.choices.duplicate()
		state.phase = "prepare"
		shop.open()
		state.choices = legacy_choices
		persist()
	combat = CombatController.new(state,data,board,recipes,rng)
	director = WaveDirector.new()
	paused = false
	accumulator = 0.0
	message = "已恢复准备快照；战斗中退出会回到本关开战前。 " + meta_error
	changed.emit()
	return true
