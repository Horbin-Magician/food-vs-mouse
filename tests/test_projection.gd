extends SceneTree

func _init() -> void:
	var board: BoardProjection = BoardProjection.new()
	assert(board.project(Vector2.ZERO).distance_to(Vector2(250.2911, 190)) < 0.1)
	assert(board.project(Vector2(768, 390)).distance_to(Vector2(898.4091, 516)) < 0.1)
	for row: int in range(5):
		for col: int in range(8):
			for offset: Vector2 in [Vector2(48,39), Vector2(1,1), Vector2(95,1), Vector2(1,77), Vector2(95,77)]:
				var screen: Vector2 = board.project(Vector2(col * 96, row * 78) + offset)
				assert(board.cell_at(screen) == Vector2i(col,row), "Projected cell hit mismatch")
	for point: Vector2 in [Vector2(115,190),Vector2(905,180),Vector2(100,520),Vector2(920,500),Vector2(500,140),Vector2(500,530)]:
		assert(board.cell_at(point) == Vector2i(-1,-1))
	# Every cross-table line is level, and all depth lines share the table vanishing point.
	var vanishing: Variant = Geometry2D.line_intersects_line(BoardProjection.TABLE_BACK_LEFT, BoardProjection.TABLE_FRONT_LEFT - BoardProjection.TABLE_BACK_LEFT, BoardProjection.TABLE_BACK_RIGHT, BoardProjection.TABLE_FRONT_RIGHT - BoardProjection.TABLE_BACK_RIGHT)
	for col: int in range(9):
		var back: Vector2 = board.project(Vector2(col * 96, 0))
		var front: Vector2 = board.project(Vector2(col * 96, 390))
		assert(absf((front - back).normalized().cross((vanishing - back).normalized())) < 0.0001)
	for row: int in range(6):
		assert(is_equal_approx(board.project(Vector2(0,row * 78)).y, board.project(Vector2(768,row * 78)).y))
	# Perspective grows toward the viewer, and the trajectory stays inside its lane.
	assert(board.depth_scale(0) < board.depth_scale(4))
	for row: int in range(5):
		for x: int in range(1,768,31):
			assert(board.cell_at(board.foot(x,row)).y == row)
	print("PASS projection: 200 interior samples, corners, outside rejection, lane trajectories")
	quit()
