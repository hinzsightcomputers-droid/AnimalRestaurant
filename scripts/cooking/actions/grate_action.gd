# GrateAction: grate cheese, one block after another (four cheeses, four
# colors). Hold the button and rub up and down on the grater; a meter in front
# of the board fills as the block wears away. Let go in the green; keep going
# and you grate the rind. Letting go early just pauses. The shreds pile up on
# the board (its contents), for ScrapeAction.
class_name GrateAction
extends CookAction

@export var on_surface := "Board"
@export var cheeses: Array[String] = ["Cheddar", "Mozzarella", "Parmesan", "Gouda"]
@export var colors: Array[Color] = [Color(0.97, 0.66, 0.2), Color(0.99, 0.96, 0.87), Color(0.96, 0.87, 0.6), Color(0.93, 0.74, 0.33)]
@export var travel := 0.5                  # Meters of rubbing that fills the meter to 1.
@export var band := Vector2(0.6, 0.88)     # The green.
@export var reach := 0.055                 # How far up and down the grater the block goes.
@export var shreds := 12                   # Per cheese.

const LEAST := 0.5                         # What a block grated down to the rind scores.
const HEAP := Vector2(0.06, 0.065)         # How far the shreds spread (x, z) about the heap's middle.
const SCRIPTED_STROKES := 1.6              # Strokes a second for a reel's chef.

var _index := 0
var _amount := 0.0
var _rubbing := false                      # Has been rubbed since the button went down.
var _scores: Array[float] = []
var _grater: Node3D
var _block: Node3D
var _along := 0.0                          # Where the block is on the grater.
var _fill: MeshInstance3D
var _shredded := 0
var _settle := 0.0
var _scripted_time := 0.0


func uses_cursor() -> bool:
	return false


# The board and, beside it, the pot that's boiling away.
func view_point() -> Vector3:
	var board := session.surface(on_surface).position
	var pot := session.surface("Pot")
	return board if pot == null else board.lerp(Vector3(pot.position.x, board.y, pot.position.z), 0.45)


func cursor_height() -> float:
	return session.surface(on_surface).position.y + 0.05


func cursor_area() -> Rect2:
	return session.area_of(on_surface, 0.02)


func _begin() -> void:
	var board := session.surface(on_surface)
	_grater = _make_grater()
	_grater.position = board.position + Vector3(-board.size.x * 0.2, 0.0, 0.0)
	_fill = session.make_meter(board.position + Vector3(0.0, 0.01, board.size.y * 0.5 + 0.05), board.size.x, band, Color(1.0, 0.85, 0.4))
	_next_block()


func end() -> void:
	_grater.queue_free()
	_fill.get_parent().queue_free()
	if is_instance_valid(_block):
		_block.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _settle > 0.0:
		_settle -= delta
		if _settle <= 0.0:
			if _index >= cheeses.size():
				finish(average(_scores))
			else:
				_next_block()
		return
	var board := session.surface(on_surface)
	var goal := 0.0
	if input.using_mouse:
		goal = clampf(input.cursor.z - board.position.z, -reach, reach)
	else:
		goal = clampf(input.stick.y, -1.0, 1.0) * reach
	var before := _along
	_along = lerpf(_along, goal, 1.0 - exp(-22.0 * delta))
	var moved := absf(_along - before)
	var lift := 0.0 if input.held else 0.025
	_block.scale = Vector3(1.0, 1.0 - 0.55 * minf(_amount, 1.0), 1.0)  # Wears away.
	_block.position = _block.position.lerp(_spot(lift), 1.0 - exp(-30.0 * delta))
	if input.held:
		_amount += moved / travel
		if moved / maxf(delta, 0.0001) > 0.1:
			_rubbing = true
		while _shredded < mini(int(_amount / band.x * shreds * 0.8), shreds):
			_drop_shred(board)
		session.set_meter(_fill, _amount)
		if _amount >= 1.0:
			_done_block(LEAST, "Grated the rind!")
			return
	elif _rubbing:
		_rubbing = false
		if _amount >= band.x - 0.02:
			var over := maxf(_amount - band.y, 0.0) / maxf(1.0 - band.y, 0.01)
			_done_block(lerpf(1.0, LEAST, over), "Lovely!" if over <= 0.0 else "A bit of rind")
			return
	var words := "let go!" if _amount >= band.x else ("keep going" if input.held else "hold and rub up and down")
	session.set_status("%s %d/%d: %s" % [cheeses[_index], _index + 1, cheeses.size(), words])


