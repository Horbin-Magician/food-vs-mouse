extends SceneTree

class RecordingSound extends SoundService:
	var heard: Array[String] = []
	func cue(id: String) -> bool:
		heard.append(id)
		return true

var sound := RecordingSound.new()
var hub := CardHub.new()
var saves := SaveService.new()
var data := Catalog.new()

func _init() -> void:
	call_deferred("check")

func expect_cue(id: String) -> void:
	assert(sound.heard == [id], "Expected exactly one %s cue, got %s" % [id, sound.heard])
	sound.heard.clear()

func add_card(id: String) -> String:
	var profile: Dictionary = saves.load_profile(data)
	var uid: String = "card_%d" % int(profile.meta.next_card)
	profile.meta.next_card += 1
	profile.meta.cards.append({"uid":uid,"id":id,"level":0,"starter":false,"locked":false})
	assert(saves.commit_profile(profile,int(profile.revision)))
	assert(hub.model.reload())
	return uid

func check() -> void:
	saves.folder = "user://qa_hub_audio_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(saves.folder)
	root.add_child(hub)
	hub.sound = sound
	hub.setup(saves,data)
	assert(sound.heard.is_empty())
	var profile: Dictionary = saves.load_profile(data)
	profile.meta.inspiration = 100
	assert(saves.commit_profile(profile,int(profile.revision)))
	assert(hub.model.reload())
	hub.rebuild()
	assert(sound.heard.is_empty())
	var buy: Button = hub.find_child("Buy_0",true,false)
	buy.mouse_entered.emit()
	assert(sound.heard.is_empty())
	buy.pressed.emit()
	expect_cue("purchase")
	assert(hub.model.profile.meta.cards.size() == 4)
	# A stale queued button is rejected without playing another purchase cue.
	buy.pressed.emit()
	expect_cue("ui_error")
	assert(hub.model.profile.meta.cards.size() == 4)
	var refresh: Button = hub.find_child("Refresh",true,false)
	refresh.pressed.emit()
	expect_cue("refresh")
	refresh.pressed.emit()
	expect_cue("ui_error")
	assert(hub.model.profile.meta.refreshes == 1)
	var first_material: String = add_card("tea")
	var second_material: String = add_card("pepper")
	hub.tab = "enhance"
	hub.main_uid = "card_1"
	hub.materials = [first_material,second_material]
	hub.rebuild()
	var enhance: Button = hub.find_child("Enhance",true,false)
	enhance.pressed.emit()
	expect_cue("upgrade_success")
	assert(MetaProgression.card(hub.model.profile.meta,"card_1").level == 1)
	enhance.pressed.emit()
	expect_cue("ui_error")
	var failure_material: String = add_card("noodles")
	var random := RandomNumberGenerator.new()
	var found_failure: bool = false
	for value: int in range(100):
		random.seed = value
		var before: int = random.state
		if random.randf() > 0.9:
			profile = saves.load_profile(data)
			profile.meta.rng = str(before)
			assert(saves.commit_profile(profile,int(profile.revision)))
			assert(hub.model.reload())
			found_failure = true
			break
	assert(found_failure)
	hub.materials = [failure_material]
	hub.rebuild()
	var failure: Button = hub.find_child("Enhance",true,false)
	failure.pressed.emit()
	expect_cue("upgrade_fail")
	assert(MetaProgression.card(hub.model.profile.meta,failure_material).is_empty())
	assert(MetaProgression.card(hub.model.profile.meta,"card_1").level == 1)
	var tea: String = add_card("tea")
	var pepper: String = add_card("pepper")
	var noodle: String = add_card("noodles")
	var garlic: String = add_card("garlic")
	hub.tab = "loadout"
	hub.selected = ["card_1","card_2","card_3",tea,pepper]
	hub.choose(noodle)
	expect_cue("ui_error")
	assert(hub.selected.size() == 5 and noodle not in hub.selected)
	hub.choose(pepper)
	expect_cue("ui_cancel")
	hub.choose(noodle)
	expect_cue("ui_click")
	hub.tab = "enhance"
	hub.materials = [tea,pepper,noodle]
	hub.select_material(garlic)
	expect_cue("ui_error")
	assert(hub.materials.size() == 3 and garlic not in hub.materials)
	hub.select_material(pepper)
	expect_cue("ui_cancel")
	hub.select_material(garlic)
	expect_cue("ui_click")
	hub.transact(hub.model.toggle_lock(garlic,int(hub.model.profile.revision)))
	expect_cue("ui_click")
	hub.sound = null
	hub.rebuild()
	hub.choose("card_2")
	assert(sound.heard.is_empty())
	hub.queue_free()
	sound.free()
	await process_frame
	print("PASS hub audio: silent rebuild/hover, single cues for transactions, stale callbacks, enhancement outcomes, selection limits and null service")
	quit()
