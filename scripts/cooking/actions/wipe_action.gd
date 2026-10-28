# WipeAction: wipe a table clean. Spills and crumbs (the session's context
# "spills": [where]) dirty the top; hold the button and scrub the cloth over
# them until they fade away. Done when they're all gone.
class_name WipeAction
extends CookAction

@export var spill_radius := 0.1
@export var scrub_needed := 0.7            # Meters of rubbing over a spill to clean it.
@export var cloth_reach := 0.05            # How far past a spill's edge the cloth still cleans it.
@export var spill_color := Color(0.55, 0.36, 0.2)
@export var crumbs_per_spill := 5

var _spills: Array[Dictionary] = []        # { at, radius, dirt, material, crumbs }
var _cloth := Node3D.new()
var _last := Vector3.ZERO
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
	spill["material"].albedo_color.a = 0.85 * spill["dirt"]
	for crumb in spill["crumbs"]:
		crumb.scale = Vector3.ONE * maxf(spill["dirt"], 0.01)


func _make_spill(at: Vector3) -> Dictionary:
	var radius := spill_radius * randf_range(0.8, 1.2)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(spill_color, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.2
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.002
	mesh.material = material
	disc.mesh = mesh
	disc.position = Vector3(at.x, 0.002, at.z)
	disc.scale = Vector3(randf_range(0.8, 1.2), 1.0, randf_range(0.8, 1.2))
	session.add_child(disc)
	var crumb_material := StandardMaterial3D.new()
	crumb_material.albedo_color = spill_color.darkened(0.25)
	var crumbs: Array[Node3D] = []
	for i in crumbs_per_spill:
		var crumb := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.016, 0.01, 0.012)
		box.material = crumb_material
		crumb.mesh = box
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 1.3)
		crumb.position = Vector3(at.x + offset.x, 0.006, at.z + offset.y)
		crumb.rotation.y = randf() * TAU
		session.add_child(crumb)
		crumbs.append(crumb)
	return { "at": Vector3(at.x, 0.0, at.z), "radius": radius, "dirt": 1.0, "material": material, "crumbs": crumbs }


# A folded cloth: a soft blue pad with a fold on top.
func _build_cloth() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.72, 0.95)
	material.roughness = 0.95
	for part in [[Vector3(0.13, 0.018, 0.1), 0.009], [Vector3(0.13, 0.014, 0.05), 0.025]]:
		var pad := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = material
		pad.mesh = box
		pad.position = Vector3(0.0, part[1], -0.025 if part[1] > 0.01 else 0.0)
		_cloth.add_child(pad)
	_cloth.position = Vector3(0.0, 0.05, 0.3)
	_last = _cloth.position
	session.add_child(_cloth)