# For a reel: rub, and let go in the green.
func scripted_hold(delta: float, input: CookInput) -> bool:
	_scripted_time += delta
	input.stick = Vector2(0.0, sin(_scripted_time * TAU * SCRIPTED_STROKES))
	return _settle <= 0.0 and _amount < (band.x + band.y) * 0.5


func _done_block(result: float, words: String) -> void:
	_scores.append(result)
	session.pop_text(words, session.surface(on_surface).position, CookSession.mood_of(result))
	session.play_sound("ding" if result >= 1.0 else "clack", _grater.position, -10.0, 1.4)
	var gone := _block
	var tween := gone.create_tween()
	tween.tween_property(gone, "scale", Vector3.ONE * 0.01, 0.2)
	tween.tween_callback(gone.queue_free)
	_index += 1
	_settle = 0.35


func _next_block() -> void:
	_amount = 0.0
	_shredded = 0
	_rubbing = false
	session.set_meter(_fill, 0.0)
	var color := colors[_index % colors.size()]
	(_fill.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = color
	_block = Node3D.new()  # Wears away by scaling this, whatever the cheese's own shape.
	var cheese := KitchenProps.soft_block(Vector3(0.055, 0.05, 0.05), color, 0.6)
	cheese.position.y = 0.025
	_block.add_child(cheese)
	session.add_child(_block)
	_block.position = _spot(0.12)


# Where the block rests on the grater's slope, `lift` off it.
func _spot(lift: float) -> Vector3:
	return _grater.position + Vector3(0.0, 0.052 + lift - _along * 0.35, _along)


func _drop_shred(board: CookSurface) -> void:
	_shredded += 1
	var shred := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.004, 0.005)
	var material := StandardMaterial3D.new()
	material.albedo_color = colors[_index % colors.size()]
	material.roughness = 0.6
	mesh.material = material
	shred.mesh = mesh
	board.add_child(shred)
	board.contents.append(shred)
	var heap := Vector2.from_angle(randf() * TAU) * sqrt(randf())
	var layer := 0.004 + 0.018 * (1.0 - heap.length()) * (_index + 1) / cheeses.size()
	heap *= HEAP
	shred.position = Vector3(-board.size.x * 0.2 + 0.03, 0.04, 0.0)
	shred.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
	var tween := shred.create_tween()
	tween.tween_property(shred, "position", Vector3(board.size.x * 0.22 + heap.x, layer, heap.y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _shredded % 2 == 0:
		session.play_sound("tick", _grater.position, -14.0, randf_range(0.5, 0.7))


# A flat grater propped up on the board, sloping down toward the cook: a steel
# plate with rows of holes between wooden rails.
func _make_grater() -> Node3D:
	var grater := Node3D.new()
	var slope := Node3D.new()
	slope.position.y = 0.04
	slope.rotation.x = atan(0.35)
	grater.add_child(slope)
	var plate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.006, 0.17)
	mesh.material = KitchenProps.steel()
	plate.mesh = mesh
	slope.add_child(plate)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.35, 0.36, 0.36)
	var hole := CylinderMesh.new()
	hole.top_radius = 0.004
	hole.bottom_radius = 0.004
	hole.height = 0.002
	hole.radial_segments = 8
	hole.material = dark
	for row in 7:
		for column in 4:
			var dot := MeshInstance3D.new()
			dot.mesh = hole
			dot.position = Vector3((column - 1.5) * 0.016 + (0.004 if row % 2 == 0 else -0.004), 0.0035, (row - 3) * 0.02)
			slope.add_child(dot)
	var wood := KitchenProps.handle_wood()
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := CapsuleMesh.new()
		rail_mesh.radius = 0.007
		rail_mesh.height = 0.2
		rail_mesh.material = wood
		rail.mesh = rail_mesh
		rail.rotation.x = PI * 0.5
		rail.position = Vector3(side * 0.04, 0.0, 0.0)
		slope.add_child(rail)
	session.add_child(grater)
	return grater
