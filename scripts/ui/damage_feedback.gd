class_name DamageFeedback
extends Node2D

const FLASH_TIME: float = 0.18
const NUMBER_TIME: float = 0.75
const MAX_NUMBERS: int = 160
const FLASH_SHADER: Shader = preload("res://scripts/ui/damage_flash.gdshader")
var numbers: Array[Dictionary] = []
var flashes: Dictionary = {}
var poses: Dictionary = {}
var combat: CombatController
var state: RunState
var projection: BoardProjection
var phase: String = ""
var serial: int = 0

func bind(run: RunController, board_projection: BoardProjection) -> void:
	if state == run.state: return
	if combat != null and combat.damage_resolved.is_connected(on_damage):
		combat.damage_resolved.disconnect(on_damage)
	clear()
	state = run.state
	combat = run.combat
	projection = board_projection
	phase = state.phase
	combat.damage_resolved.connect(on_damage)

func clear() -> void:
	for value: Dictionary in flashes.values(): value.sprite.queue_free()
	flashes.clear()
	numbers.clear()
	poses.clear()
	serial = 0
	queue_redraw()

static func damage_text(amount: float) -> String:
	if amount < 0.1: return "<0.1"
	if is_equal_approx(amount, roundf(amount)): return "%.0f" % amount
	return "%.1f" % amount

func on_damage(unit: Dictionary, amount: float, is_food: bool, direct: bool) -> void:
	var x: float = unit.col * 96.0 + 48.0 if is_food else unit.x
	var foot: Vector2 = projection.foot(x, unit.row)
	var height: float = 52.0
	var side_offset: float = 48.0 if unit.id in ["boss", "elite"] else 0.0
	var overlap: int = 0
	for number: Dictionary in numbers:
		if number.uid == unit.uid and number.age < 0.3: overlap += 1
	var offset: float = float(serial % 3 - 1) * 12.0
	serial += 1
	var tint: Color = Color("ff8d87") if is_food else Color("fff0ae")
	if not direct: tint = Color("ffb265")
	numbers.append({"uid": unit.uid, "text": ("·" if not direct else "") + damage_text(amount), "position": foot + Vector2(offset + side_offset, -height - mini(overlap, 3) * 22.0), "age": 0.0, "color": tint})
	if numbers.size() > MAX_NUMBERS: numbers.pop_front()
	if not flashes.has(unit.uid):
		var sprite := Sprite2D.new()
		var shader_material := ShaderMaterial.new()
		shader_material.shader = FLASH_SHADER
		sprite.material = shader_material
		sprite.centered = false
		sprite.show_behind_parent = true
		add_child(sprite)
		flashes[unit.uid] = {"sprite": sprite, "remaining": FLASH_TIME}
	flashes[unit.uid].remaining = FLASH_TIME
	flashes[unit.uid].sprite.material.set_shader_parameter("strength", 0.9)
	if poses.has(unit.uid): apply_pose(unit.uid)
	queue_redraw()

# Called by the actor renderer so the overlay uses exactly the same animation frame.
func capture_actor(uid: int, texture: Texture2D, foot: Vector2, size: Vector2, pose: Dictionary, depth: float) -> void:
	poses[uid] = {"texture": texture, "position": foot + pose.offset * depth, "size": size, "angle": pose.angle, "scale": pose.scale}
	if flashes.has(uid): apply_pose(uid)

func apply_pose(uid: int) -> void:
	var value: Dictionary = poses[uid]
	var sprite: Sprite2D = flashes[uid].sprite
	sprite.texture = value.texture
	var ratio: Vector2 = value.size / sprite.texture.get_size()
	sprite.transform = Transform2D(value.angle, value.scale, 0.0, value.position) * Transform2D(0.0, ratio, 0.0, Vector2(-value.size.x * 0.5, -value.size.y * 0.86))

func advance(delta: float) -> void:
	if phase != state.phase:
		clear()
		phase = state.phase
	for number: Dictionary in numbers.duplicate():
		number.age += delta
		if number.age >= NUMBER_TIME: numbers.erase(number)
	for uid: int in flashes.keys():
		var value: Dictionary = flashes[uid]
		value.remaining -= delta
		if value.remaining <= 0:
			value.sprite.queue_free()
			flashes.erase(uid)
		else:
			value.sprite.material.set_shader_parameter("strength", 0.9 * value.remaining / FLASH_TIME)
	var live: Dictionary = {}
	for unit: Dictionary in state.units + combat.enemies: live[unit.uid] = true
	for uid: int in poses.keys():
		if not live.has(uid) and not flashes.has(uid): poses.erase(uid)
	queue_redraw()

func _draw() -> void:
	for number: Dictionary in numbers:
		var progress: float = number.age / NUMBER_TIME
		var alpha: float = 1.0 - smoothstep(0.55, 1.0, progress)
		var point: Vector2 = number.position + Vector2(0, -30.0 * progress)
		var font: Font = ThemeDB.fallback_font
		point.x -= font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5
		draw_string_outline(font, point, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.12, 0.07, 0.08, alpha))
		draw_string(font, point, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(number.color, alpha))
