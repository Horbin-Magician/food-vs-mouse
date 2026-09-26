extends SceneTree

class FailingSave extends SaveService:
	var fail_write: bool = false
	func commit_profile(profile: Dictionary, revision: int) -> bool:
		if fail_write:
			error = "injected collection write failure"
			return false
		return super.commit_profile(profile, revision)

var data := Catalog.new()
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 41
	test_immediate_and_replay()
	test_legacy_assets()
	test_validation()
	print("PASS inspiration save: immediate credit, unchanged preparation, duplicate/replay high water, restore, failure rollback, idempotent loss, legacy assets, optional-field validation")
	quit()

func storage(label: String) -> FailingSave:
	var result := FailingSave.new()
	result.folder = "user://qa_inspiration_%s_%d/" % [label, Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(result.folder)
	return result

func initial_state() -> RunState:
	var result := RunState.new()
	result.run_id = "qa_inspiration"
	result.seed_value = 41
	result.heat = 117.0
	for index: int in range(3):
		var id: String = ["bun", "toast", "pudding"][index]
		result.levels[id] = 0
		result.loadout.append({"uid":"card_%d" % (index + 1), "id":id, "level":0})
	return result

func test_immediate_and_replay() -> void:
	var saves := storage("replay")
	var state := initial_state()
	assert(saves.save_run(state, rng), saves.error)
	var preparation: Dictionary = saves.load_run(data).duplicate(true)
	assert(not preparation.has("coins"))
	state.phase = "battle"
	state.heat = 22.0
	state.elapsed = 50.0
	state.metrics.kills = 6
	assert(saves.collect_inspiration(state, 1, data), saves.error)
	assert(state.collected_inspiration() == 1 and saves.load_meta(data).inspiration == 1)
	var current: Dictionary = saves.load_run(data)
	for field: String in preparation:
		if field != "inspiration_collected": assert(current[field] == preparation[field], "collection changed preparation field " + field)
	var disk: Dictionary = saves.load_profile(data)
	saves.fail_write = true
	assert(not saves.collect_inspiration(state, 3, data))
	assert(state.collected_inspiration() == 1 and saves.load_profile(data) == disk)
	saves.fail_write = false
	assert(saves.collect_inspiration(state, 3, data), saves.error)
	assert(state.collected_inspiration() == 3 and saves.load_meta(data).inspiration == 3)
	disk = saves.load_profile(data)
	for amount: int in [3, 1, 0]:
		state.inspiration_collected.clear()
		assert(saves.collect_inspiration(state, amount, data), saves.error)
		assert(state.collected_inspiration() == 3 and saves.load_profile(data) == disk, "duplicates hydrate without another write")
	# Ledger metadata restores retained collections even if the preparation payload is older.
	disk.run.erase("inspiration_collected")
	assert(saves.commit_profile(disk, int(disk.revision)))
	state = saves.restore(saves.load_run(data))
	assert(state.collected_inspiration() == 3 and state.phase == "prepare" and state.heat == 117.0)
	state.inspiration_collected.clear()
	assert(saves.save_run(state, rng), saves.error)
	assert(state.collected_inspiration() == 3 and saves.load_meta(data).inspiration == 3, "saving a stale snapshot cannot erase or recredit collections")
	state.phase = "battle"
	assert(saves.collect_inspiration(state, 4, data))
	assert(state.collected_inspiration() == 4 and saves.load_meta(data).inspiration == 4)
	# The next wave has its own high water; a recorded zero clear reward isolates pickup credit.
	state.phase = "prepare"
	state.wave = 2
	state.metrics.passed = 1
	state.inspiration_earned["1"] = 0
	assert(saves.save_run(state, rng), saves.error)
	state.phase = "battle"
	assert(saves.collect_inspiration(state, 2, data))
	assert(state.inspiration_collected == {"1":4, "2":2} and saves.load_meta(data).inspiration == 6)
	state.phase = "lost"
	state.pantry = 0
	state.inspiration_collected.clear()
	assert(saves.settle(state, data), saves.error)
	assert(state.collected_inspiration() == 6)
	disk = saves.load_profile(data)
	assert(disk.run.is_empty() and disk.meta.inspiration == 6)
	assert(disk.meta.ledger[state.run_id].summary.inspiration_collected["1"] == 4 and disk.meta.ledger[state.run_id].summary.inspiration_collected["2"] == 2)
	state.inspiration_collected.clear()
	assert(saves.settle(state, data) and state.collected_inspiration() == 6)
	assert(saves.load_profile(data) == disk, "settlement must not repeat pickup rewards or shop refresh")
	state.phase = "battle"
	assert(not saves.collect_inspiration(state, 7, data))
	assert(saves.load_profile(data) == disk)

func test_legacy_assets() -> void:
	var saves := storage("old_v2")
	var state := initial_state()
	assert(saves.save_run(state, rng))
	var profile: Dictionary = saves.load_profile(data)
	profile.run.erase("inspiration_collected")
	profile.run.erase("inspiration_earned")
	profile.run["coins"] = 91
	profile.meta.inspiration = 57
	profile.meta.cards[0].level = 2
	profile.meta.ledger[state.run_id].erase("inspiration_collected")
	profile.meta.ledger["historical"] = {"passed":8, "settled":true, "summary":{"unchanged":true}}
	assert(saves.commit_profile(profile, int(profile.revision)))
	profile = saves.load_profile(data)
	var cards: Array = profile.meta.cards.duplicate(true)
	var historical: Dictionary = profile.meta.ledger.historical.duplicate(true)
	state = saves.restore(saves.load_run(data))
	assert(state.inspiration_collected.is_empty() and state.inspiration_earned.is_empty())
	assert(state.heat == 117.0 and not saves.run_payload(state, rng).has("coins"))
	state.phase = "battle"
	assert(saves.collect_inspiration(state, 2, data))
	profile = saves.load_profile(data)
	assert(profile.meta.inspiration == 59 and profile.meta.cards == cards)
	assert(profile.meta.ledger.historical == historical)
	# Version-1 files still import; obsolete coin amounts do not become heat or inspiration.
	saves = storage("old_v1")
	state = initial_state()
	state.legacy_stars = true
	state.loadout = []
	state.levels = {}
	var payload: Dictionary = saves.run_payload(state, rng)
	payload.erase("inspiration_collected")
	payload.erase("inspiration_earned")
	payload["coins"] = 100
	assert(saves.write_json("run.json", payload))
	assert(saves.write_json("meta.json", {"kills":120, "unlocked":["wide"], "last_run":"old_finished"}))
	profile = saves.load_profile(data)
	assert(not profile.is_empty(), saves.error)
	assert(profile.meta.inspiration == 0 and profile.meta.kills == 120 and profile.meta.cards.size() == 3)
	state = saves.restore(saves.load_run(data))
	assert(state.legacy_stars and state.heat == 117.0 and state.collected_inspiration() == 0)
	state.phase = "battle"
	assert(saves.collect_inspiration(state, 1, data), saves.error)
	assert(saves.load_meta(data).inspiration == 1)
	assert(FileAccess.file_exists(saves.folder.path_join("run.json")))

func test_validation() -> void:
	var saves := storage("validation")
	var state := initial_state()
	var payload: Dictionary = saves.run_payload(state, rng)
	payload["coins"] = "obsolete data is ignored"
	assert(saves.validate(payload, data))
	for invalid: Variant in [null, [], {"0":1}, {"9":1}, {"01":1}, {1:1}, {"1":-1}, {"1":0.5}, {"1":"2"}]:
		payload.inspiration_collected = invalid
		assert(not saves.validate(payload, data))
		var meta: Dictionary = MetaProgression.initial(data)
		meta.ledger["bad"] = {"passed":0, "settled":false, "inspiration_collected":invalid}
		assert(not saves.validate_meta(meta, data))
	payload.inspiration_collected = {"1":0}
	assert(saves.validate(payload, data), "current-wave collections are valid before clearing it")
	payload.inspiration_collected = {"2":1}
	assert(not saves.validate(payload, data), "preparation cannot contain future-wave collections")
	assert(saves.save_run(state, rng))
	var disk: Dictionary = saves.load_profile(data)
	assert(not saves.collect_inspiration(state, 1, data), "preparation is not collectible")
	state.phase = "battle"
	state.rewards_enabled = false
	assert(not saves.collect_inspiration(state, 1, data))
	state.rewards_enabled = true
	state.wave = 2
	assert(not saves.collect_inspiration(state, 1, data))
	state.wave = 1
	state.run_id = "different"
	assert(not saves.collect_inspiration(state, 1, data))
	assert(saves.load_profile(data) == disk and state.collected_inspiration() == 0)
	# A rolled-back preparation cannot erase a later-wave ledger or publish invalid metadata.
	state.run_id = "qa_inspiration"
	disk.meta.ledger[state.run_id].inspiration_collected = {"2":1}
	assert(saves.commit_profile(disk, int(disk.revision)))
	disk = saves.load_profile(data)
	assert(saves.load_run(data).is_empty())
	assert(not saves.collect_inspiration(state, 1, data))
	state.phase = "prepare"
	assert(not saves.save_run(state, rng))
	assert(saves.load_profile(data) == disk)
