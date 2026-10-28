# SeasonAction: season a pot to taste. A shaker follows the cursor; each press
# gives it a shake and a pinch falls. Over the pot it counts toward the meter
# in front of it; off the pot it's wasted on the counter. Get the meter into the
# green band, then stop: once you leave it alone for a moment, that's the
# seasoning. Short of the band is bland, past it is too much.
class_name SeasonAction
extends CookAction

@export var in_surface := "Pot"
@export var seasoning := "Salt"
@export var flake_color := Color(0.97, 0.97, 0.95)
@export var cap_color := Color(0.85, 0.85, 0.88)
@export var band := Vector2(0.55, 0.75)    # The green part of the meter.
@export var pinch := Vector2(0.06, 0.1)    # How much a shake adds (a random amount in this range).
@export var settle_seconds := 1.4          # Leave it this long and the seasoning's done.
@export var meter_offset := Vector3(0.0, 0.02, 0.19)  # In front of the pot, lying flat.
@export var meter_length := 0.32

var _amount := 0.0
var _idle := 0.0
var _shakes := 0
var _shaker: Node3D
var _fill: MeshInstance3D
var _meter := Node3D.new()


func _begin() -> void:
	var pot := session.surface(in_surface)
	_shaker = _make_shaker()
	_shaker.position = pot.position + Vector3(pot.radius() * 1.6, 0.18, 0.0)
	_build_meter(pot.position + meter_offset)


func end() -> void:
	_shaker.queue_free()
	_meter.queue_free()


func cursor_height() -> float:
	return session.surface(in_surface).position.y


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(in_surface)
	var goal := Vector3(input.cursor.x, pot.position.y + 0.2, input.cursor.z)
	_shaker.position = _shaker.position.lerp(goal, 1.0 - exp(-20.0 * delta))
	if input.just_pressed:
		_shake(pot)
	elif _shakes > 0:
		_idle += delta
	var words := "Bland" if _amount < band.x else ("Just right" if _amount <= band.y else "Too much!")
	session.set_status("%s: %s" % [seasoning, words] if _shakes > 0 else "")
	if _shakes > 0 and _idle >= settle_seconds:
		var score := _score()
		session.pop_text(words if score < 1.0 else "Perfect!", pot.position, CookSession.mood_of(score))
		finish(score)


func _shake(pot: CookSurface) -> void:
	_idle = 0.0
	_shakes += 1
	var tween := _shaker.create_tween()  # A quick tip and back.
	tween.tween_property(_shaker, "rotation:z", 2.6, 0.06)
	tween.tween_property(_shaker, "rotation:z", 2.2, 0.1)
	var below := Vector3(_shaker.position.x, pot.position.y, _shaker.position.z)
	var over_pot := pot.contains(below, -0.02)
	session.burst(_shaker.position - Vector3(0.0, 0.05, 0.0), flake_color, 10, 0.15)
	session.play_sound("tick", _shaker.position, -6.0, randf_range(1.6, 2.0))
	if over_pot:
		_amount += randf_range(pinch.x, pinch.y)
		var full := minf(_amount, 1.0)
		_fill.scale.x = maxf(full, 0.001)
		_fill.position.x = (full - 1.0) * meter_length * 0.5
	else:
		session.pop_text("Missed the pot", below, -1)


# Full marks in the band, falling off either side of it.
func _score() -> float:
	if _amount < band.x:
		return clampf(_amount / band.x, 0.0, 1.0) * 0.8
	if _amount <= band.y:
		return 1.0
	return clampf(1.0 - (_amount - band.y) / (1.0 - band.y), 0.0, 1.0) * 0.8


# A flat bar with the green band marked, filling from the left.
func _build_meter(at: Vector3) -> void:
	_meter.position = at
	session.add_child(_meter)
	_meter_box(Vector3(meter_length, 0.002, 0.04), 0.0, Color(0.2, 0.15, 0.1, 0.7), 0.0)
	var band_length := (band.y - band.x) * meter_length
	_meter_box(Vector3(band_length, 0.003, 0.048), ((band.x + band.y) * 0.5 - 0.5) * meter_length, Color(0.4, 0.95, 0.45, 0.6), 0.002)
	_fill = _meter_box(Vector3(meter_length, 0.004, 0.026), 0.0, flake_color, 0.004)
	_fill.scale.x = 0.001
	_fill.position.x = -meter_length * 0.5


func _meter_box(box_size: Vector3, x: float, color: Color, y: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true  # Over the burner grates.
	material.render_priority = roundi(y * 1000.0)  # Back, band, then the fill on top.
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(x, y, 0.0)
	_meter.add_child(node)
	return node


# A glass shaker with a domed cap, held tipped over (its cap toward the pot).
func _make_shaker() -> Node3D:
	var shaker := Node3D.new()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.022
	body_mesh.bottom_radius = 0.026
	body_mesh.height = 0.07
	body_mesh.material = glass
	body.mesh = body_mesh
	shaker.add_child(body)
	var inside := MeshInstance3D.new()
	var inside_mesh := CylinderMesh.new()
	inside_mesh.top_radius = 0.019
	inside_mesh.bottom_radius = 0.022
	inside_mesh.height = 0.04
	var filling := StandardMaterial3D.new()
	filling.albedo_color = flake_color
	inside_mesh.material = filling
	inside.mesh = inside_mesh
	inside.position.y = -0.012
	shaker.add_child(inside)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.024
	cap_mesh.height = 0.03
	var metal := StandardMaterial3D.new()
	metal.albedo_color = cap_color
	metal.metallic = 0.7
	metal.roughness = 0.3
	cap_mesh.material = metal
	cap.mesh = cap_mesh
	cap.position.y = 0.037
	shaker.add_child(cap)
	shaker.rotation.z = 2.2  # Tipped over, cap down and toward the pot.
	session.add_child(shaker)
	return shaker
