extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(42)
	var animator: UnitAnimator = UnitAnimator.new()
	var projection: BoardProjection = BoardProjection.new()
	animator.bind(run, projection)
	run.start()
	animator.advance(0, [])
	for index: int in range(8):
		var id: String = ArtCatalog.FOOD_IDS[index]
		run.state.cards[id] = 1
		run.state.heat = 350
		assert(run.board.place(id, index / 4, index % 4, false) == "")
		assert(animator.entries[run.state.units[-1].uid].drop > 0)
		assert(animator.pose(run.state.units[-1], Vector2.ZERO).offset.y < 0)
	var count: int = animator.entries.size()
	assert(run.board.place("bun", 0, 0, false) != "")
	assert(animator.entries.size() == count)
	for index: int in range(8):
		run.combat.spawn(ArtCatalog.MOUSE_IDS[index], 3, run.data.waves[0])
	animator.advance(0.4, run.combat.enemies)
	for enemy: Dictionary in run.combat.enemies:
		enemy.x -= 5
	animator.advance(0.1, run.combat.enemies)
	for enemy: Dictionary in run.combat.enemies:
		assert(animator.entries[enemy.uid].walking)
		assert(animator.pose(enemy, Vector2.ZERO).offset.y < 0)
		animator.act(enemy.uid)
	# Dense hits must not pin bun/mice to their first reaction frame.
	for actor: Dictionary in [run.state.units[0], run.combat.enemies[0]]:
		animator.hurt(actor)
		animator.advance(0.1, run.combat.enemies)
		var reaction: float = animator.entry(actor).hurt
		animator.hurt(actor)
		assert(is_equal_approx(animator.entry(actor).hurt, reaction))
		animator.advance(0.21, run.combat.enemies)
		animator.hurt(actor)
		assert(animator.entry(actor).hurt == 0.0)
		animator.advance(0.15, run.combat.enemies)
		animator.hurt(actor)
		assert(animator.entry(actor).hurt == UnitAnimator.HURT_TIME)
	# Two normal ticks and one double-speed tick consume equal visual time.
	var reaction_actor: Dictionary = run.combat.enemies[0]
	var reaction_state: Dictionary = animator.entry(reaction_actor).duplicate(true)
	animator.advance(0.05, run.combat.enemies)
	animator.advance(0.05, run.combat.enemies)
	var normal_remaining: float = animator.entry(reaction_actor).hurt
	animator.entries[reaction_actor.uid] = reaction_state
	animator.advance(0.1, run.combat.enemies)
	assert(is_equal_approx(animator.entry(reaction_actor).hurt, normal_remaining))
	# Toast starts undeformed, peaks halfway, and returns smoothly.
	var toast: Dictionary = run.state.units[1]
	var initial_scale: Vector2 = animator.pose(toast, Vector2.ZERO).scale
	animator.food_hurt(toast)
	assert(animator.pose(toast, Vector2.ZERO).scale.is_equal_approx(initial_scale))
	assert(animator.action_pulse(UnitAnimator.HURT_TIME, UnitAnimator.HURT_TIME) == 0.0)
	assert(is_equal_approx(animator.action_pulse(UnitAnimator.HURT_TIME * 0.5, UnitAnimator.HURT_TIME), 1.0))
	assert(animator.action_pulse(0.0, UnitAnimator.HURT_TIME) < 0.00001)
	assert(animator.action_pulse(UnitAnimator.HURT_TIME - 0.001, UnitAnimator.HURT_TIME) < 0.001)
	# Known real speeds advance frames more often, but remain distance driven.
	var walker: Dictionary = run.combat.enemies[0]
	animator.advance(0.5, run.combat.enemies)
	animator.entry(walker).stride = 0.0
	walker.x -= 1.2
	animator.advance(0.1, run.combat.enemies)
	assert(animator.mouse_frame(walker) == Vector2i(1, 0))
	var bun: Dictionary = run.state.units[0]
	animator.time = 10.025
	var idle_frame: Vector2i = animator.bun_frame(bun)
	animator.advance(0.1, run.combat.enemies)
	assert(animator.bun_frame(bun).x == (idle_frame.x + 1) % 6)
	var saved: Dictionary = animator.entries.duplicate(true)
	animator.advance(0, run.combat.enemies)
	assert(saved == animator.entries)
	# Real combat emits attacks and production without relying on presentation timers.
	for enemy: Dictionary in run.combat.enemies: enemy.row = 0; enemy.x = 90
	run.state.units[0].timer = 10
	run.state.units[2].timer = run.data.foods["pudding"].stats.interval
	run.combat.step(1.0 / 60.0)
	assert(animator.entries[run.state.units[0].uid].action > 0)
	assert(animator.entries[run.state.units[2].uid].action > 0)
	run.state.phase = "prepare"
	animator.advance(0, run.combat.enemies)
	var unit: Dictionary = run.state.units[0]
	var other: Dictionary = run.state.units[1]
	var hp: float = unit.hp
	assert(run.board.move(0, 0, 0, 1) == "")
	assert(animator.entries[unit.uid].move > 0 and animator.entries[other.uid].move > 0)
	animator.advance(0.1, run.combat.enemies)
	var shown: Vector2 = animator.pose(unit, projection.foot(144, 0)).foot
	assert(run.board.move(0, 1, 4, 7) == "")
	assert(animator.pose(unit, projection.foot(720, 4)).foot.is_equal_approx(shown))
	animator.advance(0.4, run.combat.enemies)
	assert(animator.pose(unit, projection.foot(720, 4)).foot.is_equal_approx(projection.foot(720, 4)))
	assert(unit.hp == hp)
	run.board.remove(4, 7, false)
	animator.advance(0, run.combat.enemies)
	assert(not animator.entries.has(unit.uid))
	run.new_run(43)
	animator.bind(run, projection)
	assert(animator.entries.is_empty())
	print("PASS animation: all IDs, events, pause, exchange, interruption and cleanup")
	quit()
