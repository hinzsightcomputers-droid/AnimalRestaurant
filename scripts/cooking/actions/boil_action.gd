# BoilAction: boil pasta. A bowl of macaroni follows the cursor; press over the
# pot to tip it in. Then it boils on its own in the background while the cook
# gets on with the next step (grating the cheese), a meter in front of the pot
# filling toward its green part: al dente. DrainAction takes it off the heat,
# in the green or after; the further past it, the mushier.
class_name BoilAction
extends CookAction

@export var in_surface := "Pot"
@export var pasta := 36                     # Pieces of it.
@export var boil_seconds := 15.0            # Boiling this long is just right (longer on Easy).
@export var perfect_from := 0.85            # Share of boil_seconds where the green starts...
@export var perfect_to := 1.45              # ...and ends: wide, as there's cheese to grate meanwhile.
@export var mushy_at := 2.2                 # Boiled this far it scores least (the end of the meter).
@export_range(0.0, 1.0) var least_score := 0.35
@export var pasta_color := Color(0.97, 0.86, 0.55)
@export var water_color := Color(0.58, 0.82, 0.92, 0.7)
@export var meter_offset := Vector3(0.0, 0.02, 0.19)  # In front of the pot, lying flat.
@export var meter_length := 0.32

const SCRIPTED_PACE := 2.5      # A reel doesn't wait around: this much faster once there's only the pasta to wait for.

var doneness := 0.0             # 1 is boil_seconds.
var _boiling := false
var _tipped := false
var _bowl: Node3D
var _fill: MeshInstance3D
var _bubbles: CPUParticles3D
var _steam: CPUParticles3D
var _sound: AudioStreamPlayer3D
var _label: Label3D
var _bits: Array[Node3D] = []
var _time := 0.0


func uses_cursor() -> bool:
	return false  # The bowl shows the spot.


func view_point() -> Vector3:
	return session.surface(in_surface).position


func cursor_height() -> float:
	return session.surface(in_surface).position.y


func _begin() -> void:
	var pot := session.surface(in_surface)
	pot.fill_to(1.0, water_color)
	var water := pot.liquid.mesh.surface_get_material(0) as StandardMaterial3D
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	_bowl = _make_bowl()
	_bowl.position = pot.position + Vector3(pot.radius() * 1.7, 0.2, 0.0)
	_bubbles = _make_bubbles(pot)
	_steam = session.make_steam(pot.radius())
	_steam.position = Vector3(pot.position.x, pot.liquid_top(), pot.position.z)
	session.add_child(_steam)
	_steam.emitting = true
	_sound = session.loop_sound("sizzle", -18.0)
	_sound.pitch_scale = 0.55  # Lower: a rolling boil, not a fry.
	_sound.position = pot.position
	_sound.play()


func end() -> void:
	if is_instance_valid(_bowl):
		_bowl.queue_free()
	if _fill != null:
		_fill.get_parent().queue_free()
	if _label != null:
		_label.queue_free()
	_sound.queue_free()
	_bubbles.emitting = false
	_steam.emitting = false


func update(delta: float, input: CookInput) -> void:
	_time += delta
	var pot := session.surface(in_surface)
	if not _tipped:
		var goal := Vector3(input.cursor.x, pot.liquid_top() + 0.16, input.cursor.z)
		_bowl.position = _bowl.position.lerp(goal, 1.0 - exp(-18.0 * delta))
		session.set_status("The water's boiling")
		if input.just_pressed:
			if pot.contains(input.cursor, 0.04):
				_tip(pot)
			else:
				session.pop_text("Over the pot!", pot.position, 0)
		return
	if not _boiling:
		return
	var pace := SCRIPTED_PACE if input.scripted and session.current is DrainAction else 1.0
	doneness += delta * pace / boil_seconds * GameState.difficulty_value("closeup_pace")
	session.set_meter(_fill, doneness / mushy_at)
	var ready := doneness >= perfect_from
	var late := doneness > perfect_to
	if ready and not _label.visible:
		session.play_sound("ding", pot.position, -8.0, 1.6)
	_label.visible = ready
	_label.text = "Getting mushy!" if late else "Al dente!"
	_label.modulate = Color(1.0, 0.6, 0.3) if late else Color(0.6, 1.0, 0.55)
	_label.position = Vector3(pot.position.x, pot.liquid_top() + 0.1 + sin(_time * 8.0) * 0.008, pot.position.z)
	_bob(pot)


# Off the heat: scored by how long it boiled, and it's done.
func take_off() -> void:
	if done:
		return
	var result := score_now()
	var words := "Al dente!" if result >= 1.0 else "Mushy!"
	session.pop_text(words, session.surface(in_surface).position, CookSession.mood_of(result))
	finish(result)


func score_now() -> float:
	if doneness <= perfect_to:
		return 1.0
	return lerpf(1.0, least_score, clampf((doneness - perfect_to) / (mushy_at - perfect_to), 0.0, 1.0))


