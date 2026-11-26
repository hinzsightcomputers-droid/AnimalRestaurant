# WokTossAction: the drained noodles go into a hot wok with chili sauce and are
# tossed, in rhythm. The pot becomes a wok over a roaring flame (the pot
# surface stays, so what's in it is what's tossed, and the steps after still
# put things on it). A ring closes in on the noodles; press as it meets them
# and the wok jerks, the noodles fly up and drop back, and flames leap up the
# side, bigger the closer to the beat. Every toss works the chili sauce
# through: the noodles go from pale to fiery red. Each toss scores how close
# to the ring it was.
class_name WokTossAction
extends CookAction

const WOK_STEEL := Color(0.16, 0.16, 0.17)
const CHILI := Color(0.86, 0.22, 0.1)

@export var in_surface := "Pot"
@export var tosses := 6
@export var beat_seconds := 0.9
@export var tolerance := 0.25
@export var perfect_seconds := 0.08
@export var hide_node := "PotModel"         # The pot's model, swapped for the wok.

var _wok: Node3D
var _ring: MeshInstance3D
var _flames: CPUParticles3D
var _clock := 0.0
var _done := 0
var _scores: Array[float] = []
var _busy := false
var _paints: Array[StandardMaterial3D] = []
var _start_colors: Array[Color] = []
var _sizzle: AudioStreamPlayer3D


func _init() -> void:
	view_distance = 0.55
	view_pitch = 56.0


func view_point() -> Vector3:
	return session.surface(in_surface).position


func uses_cursor() -> bool:
	return false


func aims() -> bool:
	return false


