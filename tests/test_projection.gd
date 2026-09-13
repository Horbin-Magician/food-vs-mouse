extends SceneTree

func _init() -> void:
	var board: BoardProjection = BoardProjection.new()
	assert(board.project(Vector2.ZERO).distance_to(Vector2(190, 88)) < 0.1)
	assert(board.project(Vector2(864, 672)).distance_to(Vector2(928, 662)) < 0.1)
	for row: int in range(7):
		for col: int in range(9):
			for offset: Vector2 in [Vector2(48,48), Vector2(1,1), Vector2(95,1), Vector2(1,95), Vector2(95,95)]:
				var screen: Vector2 = board.project(Vector2(col * 96, row * 96) + offset)
				assert(board.cell_at(screen) == Vector2i(col,row), "Projected cell hit mismatch")
	for point: Vector2 in [Vector2(189,88),Vector2(929,88),Vector2(190,663),Vector2(929,662),Vector2(500,87),Vector2(500,663)]:
		assert(board.cell_at(point) == Vector2i(-1,-1))
	for col: int in range(10):
		assert(is_equal_approx(board.project(Vector2(col * 96,0)).x,board.project(Vector2(col * 96,672)).x))
	for row: int in range(8):
		assert(is_equal_approx(board.project(Vector2(0,row * 96)).y,board.project(Vector2(864,row * 96)).y))
	var cell_size: Vector2 = board.project(Vector2(96,96)) - board.project(Vector2.ZERO)
	assert(cell_size == Vector2(82,82) and board.hit_cells.size() == 63)
	assert(board.depth_scale(0) == board.depth_scale(4))
	for row: int in range(7):
		for x: int in range(1,864,31):
			assert(board.cell_at(board.foot(x,row)).y == row)
	print("PASS projection: 315 interior samples, corners, outside rejection, lane trajectories")
	quit()
