extends "res://scenes/main.gd"

# Real combat fixture, isolated from the player's save and gameplay RNG.
var capture_mice: bool = false
var captures: Dictionary = {}

func _ready() -> void:
	run.saves.folder = "user://qa_mouse_combat/"
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	super._ready()
	run.persistence = false
	run.new_run(81)
	run.start()
	animator.bind(run, projection)
	for row: int in range(7):
		run.state.heat = 350
		run.state.cooldowns.clear()
		assert(run.board.place("toast", row, 4, false) == "")
		assert(run.board.place("bun", row, 1, false) == "")
		run.combat.spawn(ArtCatalog.MOUSE_IDS[row], row, run.data.waves[0])
		run.combat.enemies[-1].x = 478.0
		run.combat.spawn(ArtCatalog.MOUSE_IDS[row], row, run.data.waves[0])
		run.combat.enemies[-1].x = 740.0
	run.combat.spawn("boss", 3, run.data.waves[0])
	run.combat.enemies[-1].x = 620.0
	capture_mice = "--capture-mouse-combat" in OS.get_cmdline_user_args()
	rebuild()

func _process(delta: float) -> void:
	super._process(delta)
	if not capture_mice: return
	for enemy: Dictionary in run.combat.enemies:
		var frame: Vector2i = animator.mouse_frame(enemy)
		if frame.y == 1 and frame.x == 2: capture_once("attack")
		if frame.y == 2 and frame.x == 2: capture_once("hurt")
	for corpse: Dictionary in animator.corpses:
		if animator.mouse_frame(corpse).x == 4: capture_once("death")
	if run.state.elapsed > 1.0: capture_once("walk")
	if run.state.elapsed > 12.0:
		assert(captures.size() == 4)
		print("PASS native mouse combat: walk, actual attack, hurt and death rendered")
		get_tree().quit()

func capture_once(label: String) -> void:
	if captures.has(label): return
	captures[label] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/mouse_combat_%s.png" % label)