func _begin() -> void:
	var pot := session.surface(in_surface)
	var old := session.get_node_or_null(hide_node)
	if old != null:
		old.visible = false
	if pot.liquid != null:  # What water was left goes with the drain.
		pot.liquid.visible = false
	_wok = _make_wok(pot.radius() * 1.5)
	pot.add_child(_wok)
	_wok.position.y = -0.012
	_flames = _make_flames(pot.radius() * 1.2)
	session.add_child(_flames)
	_flames.position = pot.position + Vector3(0.0, -0.03, 0.0)
	var seen := {}
	for piece in pot.contents:  # The noodles' paint, once each, to turn them red.
		if piece is MeshInstance3D and is_instance_valid(piece):
			var paint := (piece as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D if (piece as MeshInstance3D).mesh != null else null
			if paint != null and not seen.has(paint):
				seen[paint] = true
				_paints.append(paint)
				_start_colors.append(paint.albedo_color)
	session.burst(pot.position + Vector3(0.0, 0.03, 0.0), CHILI, 16, 0.3)  # The sauce goes in.
	_ring = session.make_ring(pot.radius() * 0.6, Color(1.0, 1.0, 1.0, 0.9))
	_ring.position = pot.position + Vector3(0.0, 0.03, 0.0)
	_sizzle = session.loop_sound("sizzle", -10.0)
	_sizzle.position = pot.position
	_sizzle.play()


func end() -> void:
	if _ring != null:
		_ring.queue_free()
	if _sizzle != null:
		_sizzle.queue_free()
	if _flames != null:
		_flames.emitting = false


func update(delta: float, input: CookInput) -> void:
	if done:
		return
	_clock += delta * GameState.difficulty_value("closeup_pace")
	var phase := fmod(_clock, beat_seconds) / beat_seconds
	_ring.scale = Vector3.ONE * lerpf(2.4, 1.0, phase)
	_ring.visible = not _busy
	session.set_status("Tosses: %d of %d" % [_done, tosses])
	if input.just_pressed and not _busy:
		var off := minf(fmod(_clock, beat_seconds), beat_seconds - fmod(_clock, beat_seconds))
		_toss(1.0 - clampf((off - perfect_seconds) / (tolerance - perfect_seconds), 0.0, 1.0))


func _toss(score: float) -> void:
	_busy = true
	_done += 1
	_scores.append(score)
	var pot := session.surface(in_surface)
	session.pop_text("Whoosh!" if score >= 0.85 else ("Toss!" if score >= 0.4 else "Clunk"), pot.position + Vector3(0.0, 0.08, 0.0), CookSession.mood_of(score))
	session.play_sound("whoosh", pot.position, -4.0, 0.9 + score * 0.2)
	# Flames up the side, bigger for a good one.
	_flames.amount = int(lerpf(20.0, 70.0, score))
	_flames.initial_velocity_max = lerpf(0.3, 0.9, score)
	_flames.restart()
	_flames.emitting = true
	var red := clampf(float(_done) / tosses, 0.0, 1.0)
	for i in _paints.size():
		_paints[i].albedo_color = _start_colors[i].lerp(CHILI, red * 0.85)
	var home := pot.position
	var jerk := pot.create_tween()
	jerk.tween_property(pot, "position", home + Vector3(-0.03, 0.02, 0.0), 0.08)
	jerk.parallel().tween_property(pot, "rotation:z", deg_to_rad(10.0), 0.08)
	for piece in pot.contents:  # Up they go, and back down.
		if piece is Node3D and is_instance_valid(piece):
			var node := piece as Node3D
			var rest := node.position
			var fly := node.create_tween()
			fly.tween_property(node, "position", rest + Vector3(randf_range(-0.02, 0.03), randf_range(0.05, 0.1) * (0.5 + score), randf_range(-0.02, 0.02)), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			fly.parallel().tween_property(node, "rotation:y", node.rotation.y + randf_range(-1.5, 1.5), 0.36)
			fly.tween_property(node, "position", rest, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	jerk.tween_property(pot, "position", home, 0.2)
	jerk.parallel().tween_property(pot, "rotation:z", 0.0, 0.2)
	jerk.tween_callback(func():
		_busy = false
		if _done >= tosses:
			session.pop_text("Fiery!" if average(_scores) >= 0.8 else "Saucy", home, CookSession.mood_of(average(_scores)))
			finish(average(_scores)))


# Presses right on the beat.
func scripted_hold(_delta: float, _input: CookInput) -> bool:
	if _busy:
		return false
	var at := fmod(_clock, beat_seconds)
	return at > beat_seconds - 0.03 or at < 0.02


# A dark steel wok: a wide shallow bowl with a long handle and a little loop
# opposite, origin at its bottom.
func _make_wok(radius: float) -> Node3D:
	var wok := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = WOK_STEEL
	steel.metallic = 0.6
	steel.roughness = 0.35
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bowl := MeshInstance3D.new()  # Open at the top: wide and shallow.
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.45
	mesh.height = radius * 0.35
	mesh.cap_top = false
	mesh.radial_segments = 32
	mesh.material = steel
	bowl.mesh = mesh
	bowl.position.y = radius * 0.175
	wok.add_child(bowl)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.004
	ring.outer_radius = radius + 0.004
	ring.material = steel
	rim.mesh = ring
	rim.position.y = radius * 0.35
	wok.add_child(rim)
	var handle := MeshInstance3D.new()
	var grip := CylinderMesh.new()
	grip.top_radius = 0.012
	grip.bottom_radius = 0.014
	grip.height = 0.18
	handle.mesh = grip
	handle.material_override = KitchenProps.handle_wood()
	handle.rotation.z = PI * 0.5 - 0.25
	handle.position = Vector3(radius + 0.08, radius * 0.35 + 0.02, 0.0)
	wok.add_child(handle)
	return wok


func _make_flames(radius: float) -> CPUParticles3D:
	var flames := CPUParticles3D.new()
	flames.amount = 30
	flames.lifetime = 0.45
	flames.one_shot = true
	flames.explosiveness = 0.8
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	flames.emission_ring_axis = Vector3.UP
	flames.emission_ring_radius = radius
	flames.emission_ring_inner_radius = radius * 0.8
	flames.emission_ring_height = 0.01
	flames.direction = Vector3.UP
	flames.spread = 25.0
	flames.gravity = Vector3(0.0, 0.6, 0.0)
	flames.initial_velocity_min = 0.2
	flames.initial_velocity_max = 0.6
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.4
	var ball := SphereMesh.new()
	ball.radius = 0.012
	ball.height = 0.024
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = Color(1.0, 0.55, 0.15)
	fire.vertex_color_use_as_albedo = true
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = fire
	flames.mesh = ball
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.4))
	fade.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	flames.color_ramp = fade
	flames.emitting = false
	return flames
