# WipeAction: wipe a table clean. Spills and crumbs (the session's context
# "spills": [where]) dirty the top; hold the button and scrub the cloth over
# them until they fade away. Done when they're all gone.
class_name WipeAction
extends CookAction

@export var spill_radius := 0.1
@export var scrub_needed := 0.4            # Meters of rubbing over a spill to clean it.
@export var cloth_reach := 0.09            # How far past a spill's edge the cloth still cleans it.
@export var spill_color := Color(0.55, 0.36, 0.2)
@export var crumbs_per_spill := 5

var _spills: Array[Dictionary] = []        # { at, radius, dirt, material, crumbs }
var _cloth := Node3D.new()
var _last := Vector3.ZERO
var _rubbed := 0.0                         # How far the cloth's gone since it last left a streak.
var _swish: AudioStreamPlayer3D


func _begin() -> void:
	for at in session.context.get("spills", []):
		_spills.append(_make_spill(at))
	_build_cloth()
	_swish = session.loop_sound("drizzle", -40.0)
	_swish.play()


func uses_cursor() -> bool:
	return false


func end() -> void:
	_cloth.queue_free()
	_swish.queue_free()


func update(delta: float, input: CookInput) -> void:
	var goal := Vector3(input.cursor.x, 0.012 if input.held else 0.05, input.cursor.z)
	_cloth.position = _cloth.position.lerp(goal, 1.0 - exp(-22.0 * delta))
	var moved := Vector2(_cloth.position.x - _last.x, _cloth.position.z - _last.z).length() if input.held else 0.0
	_last = _cloth.position
	_cloth.rotation.y += moved * 6.0  # It twists as you rub.
	_cloth.scale = _cloth.scale.lerp(Vector3(1.05, 0.75, 1.05) if input.held else Vector3.ONE, 1.0 - exp(-16.0 * delta))
	_rubbed += moved
	if _rubbed > 0.05:
		_rubbed = 0.0
		_leave_streak()
	for spill in _spills:  # Crumbs get pushed along in front of it.
		for crumb: Node3D in spill["crumbs"]:
			var off := Vector2(crumb.position.x - _cloth.position.x, crumb.position.z - _cloth.position.z)
			if input.held and off.length() < 0.075:
				var to := off.normalized() * 0.076
				crumb.position.x = _cloth.position.x + to.x
				crumb.position.z = _cloth.position.z + to.y
				crumb.rotate_y(moved * 20.0)
	_swish.volume_db = lerpf(-40.0, -12.0, clampf(moved / maxf(delta, 0.001) / 0.6, 0.0, 1.0))

	var left := 0
	for spill in _spills:
		if spill["dirt"] <= 0.0:
			continue
		var gap := Vector2(_cloth.position.x - spill["at"].x, _cloth.position.z - spill["at"].z).length()
		if moved > 0.0 and gap <= spill["radius"] + cloth_reach:
			spill["dirt"] = maxf(spill["dirt"] - moved / scrub_needed, 0.0)
			_show_dirt(spill)
			if spill["dirt"] <= 0.0:
				session.burst(spill["at"] + Vector3(0.0, 0.02, 0.0), Color(1.0, 1.0, 0.9), 10, 0.3)
				session.play_sound("ding", spill["at"], -10.0, 1.5)
				session.pop_text("Clean!", spill["at"], 1)
		if spill["dirt"] > 0.0:
			left += 1
	session.set_status("Spills left: %d" % left)
	if left == 0:
		finish(1.0)


func _show_dirt(spill: Dictionary) -> void:
	spill["material"].set_shader_parameter("left", spill["dirt"])
	for crumb in spill["crumbs"]:
		crumb.scale = Vector3.ONE * maxf(spill["dirt"], 0.01)


func _make_spill(at: Vector3) -> Dictionary:
	var radius := spill_radius * randf_range(0.8, 1.2)
	var material := _puddle(spill_color)
	var disc := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * radius * 2.8
	disc.mesh = mesh
	disc.material_override = material
	disc.position = Vector3(at.x, 0.002, at.z)
	disc.scale = Vector3(randf_range(0.8, 1.2), 1.0, randf_range(0.8, 1.2))
	session.add_child(disc)
	var crumb_material := StandardMaterial3D.new()
	crumb_material.albedo_color = spill_color.lightened(0.1)
	crumb_material.set_meta(ToonStyle.FOOD, "baked")
	var crumbs: Array[Node3D] = []
	for i in crumbs_per_spill:
		var crumb := MeshInstance3D.new()
		crumb.mesh = PlaceAction.rounded_block(Vector3(0.016, 0.01, 0.012) * randf_range(0.6, 1.1), 0.0035)
		crumb.material_override = crumb_material
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 1.3)
		crumb.position = Vector3(at.x + offset.x, 0.006, at.z + offset.y)
		crumb.rotation.y = randf() * TAU
		session.add_child(crumb)
		crumbs.append(crumb)
	return { "at": Vector3(at.x, 0.0, at.z), "radius": radius, "dirt": 1.0, "material": material, "crumbs": crumbs }


func _puddle(color: Color) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = preload("res://assets/shaders/spill.gdshader")
	look.set_shader_parameter("spill", color)
	look.set_shader_parameter("seed", randf() * 20.0)
	return look


# The wet streak behind the cloth, drying away.
func _leave_streak() -> void:
	var streak := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.15, 0.13)
	streak.mesh = mesh
	var look := _puddle(Color(0.95, 0.97, 1.0))
	look.set_shader_parameter("film", 1.0)
	streak.material_override = look
	streak.position = Vector3(_cloth.position.x, 0.0012 + randf() * 0.0006, _cloth.position.z)
	streak.rotation.y = randf() * TAU
	session.add_child(streak)
	var dry := streak.create_tween()
	dry.tween_method(func(left: float): look.set_shader_parameter("left", left), 1.0, 0.0, 2.4).set_delay(0.3)
	dry.tween_callback(streak.queue_free)


# A folded cloth: a soft blue pad with a fold on top.
func _build_cloth() -> void:
	var blue := Color("#7FB8E0")
	var pad := KitchenProps.soft_block(Vector3(0.13, 0.018, 0.1), blue)
	pad.position.y = 0.009
	_cloth.add_child(pad)
	var fold := KitchenProps.soft_block(Vector3(0.13, 0.014, 0.05), blue.lightened(0.08))
	fold.position = Vector3(0.0, 0.025, -0.025)
	_cloth.add_child(fold)
	_cloth.position = Vector3(0.0, 0.05, 0.3)
	_last = _cloth.position
	session.add_child(_cloth)


# --- For a reel -----------------------------------------------------------------

var _scripted_angle := 0.0


# Small circles over each spill till it's gone.
func scripted_hold(delta: float, input: CookInput) -> bool:
	for spill in _spills:
		if spill["dirt"] > 0.0:
			_scripted_angle += delta * 12.0
			var round_it := Vector3(cos(_scripted_angle), 0.0, sin(_scripted_angle)) * float(spill["radius"]) * 0.7
			input.move_to((spill["at"] as Vector3) + round_it, delta, 0.8)
			return true
	return false
