extends Node

# Isolated native-window fixture; never reads or writes a player's real progress.
func _ready() -> void:
	var front = load("res://scenes/front_end.tscn").instantiate()
	front.saves.folder = "user://qa_meta_manual_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(front.saves.folder)
	var model := MetaProgression.new(front.saves,front.data)
	assert(model.reload())
	var profile: Dictionary = front.saves.load_profile(front.data)
	profile.meta.inspiration = 100
	assert(front.saves.commit_profile(profile,int(profile.revision)))
	add_child(front)
