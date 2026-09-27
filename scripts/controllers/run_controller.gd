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
var automatic_start_pending: bool = false
var boss_defeated: bool = false
var message: String = "大关内连续作战，通关后可进入小铺购买食谱。"

func new_run(seed_value: int = 1, selected: Array = [], difficulty: String = "easy", scene_id: String = "kitchen") -> void:
	if not data.difficulties.has(difficulty):
		message = "未知难度"
		return
	if persistence:
		saves.load_meta(data)
		if not saves.error.is_empty():
			message = saves.error
			return
	var scene_issue: String = data.scene_error(scene_id)
	if not scene_issue.is_empty():
		message = scene_issue
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
	state = RunState.new(data)
	state.heat = data.rules.heat_start
	state.difficulty = difficulty
	state.scene_id = scene_id
	state.chapter_id = data.scene_chapters(scene_id)[0]
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
	combat = CombatController.new(state, data, board, recipes, rng)
	combat.enemy_killed.connect(on_enemy_killed)
	director = WaveDirector.new()
	paused = false
	speed = 1.0
	accumulator = 0.0
	message = "准备开战；大关通关后可购买食谱。"
	automatic_start_pending = persist()
	changed.emit()

func start() -> void:
	if state.phase != "prepare": return
	automatic_start_pending = false
	if not persist(): return
	state.phase = "battle"
	state.cooldowns.clear()
	state.leaks = 0
	accumulator = 0.0
	boss_defeated = false
	combat.begin_wave()
	director.begin(data.chapter_waves(state.chapter_id)[state.wave - 1], rng)
	message = "鼠潮来袭！左键选卡再点格子，右键取消。"
	changed.emit()

func collect_heat(uid: int) -> String:
	if state.phase != "battle": return "仅战斗中可收取火苗"
	if paused: return "暂停时不能收取火苗"
	combat.collect_heat(uid)
	return ""

func collect_inspiration(uid: int) -> String:
	if state.phase != "battle": return "仅战斗中可收取灵感"
	if paused: return "暂停时不能收取灵感"
	var pickup: Dictionary = combat.inspiration_pickup(uid)
	if pickup.is_empty(): return ""
	if not state.rewards_enabled: return "调试对局不获得灵感"
	var total: int = combat.inspiration_collected + int(pickup.amount)
	if persistence:
		if not saves.collect_inspiration(state, total, data):
			message = saves.error
			return message
	else:
		var key: String = str(state.global_wave())
		state.inspiration_collected[key] = maxi(int(state.inspiration_collected.get(key, 0)), total)
	combat.collect_inspiration(uid)
	return ""

func advance(delta: float) -> void:
	if state.phase == "prepare" and automatic_start_pending and not shop.is_open() and not paused:
		start()
		if state.phase == "prepare": changed.emit()
		return
	if state.phase != "battle" or paused: return
	accumulator += minf(delta, 0.25) * speed
	while accumulator >= 1.0 / 60.0 and state.phase == "battle" and not paused:
		accumulator -= 1.0 / 60.0
		state.elapsed += 1.0 / 60.0
		for event: Dictionary in director.advance(1.0 / 60.0):
			combat.spawn(event.id, event.row, data.chapter_waves(state.chapter_id)[state.wave - 1])
		combat.step(1.0 / 60.0)
		if state.pantry <= 0:
			state.phase = "lost"
			message = "粮仓失守。调整阵型，再试一次。"
			settle()
		elif director.can_complete(combat.enemies.size()) and not waiting_for_boss():
			finish_wave()
		if state.phase != "battle":
			if state.phase in ["won", "lost"]: combat.clear()
			changed.emit()

func waiting_for_boss() -> bool:
	return state.wave == data.chapter_waves(state.chapter_id).size() and not boss_defeated

func on_enemy_killed(id: String) -> void:
	if state.phase != "battle": return
	var wave: Resource = data.chapter_waves(state.chapter_id)[state.wave - 1]
	if id == wave.stats.get("boss_id", "boss"):
		boss_defeated = true

func finish_wave() -> void:
	if state.phase != "battle": return
	# Last-kill drops are collected before leaving battle; a failed write stays retryable.
	for pickup: Dictionary in combat.inspiration_pickups:
		if pickup.flight < 0.0:
			var failure: String = collect_inspiration(pickup.uid)
			if not failure.is_empty():
				message = failure + "；恢复战斗后重试收取。"
				paused = true
				changed.emit()
				return
	state.metrics.passed = state.global_wave()
	var difficulty: DifficultyDef = data.difficulties[state.difficulty]
	state.inspiration_earned[str(state.global_wave())] = difficulty.reward(data.progression.inspiration_rewards[state.wave - 1]) if state.rewards_enabled else 0
	board.heal(recipes.value("reheat","heal",data.rules.heal))
	if state.wave == data.chapter_waves(state.chapter_id).size():
		var chapters: Array[String] = data.scene_chapters(state.scene_id)
		var chapter_index: int = chapters.find(state.chapter_id)
		if chapter_index == chapters.size() - 1:
			combat.clear()
			state.phase = "won"
			message = "五大关全部守住，厨房迎来黎明！"
			settle()
			return
		state.chapter_id = chapters[chapter_index + 1]
		state.wave = 1
	else:
		state.wave += 1
	state.phase = "prepare"
	if shop.is_open():
		shop.open()
		message = "大关通关！阵地已恢复，选购食谱后继续下一大关。"
	else:
		shop.close()
		message = "灵感已收取，阵地已恢复，准备下一小关。"
	automatic_start_pending = persist() and not shop.is_open()

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
	state.phase = "prepare"
	if not shop.is_open(): shop.close()
	combat = CombatController.new(state,data,board,recipes,rng)
	combat.enemy_killed.connect(on_enemy_killed)
	director = WaveDirector.new()
	paused = false
	accumulator = 0.0
	message = "已恢复准备快照；战斗中退出会回到本关开战前。 " + meta_error
	automatic_start_pending = not shop.is_open()
	changed.emit()
	return true
