extends SceneTree

func _init() -> void:
	var art := ArtCatalog.new()
	assert(ArtCatalog.CHAPTER_MOUSE_IDS.size() == 16)
	var all_sheets: Dictionary = {}
	var count := 0
	var valid := true
	for id: String in ArtCatalog.CHAPTER_MOUSE_IDS:
		assert(art.mouse(id) != null, "Missing portrait: " + id)
		assert(art.mouse_frames.has(id), "Missing basic atlas: " + id)
		valid = check_sheet(art.mouse_frames[id], 4, id) and valid
		assert(art.enemy_skill_frames.has(id), "Missing skill atlas: " + id)
		valid = check_sheet(art.enemy_skill_frames[id], 3, id + ":skill") and valid
		var digest := sheet_hash(art.mouse_frames[id])
		assert(not all_sheets.has(digest), "Two characters must not share the same drawing")
		all_sheets[digest] = id
		assert(art.mouse(id) == art.mouse_frames[id][0])
		count += 24 + 18
	for id: String in ArtCatalog.UNARMORED_IDS:
		assert(art.unarmored_frames.has(id), "Missing unarmored atlas: " + id)
		valid = check_sheet(art.unarmored_frames[id], 4, id + ":unarmored") and valid
		assert(sheet_hash(art.unarmored_frames[id]) != sheet_hash(art.mouse_frames[id]))
		assert(art.mouse_frame_for_state(id, Vector2i.ZERO, true) == art.unarmored_frames[id][0])
		count += 24
	for id: String in ["rivet_foreman", "boss_ironpot"]:
		assert(art.unarmored_skill_frames.has(id), "Missing unarmored skill: " + id)
		valid = check_sheet(art.unarmored_skill_frames[id], 3, id + ":unarmored_skill") and valid
		assert(art.skill_frame(id, Vector2i.ZERO, true) == art.unarmored_skill_frames[id][0])
		count += 18
	assert(art.skill_frame("unknown", Vector2i.ZERO) == null)
	if not valid:
		quit(1)
		return
	print("PASS chapter enemy art: 16 unique characters, 19 basic atlases, 18 skill atlases, %d transparent frames" % count)
	quit()

func sheet_hash(frames: Array) -> int:
	return hash(frames[0].atlas.get_image().get_data())

func check_sheet(frames: Array, rows: int, label: String) -> bool:
	if frames.size() != rows * 6: return reject("Frame count: " + label)
	var sheet: Image = frames[0].atlas.get_image()
	if sheet.get_size() != Vector2i(1536, rows * 256): return reject("Atlas dimensions: " + label)
	if sheet.detect_alpha() == Image.ALPHA_NONE: return reject("Actual alpha required: " + label)
	for row: int in range(rows):
		var unique_frames: Dictionary = {}
		for col: int in range(6):
			var texture: AtlasTexture = frames[row * 6 + col]
			if not texture.filter_clip: return reject("Filter clip required: " + label)
			if texture.region != Rect2(col * 256, row * 256, 256, 256): return reject("Region: " + label)
			var frame := sheet.get_region(Rect2i(texture.region))
			var bounds := frame.get_used_rect()
			if bounds.size.x < 60 or bounds.size.y < 40: return reject("Empty or tiny frame: " + label)
			if bounds.position.x < 16 or bounds.position.y < 16: return reject("Gutter: " + label)
			if bounds.end.x > 240 or bounds.end.y > 220: return reject("Overflow/baseline: " + label)
			unique_frames[hash(frame.get_data())] = true
		if unique_frames.size() < 4: return reject("Animation must contain distinct poses: " + label)
	return true

func reject(message: String) -> bool:
	push_error(message)
	return false
