class_name BoardProjection
extends RefCounted

const LOGICAL_SIZE: Vector2 = Vector2(RunState.BOARD_WIDTH, RunState.ROWS * RunState.CELL_WIDTH)
const CELL_SIZE: Vector2 = Vector2(96, 96)
# Orthogonal canvas bounds; logical combat coordinates remain unchanged.
const ORIGIN: Vector2 = Vector2(352, 180)
const CANVAS_SIZE: Vector2 = Vector2(558, 434)
var hit_cells: Array[PackedVector2Array] = []
var tiles: Array[PackedVector2Array] = []

func _init() -> void:
	for row: int in range(RunState.ROWS):
		for col: int in range(RunState.COLS):
			hit_cells.append(polygon(Rect2(Vector2(col, row) * CELL_SIZE, CELL_SIZE)))
			tiles.append(polygon(Rect2(Vector2(col, row) * CELL_SIZE + Vector2(2, 2), CELL_SIZE - Vector2(4, 4))))

func project(point: Vector2) -> Vector2:
	return ORIGIN + point / LOGICAL_SIZE * CANVAS_SIZE

func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([project(rect.position), project(Vector2(rect.end.x, rect.position.y)), project(rect.end), project(Vector2(rect.position.x, rect.end.y))])

func cell_at(point: Vector2) -> Vector2i:
	for index: int in range(hit_cells.size()):
		if Geometry2D.is_point_in_polygon(point, hit_cells[index]):
			return Vector2i(index % RunState.COLS, index / RunState.COLS)
	return Vector2i(-1, -1)

func depth_scale(_row: int) -> float:
	return 0.72

func foot(x: float, row: int) -> Vector2:
	return project(Vector2(x, (row + 0.76) * CELL_SIZE.y))
