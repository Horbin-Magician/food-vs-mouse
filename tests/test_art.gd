extends SceneTree

# Regression: crossing the old equal-cell dividers produced severed silhouettes
# and unrelated fragments. Check the imported alpha, not just PNG dimensions.
func _init() -> void:
	var catalog: ArtCatalog = ArtCatalog.new()
	var groups: Array[Dictionary] = [catalog.foods, catalog.mice, catalog.recipes]
	var count: int = 0
	for group: Dictionary in groups:
		for texture: AtlasTexture in group.values():
			assert(texture.filter_clip)
			var source: Image = texture.atlas.get_image()
			var region: Rect2 = texture.region
			var left: int = roundi(region.position.x)
			var top: int = roundi(region.position.y)
			var right: int = roundi(region.end.x)
			var bottom: int = roundi(region.end.y)
			var visible: bool = false
			for y: int in range(top, bottom):
				for x: int in range(left, right):
					var alpha: float = source.get_pixel(x, y).a
					if x < left + 16 or x >= right - 16 or y < top + 16 or y >= bottom - 16:
						assert(alpha == 0.0, "Atlas subject crossed transparent gutter")
					visible = visible or alpha > 0.0
			assert(visible, "Atlas cell cannot be empty")
			count += 1
	assert(count == 28)
	assert(catalog.food("unknown") == null and catalog.mouse("unknown") == null and catalog.recipe("unknown") == null)
	print("PASS art: 28 imported sprites with transparent gutters and valid ID mapping")
	quit()
