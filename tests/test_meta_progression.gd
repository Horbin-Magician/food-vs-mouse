extends SceneTree

class FailingSave extends SaveService:
	var fail_write: bool = false
	func commit_profile(profile: Dictionary, revision: int) -> bool:
		if fail_write:
			error = "injected write failure"
			return false
		return super.commit_profile(profile,revision)

var saves := FailingSave.new()
var data := Catalog.new()
var model: MetaProgression

func _init() -> void:
	saves.folder = "user://qa_meta_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(saves.folder)
	model = MetaProgression.new(saves,data)
	assert(model.reload())
	assert(model.profile.meta.cards.size() == 3 and model.profile.meta.inspiration == 0)
	assert(model.buy(0,revision()) == "灵感不足")
	var p: Dictionary = saves.load_profile(data)
	p.meta.inspiration = 10000
	assert(saves.commit_profile(p,int(p.revision)))
	assert(model.reload())
	var old_revision: int = revision()
	assert(model.buy(0,old_revision).is_empty())
	assert(model.profile.meta.cards.size() == 4)
	assert(not model.buy(0,old_revision).is_empty())
	assert(model.profile.meta.inspiration == 9996)
	for cost: int in [2,4,8]:
		assert(model.refresh_cost() == cost)
		var before: int = int(model.profile.meta.inspiration)
		assert(model.refresh(revision()).is_empty())
		assert(model.profile.meta.inspiration == before-cost)
	var stock: Array = model.profile.meta.offers.duplicate(true)
	assert(model.reload() and model.profile.meta.offers == stock and model.refresh_cost() == 16)
	assert(model.preview("card_1",[]).error != "")
	assert(model.preview("card_1",["card_1"]).error != "")
	assert(model.preview("card_1",["card_2"]).error != "")
	var a: String = add_card("bun",0)
	var b: String = add_card("tea",0)
	var c: String = add_card("toast",0)
	assert(model.preview("card_1",[a,a]).error != "")
	assert(model.preview("card_1",[a,b,c,"card_4"]).error != "")
	assert(is_equal_approx(model.preview("card_1",[a]).chance,0.6))
	assert(model.preview("card_1",[a,b]).chance == 1.0)
	assert(model.preview("card_1",[a,b,c]).chance == 1.0)
	assert(model.toggle_lock(a,revision()).is_empty())
	assert(model.preview("card_1",[a]).error != "")
	assert(model.toggle_lock(a,revision()).is_empty())
	assert(model.enhance("card_1",[a,b],revision()).is_empty())
	assert(MetaProgression.card(model.profile.meta,"card_1").level == 1)
	assert(MetaProgression.card(model.profile.meta,a).is_empty() and MetaProgression.card(model.profile.meta,b).is_empty())
	# Failure consumes the material on both sides of the protection boundary.
	for level: int in [5,6,7]:
		set_main(level)
		var material: String = add_card("pepper",0)
		force_failure()
		assert(model.enhance("card_1",[material],revision()).is_empty())
		assert(MetaProgression.card(model.profile.meta,"card_1").level == (5 if level <= 6 else 6))
		assert(MetaProgression.card(model.profile.meta,material).is_empty())
	set_main(6)
	a = add_card("tea",6)
	b = add_card("pudding",5)
	assert(model.preview("card_1",[a,b]).chance == 1.0)
	assert(model.preview("card_1",[b,a]).chance == model.preview("card_1",[a,b]).chance)
	var disk_before: Dictionary = saves.load_profile(data)
	saves.fail_write = true
	assert(model.enhance("card_1",[a,b],revision()) == "injected write failure")
	assert(saves.load_profile(data) == disk_before)
	saves.fail_write = false
	assert(model.enhance("card_1",[a,b],revision()).is_empty())
	assert(MetaProgression.card(model.profile.meta,"card_1").level == 7)
	set_main(10)
	assert(model.preview("card_1",[c]).error == "主卡已满级")
	assert(MetaProgression.loadout_error(model.profile.meta,["card_2","card_3"],data) != "")
	assert(MetaProgression.loadout_error(model.profile.meta,["card_1","card_2","card_3"],data).is_empty())
	var duplicate: String = add_card("bun",0)
	assert(not MetaProgression.loadout_error(model.profile.meta,["card_1",duplicate],data).is_empty())
	p = saves.load_profile(data)
	p.meta.cards[0].level = -1
	assert(not saves.commit_profile(p,int(p.revision)))
	p = saves.load_profile(data)
	p.meta.refreshes = 30
	assert(saves.commit_profile(p,int(p.revision)))
	model.reload()
	assert(model.refresh(revision()) == "本周期刷新已达安全上限")
	print("PASS meta progression: shop, doubling, reload, stale transactions, materials 1-3, failure boundaries, locks, write rollback, max level, selection")
	quit()

func revision() -> int:
	return int(model.profile.revision)

func add_card(id: String, level: int) -> String:
	var p: Dictionary = saves.load_profile(data)
	var uid: String = "card_%d" % int(p.meta.next_card)
	p.meta.next_card += 1
	p.meta.cards.append({"uid":uid,"id":id,"level":level,"starter":false,"locked":false})
	assert(saves.commit_profile(p,int(p.revision)))
	assert(model.reload())
	return uid

func set_main(level: int) -> void:
	var p: Dictionary = saves.load_profile(data)
	MetaProgression.card(p.meta,"card_1").level = level
	assert(saves.commit_profile(p,int(p.revision)))
	model.reload()

func force_failure() -> void:
	var random := RandomNumberGenerator.new()
	for value: int in range(100):
		random.seed = value
		var before: int = random.state
		if random.randf() > 0.9:
			var p: Dictionary = saves.load_profile(data)
			p.meta.rng = str(before)
			assert(saves.commit_profile(p,int(p.revision)))
			model.reload()
			return
	assert(false)