# The pasta that went in, for the drain to move about.
func bits() -> Array[Node3D]:
	return _bits


# For a reel: over the pot, and in.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _tipped:
		return false
	return input.move_to(session.surface(in_surface).position, delta) and not input.held


func _tip(pot: CookSurface) -> void:
	_tipped = true
	session.set_status("")
	var over := Vector3(pot.position.x + pot.radius() * 0.5, pot.liquid_top() + 0.16, pot.position.z)
	var tween := _bowl.create_tween()
	tween.tween_property(_bowl, "position", over, 0.12)
	tween.tween_property(_bowl, "rotation:z", deg_to_rad(115.0), 0.25).set_trans(Tween.TRANS_QUAD)
	var mesh := macaroni_mesh(pasta_color)
	for i in pasta:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		bit.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
		pot.add_child(bit)
		pot.contents.append(bit)
		_bits.append(bit)
		var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * pot.radius() * 0.75
		bit.position = Vector3(pot.radius() * 0.4, pot.depth + 0.14, 0.0)
		bit.set_meta("rest", randf() * TAU)
		bit.visible = false
		var fall := bit.create_tween()
		fall.tween_interval(0.25 + i * 0.012)
		fall.tween_callback(func(): bit.visible = true)
		fall.tween_property(bit, "position", Vector3(spot.x, pot.depth, spot.y), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if i % 4 == 0:
			fall.tween_callback(func():
				session.play_sound("plop", pot.position, -8.0, 1.3)
				session.burst(pot.position + bit.position, Color(water_color, 1.0), 4, 0.2))
	tween.tween_interval(0.25 + pasta * 0.012)
	tween.tween_callback(func():
		_bowl.queue_free()
		_start_boiling(pot))


func _start_boiling(pot: CookSurface) -> void:
	_boiling = true
	_fill = session.make_meter(pot.position + meter_offset, meter_length, Vector2(perfect_from, perfect_to) / mushy_at, Color(1.0, 0.85, 0.4))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 56
	_label.outline_size = 18
	_label.pixel_size = session.text_size * 0.5
	_label.outline_modulate = Color(0.2, 0.12, 0.08)
	_label.visible = false
	session.add_child(_label)
	to_background = true  # On to the next step, the pasta boiling away.


# Riding up and down on the boil.
func _bob(pot: CookSurface) -> void:
	for bit in _bits:
		if is_instance_valid(bit):
			bit.position.y = pot.depth * minf(pot.level, 1.0) - 0.004 + sin(_time * 5.0 + float(bit.get_meta("rest"))) * 0.006


# One elbow of macaroni: a fat half ring, as one mesh to share.
static func macaroni_mesh(color: Color) -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radius = 0.0075
	ball.height = 0.015
	ball.radial_segments = 8
	ball.rings = 4
	var tool := SurfaceTool.new()
	const BALLS := 6
	for i in BALLS:
		var angle := PI * 0.9 * i / (BALLS - 1)
		tool.append_from(ball, 0, Transform3D(Basis.IDENTITY, Vector3(cos(angle), 0.0, sin(angle) - 0.5) * 0.014))
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	mesh.surface_set_material(0, material)
	return mesh


# A cream bowl heaped with macaroni.
func _make_bowl() -> Node3D:
	var bowl := Node3D.new()
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.07
	cup_mesh.bottom_radius = 0.045
	cup_mesh.height = 0.06
	var cream := StandardMaterial3D.new()
	cream.albedo_color = KitchenProps.CREAM
	cream.roughness = 0.45
	cup_mesh.material = cream
	cup.mesh = cup_mesh
	bowl.add_child(cup)
	var mesh := macaroni_mesh(pasta_color)
	for i in 12:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		var spot := Vector2.from_angle(i * 2.4) * 0.048 * sqrt(i / 12.0)
		bit.position = Vector3(spot.x, 0.034, spot.y)
		bit.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, 0.0)
		bowl.add_child(bit)
	session.add_child(bowl)
	return bowl


func _make_bubbles(pot: CookSurface) -> CPUParticles3D:
	var bubbles := CPUParticles3D.new()
	bubbles.amount = 26
	bubbles.lifetime = 0.5
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = pot.radius() * 0.8
	bubbles.direction = Vector3.UP
	bubbles.spread = 5.0
	bubbles.initial_velocity_min = 0.01
	bubbles.initial_velocity_max = 0.04
	bubbles.gravity = Vector3.ZERO
	bubbles.scale_amount_min = 0.4
	bubbles.scale_amount_max = 1.2
	bubbles.mesh = session.dot_mesh(0.009, Color(0.93, 0.98, 1.0, 0.75))
	bubbles.scale.y = 0.15  # Flat on the water.
	bubbles.position = Vector3(pot.position.x, pot.liquid_top(), pot.position.z)
	session.add_child(bubbles)
	return bubbles
