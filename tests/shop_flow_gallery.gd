extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.run.new_run(25)
	scene.run.saves.folder = "user://qa_shop_gallery/"
	DirAccess.make_dir_recursive_absolute(scene.run.saves.folder)
	root.add_child(scene)
	scene.run.persistence = false
	await snap("shop")
	scene.shop_surface.get_node("Done").pressed.emit()
	scene.run.paused = true
	await snap("battle")
	root.size = Vector2i(1600, 900)
	await snap("battle_large")
	scene.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_flow_" + label + ".png")
