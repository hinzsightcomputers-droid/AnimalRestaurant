# BoilOverAction: bring the pot up to the boil and turn it down before it boils
# over. The bubbles get busier as the meter rises (PressAction without hold);
# in the green it's at a rolling boil: press the button and the heat goes down
# and the lid goes on to simmer. Too late and the foam climbs the pot and
# spills over the rim. Full marks in the band, less either side.
class_name BoilOverAction
extends PressAction

const FOAM := Color(0.98, 0.95, 0.85)

@export var simmer_seconds := 0.9          # The lid sits on this long before the next step.

var _level := 0.0
var _foam_timer := 0.0
var _lid: Node3D


func _init() -> void:
	hold = false
	surface = "Pot"
	low_word = "Not boiling yet"
	high_word = "Boiled over!"
	good_word = "Rolling boil!"
	rise_seconds = 3.2


func _begin() -> void:
	_level = session.surface(surface).level
	super()


func update(delta: float, input: CookInput) -> void:
	if done:
		return
	super(delta, input)
	var pot := session.surface(surface)
	if _index < _targets.size() and _amount > band.y and pot.liquid != null:  # The foam climbs, then spills over.
		var over := clampf((_amount - band.y) / (1.0 - band.y), 0.0, 1.0)
		pot.fill_to(minf(_level + over * 0.4, 1.05))
		pot.liquid.dress({ "foam": 1.0 })
		_foam_timer -= delta
		if _foam_timer <= 0.0:
			_foam_timer = 0.06
			var round := Vector2.from_angle(randf() * TAU) * pot.radius() * (0.6 + over * 0.45)
			session.burst(Vector3(pot.position.x + round.x, pot.liquid_top() + 0.006, pot.position.z + round.y), FOAM, 4, 0.1 + over * 0.15)
		if over > 0.5 and fmod(_amount, 0.05) < 0.01:
			session.play_sound("sizzle", pot.position, -8.0, 1.4)


func finish(result: float) -> void:
	# Heat down, lid on: it settles to a simmer under the lid, then the step's done.
	var pot := session.surface(surface)
	if pot.liquid != null:
		pot.liquid.set_boil(0.25)
		pot.liquid.dress({ "foam": 0.15 })
		pot.fill_to(_level)
	_lid = _make_lid(pot.radius() * 1.12)
	session.add_child(_lid)
	_lid.position = pot.position + Vector3(0.0, 0.2, 0.0)
	var drop := _lid.create_tween()
	drop.tween_property(_lid, "position:y", pot.liquid_top() + 0.03, 0.25).set_ease(Tween.EASE_IN)
	drop.tween_callback(func(): session.play_sound("clack", pot.position, -4.0, 0.8))
	drop.tween_interval(simmer_seconds)
	drop.tween_property(_lid, "position", pot.position + Vector3(0.25, 0.15, -0.1), 0.3)  # Off again for the seasoning.
	drop.tween_callback(func():
		_lid.queue_free()
		_settled(result))


func _settled(result: float) -> void:
	super.finish(result)


func _make_lid(radius: float) -> Node3D:
	var lid := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.75, 0.74)
	steel.metallic = 0.5
	steel.roughness = 0.3
	var dome := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 0.5
	mesh.is_hemisphere = true
	mesh.material = steel
	dome.mesh = mesh
	lid.add_child(dome)
	var knob := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 0.012
	top.bottom_radius = 0.016
	top.height = 0.02
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.15, 0.12)
	top.material = dark
	knob.mesh = top
	knob.position.y = radius * 0.5 + 0.008
	lid.add_child(knob)
	return lid
