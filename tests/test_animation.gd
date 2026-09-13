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
	var saved: Dictionary = animator.entries.duplicate(true)
	animator.advance(0, run.combat.enemies)
	assert(saved == animator.entries)
	# Real combat emits attacks and production without relying on presentation timers.
	for enemy: Dictionary in run.combat.enemies: enemy.row = 0; enemy.x = 90
	run.state.units[0].timer = 10
	run.state.units[2].timer = 10
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
	run.board.remove(4, 7, false, true)
	animator.advance(0, run.combat.enemies)
	assert(not animator.entries.has(unit.uid))
	run.new_run(43)
	animator.bind(run, projection)
	assert(animator.entries.is_empty())
	print("PASS animation: all IDs, events, pause, exchange, interruption and cleanup")
	quit()
