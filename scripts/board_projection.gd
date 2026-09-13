class_name BoardProjection
extends RefCounted

const LOGICAL_SIZE: Vector2 = Vector2(768, 390)
const CELL_SIZE: Vector2 = Vector2(96, 78)
# Measured tabletop edges in the background's 1280 x 720 canvas.
const TABLE_BACK_LEFT: Vector2 = Vector2(231, 151)
const TABLE_BACK_RIGHT: Vector2 = Vector2(1086, 151)
const TABLE_FRONT_LEFT: Vector2 = Vector2(100, 600)
const TABLE_FRONT_RIGHT: Vector2 = Vector2(1202, 600)
const BACK_DEPTH: float = (190.0 - 151.0) / 449.0
const FRONT_DEPTH: float = (516.0 - 151.0) / 449.0
var back_left: Vector2 = table_point(0.035, BACK_DEPTH)
var back_right: Vector2 = table_point(0.733, BACK_DEPTH)
var front_left: Vector2 = table_point(0.035, FRONT_DEPTH)
var front_right: Vector2 = table_point(0.733, FRONT_DEPTH)
var hit_cells: Array[PackedVector2Array] = []
var tiles: Array[PackedVector2Array] = []

func _init() -> void:
	for row: int in range(5):
		for col: int in range(8):
			hit_cells.append(polygon(Rect2(Vector2(col, row) * CELL_SIZE, CELL_SIZE)))
			tiles.append(polygon(Rect2(Vector2(col, row) * CELL_SIZE + Vector2(2, 2), CELL_SIZE - Vector2(4, 4))))

static func table_point(u: float, depth: float) -> Vector2:
	return TABLE_BACK_LEFT.lerp(TABLE_FRONT_LEFT, depth).lerp(TABLE_BACK_RIGHT.lerp(TABLE_FRONT_RIGHT, depth), u)

func screen_depth(v: float) -> float:
	var ratio: float = (back_right.x - back_left.x) / (front_right.x - front_left.x)
	return v * ratio / (1.0 - v * (1.0 - ratio))

func project(point: Vector2) -> Vector2:
	var uv: Vector2 = point / LOGICAL_SIZE
	var depth: float = screen_depth(uv.y)
	return back_left.lerp(front_left, depth).lerp(back_right.lerp(front_right, depth), uv.x)

func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([project(rect.position), project(Vector2(rect.end.x, rect.position.y)), project(rect.end), project(Vector2(rect.position.x, rect.end.y))])

func cell_at(point: Vector2) -> Vector2i:
	for index: int in range(hit_cells.size()):
		if Geometry2D.is_point_in_polygon(point, hit_cells[index]):
			return Vector2i(index % 8, index / 8)
	return Vector2i(-1, -1)

func depth_scale(row: int) -> float:
	return lerpf(0.82, 1.0, screen_depth((row + 0.5) / 5.0))

func foot(x: float, row: int) -> Vector2:
	return project(Vector2(x, (row + 0.76) * CELL_SIZE.y))
