# WashAction: wash a bin of dirty dishes at the sink. With more than one dish,
# hold the button on the bin and let go over the sink: it tips them all into the
# soapy water at once. Each comes up in turn: scrub its grime off with the sponge
# (hold and rub), and once it sparkles it hops onto the rack by itself and the
# next comes up. A single dish is lifted out of the bin and dropped in by itself. The session's context gives "dishes" (the dirty models, the
# bin's order), "rack_spot" (a Callable: where the next clean dish goes, in
# world space) and "on_racked" (a Callable, called as each one goes on).
class_name WashAction
extends CookAction

enum Phase { PICK, SOAK, SCRUB, RACK }  # SOAK: the next dish is about to come up. RACK: a clean one is on its way.

@export var bin_surface := "Bin"           # Its DishBinModel child, "Bin", holds the dirty dishes.
@export var sink_surface := "Sink"
@export var rack_surface := "Rack"
@export var dish_size := 0.26
@export var carry_height := 0.16
@export var water_level := 0.065           # The soapy water's top, above the counter top: the sink's half full.
@export var water_size := Vector2(0.68, 0.46)
@export var water_offset := Vector2(0.0, -0.062)  # From the sink surface's middle.
@export var scrub_view := Vector2(0.78, 58.0)  # How close the view comes while scrubbing, and how steep.
@export var soak_tilt := 0.6               # Radians: dishes in the water lean on their sides, one against the next.
@export var soak_spacing := 0.1           # Between dishes in the water (closer when there are lots, to fit).
@export var spots_per_dish := 2
@export var big_load := 4                 # From this many dishes in a bin, each has one spot fewer (a big pile stays quick).
@export var spot_radius := 0.035
@export var scrub_needed := 0.32           # Meters of rubbing over a spot to clean it.
@export var grime_color := Color(0.45, 0.33, 0.2)

var _phase := Phase.PICK
var _bin: DishBinModel
var _dish: Node3D = null                   # The one being washed.
var _carrying := false
var _spots: Array[Dictionary] = []         # { node, dirt, offset } on the dish being washed.
var _sponge := Node3D.new()
var _last := Vector3.ZERO
var _left := 0
var _load := 0                             # Dishes the bin came with.
var _busy := false                         # A dish is flying somewhere.
var _water: AudioStreamPlayer3D
var _soaking: Array[Node3D] = []           # Tipped into the sink, still dirty, top last.
var _carrying_bin := false
var _bin_home := Vector3.ZERO
var _water_look := ShaderMaterial.new()
var _rings: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
var _next_ring := 0
var _froth: Array[Node3D] = []
var _bubbles: CPUParticles3D
var _stirred := 0.0
var _scrubbed := 0.0                       # How far the sponge went this frame.
var _rubbed := 0.0                         # How far the sponge's gone since its last ring.
var _time := 0.0
var _near := false                         # The view's down at the sink.
var _suds: Node3D                          # The water and its foam.


func _begin() -> void:
	_bin = session.surface(bin_surface).get_node("Bin")
	_left = _bin.contents.get_child_count()
	_load = _left
	_bin_home = _bin.position
	_build_sponge()
	_build_suds()
	_water = session.loop_sound("pour", -40.0)
	_water.play()


func end() -> void:
	_sponge.queue_free()
	_suds.queue_free()
	_water.queue_free()


func uses_cursor() -> bool:
	return _phase != Phase.SCRUB


func update(delta: float, input: CookInput) -> void:
	var spot := input.cursor
	_move_water(delta, _scrubbed)
	_scrubbed = 0.0
	_sponge.visible = _phase == Phase.SCRUB
	match _phase:
		Phase.PICK:
			_update_pick(delta, input, spot)
		Phase.SOAK:
			if not _busy and not _soaking.is_empty():
				_dish = _soaking.pop_back()  # The top one comes up to be scrubbed.
				_into_sink()
		Phase.SCRUB:
			_update_scrub(delta, input, spot)
		Phase.RACK:
			if not _busy:
				_onto_rack()  # Up to the rack by itself.
	session.set_status("Dishes left: %d" % _left)
	if _left == 0 and not _busy:
		finish(1.0)


func _update_pick(delta: float, input: CookInput, spot: Vector3) -> void:
	if _busy:
		return
	if _carrying_bin:  # The whole bin, to tip into the sink.
		var goal := session.to_global(Vector3(spot.x, carry_height - 0.06, spot.z))
		_bin.global_position = _bin.global_position.lerp(goal, 1.0 - exp(-18.0 * delta))
		if not input.held:
			_carrying_bin = false
			if session.surface(sink_surface).contains(spot, 0.08):
				_tip_into_sink()
			else:
				_bin_back_home()
		return
	if _carrying:
		_follow(delta, spot)
		if not input.held:
			_carrying = false
			if session.surface(sink_surface).contains(spot, 0.04):
				_into_sink()
			else:
				_back_to_bin()
	elif input.just_pressed and session.surface(bin_surface).contains(spot, 0.04) and _bin.top() != null:
		if _bin.contents.get_child_count() > 1:
			_carrying_bin = true
			session.play_sound("clack", session.surface(bin_surface).position, -6.0, 1.2)
			return
		_dish = _bin.top()
		_dish.reparent(session)
		_carrying = true
		session.play_sound("clack", _dish.position, -6.0, 1.7)


func _update_scrub(delta: float, input: CookInput, spot: Vector3) -> void:
	var sink := session.surface(sink_surface).position
	var goal := Vector3(spot.x, sink.y + _scrub_height() + (0.03 if input.held else 0.07), spot.z)
	_sponge.position = _sponge.position.lerp(goal, 1.0 - exp(-22.0 * delta))
	var moved := Vector2(_sponge.position.x - _last.x, _sponge.position.z - _last.z).length() if input.held else 0.0
	_last = _sponge.position
	_sponge.rotation.y += moved * 5.0
	_scrubbed = moved
	_rubbed += moved
	# It squashes as it's pressed, and froths.
	_sponge.scale = _sponge.scale.lerp(Vector3(1.06, 0.72, 1.06) if input.held else Vector3.ONE, 1.0 - exp(-16.0 * delta))
	if _rubbed > 0.07:
		_rubbed = 0.0
		_ring(_sponge.position, 0.0035)
		_add_lather()
	_water.volume_db = lerpf(-30.0, -14.0, clampf(moved / maxf(delta, 0.001) / 0.5, 0.0, 1.0))
	if moved > 0.0 and randf() < 0.3:
		session.burst(_sponge.position + Vector3(0.0, 0.02, 0.0), Color(1.0, 1.0, 1.0, 0.8), 3, 0.15)  # Suds.
	var dirty := 0
	for entry in _spots:
		if entry["dirt"] <= 0.0:
			continue
		var at: Vector3 = _dish.position + entry["offset"]
		if moved > 0.0 and Vector2(_sponge.position.x - at.x, _sponge.position.z - at.z).length() <= spot_radius + 0.05:
			entry["dirt"] = maxf(entry["dirt"] - moved / scrub_needed, 0.0)
			entry["node"].scale = Vector3(1.0, 1.0, 1.0) * maxf(entry["dirt"], 0.01)
			if entry["dirt"] <= 0.0:
				session.burst(at + Vector3(0.0, 0.02, 0.0), Color(1.0, 1.0, 0.9), 8, 0.25)
				session.play_sound("ding", at, -14.0, 1.6)
		if entry["dirt"] > 0.0:
			dirty += 1
	if dirty == 0:
		session.pop_text("Sparkling!", _dish.position, 1)
		_phase = Phase.RACK
		_water.volume_db = -40.0


# A dab of lather left on the dish where the sponge went; it slides off and goes.
func _add_lather() -> void:
	if _dish == null:
		return
	var off := Vector2(_sponge.position.x - _dish.position.x, _sponge.position.z - _dish.position.z)
	if off.length() > dish_size * 0.44:
		return
	for i in 4:
		var bead := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = randf_range(0.004, 0.009)
		ball.height = ball.radius * 1.4
		ball.radial_segments = 12
		ball.rings = 6
		ball.material = session.soap_skin()
		bead.mesh = ball
		_dish.add_child(bead)
		bead.position = Vector3(off.x + randf_range(-0.02, 0.02), 0.026, off.y + randf_range(-0.02, 0.02))
		var slide := bead.create_tween()
		slide.tween_property(bead, "position", bead.position + Vector3(randf_range(-0.01, 0.01), -0.004, 0.02), randf_range(0.8, 1.6))
		slide.tween_property(bead, "scale", Vector3.ONE * 0.01, 0.15)
		slide.tween_callback(bead.queue_free)


func _follow(delta: float, spot: Vector3) -> void:
	var goal := Vector3(spot.x, carry_height, spot.z)
	_dish.position = _dish.position.lerp(goal, 1.0 - exp(-18.0 * delta))


# Into the water: the dirty dish turns into a clean one with grime spots to scrub.
func _into_sink() -> void:
	_busy = true
	var sink := session.surface(sink_surface).position
	var tween := _dish.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dish, "position", Vector3(sink.x, sink.y + _scrub_height(), sink.z), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_dish, "rotation", Vector3.ZERO, 0.18)  # Out of the water, held flat to scrub.
	await tween.finished
	_ring(_dish.position, 0.01)
	session.burst(_dish.position + Vector3(0.0, 0.03, 0.0), Color(0.75, 0.9, 1.0, 0.8), 14, 0.4)
	session.play_sound("plop", _dish.position, -4.0, 0.8)
	var model := _clean_model(_dish)
	var at := _dish.position
	_dish.queue_free()
	_dish = ModelFit.place(model, session, at, Vector3(dish_size, 0.0, dish_size))
	_dish.set_meta("model", model)
	_add_spots()
	_sponge.position = at + Vector3(0.0, 0.1, dish_size)
	_last = _sponge.position
	_look_in()
	_phase = Phase.SCRUB
	_busy = false


func _back_to_bin() -> void:
	_busy = true
	var dish := _dish
	var tween := dish.create_tween()
	tween.tween_property(dish, "position", _bin_spot(), 0.2).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	_bin.add(dish)
	_dish = null
	_busy = false
	session.pop_text("Into the sink!", session.surface(sink_surface).position, 0)


func _onto_rack() -> void:
	_busy = true
	var rack_spot: Callable = session.context.get("rack_spot", Callable())
	var goal := session.to_local(rack_spot.call()) if rack_spot.is_valid() else session.surface(rack_surface).position
	var tween := _dish.create_tween().set_parallel(true)
	tween.tween_property(_dish, "position", goal + Vector3(0.0, 0.05, 0.0), 0.22).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_dish, "rotation", Vector3(0.0, 0.0, session.context.get("rack_turn", PI * 0.5)), 0.22)  # Stood up in the rack.
	tween.tween_property(_dish, "scale", Vector3.ONE * 0.7, 0.22)
	await tween.finished
	session.play_sound("clack", _dish.position, -4.0, 2.0)
	_dish.queue_free()
	_dish = null
	var on_racked: Callable = session.context.get("on_racked", Callable())
	if on_racked.is_valid():
		on_racked.call()
	_left -= 1
	if _soaking.is_empty() and _left > 0:  # Back for the next one in the bin.
		_near = false
		session.frame(Vector3(0.0, 0.0, 0.0), 1.55, 70.0, 0.4)
	_phase = Phase.SOAK if not _soaking.is_empty() else Phase.PICK
	_busy = false


# The view comes down to the sink.
func _look_in() -> void:
	if _near:
		return
	_near = true
	session.frame(session.surface(sink_surface).position + Vector3(0.0, 0.05, 0.0), scrub_view.x, scrub_view.y, 0.4)


# Over the sink the bin tips, every dish slides into the water, and the empty
# bin goes back where it was.
func _tip_into_sink() -> void:
	_busy = true
	var sink := session.surface(sink_surface).position
	var over := session.to_global(sink + Vector3(-0.12, 0.12, 0.0))
	var tip := _bin.create_tween().set_parallel(true)
	tip.tween_property(_bin, "global_position", over, 0.15).set_trans(Tween.TRANS_SINE)
	tip.tween_property(_bin, "rotation:z", -1.1, 0.2).set_trans(Tween.TRANS_SINE).set_delay(0.05)  # Its far side up, tipping toward the sink.
	await tip.finished
	var dishes := _bin.contents.get_children()
	for i in dishes.size():
		var dish := dishes[dishes.size() - 1 - i] as Node3D  # The top one first, so it ends up at the bottom.
		dish.reparent(session)
		var goal := _soak_spot(i, dishes.size())
		var slide := dish.create_tween().set_parallel(true)
		slide.tween_property(dish, "position", goal, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(i * 0.06)
		slide.tween_property(dish, "rotation", Vector3(0.0, 0.0, soak_tilt), 0.22).set_delay(i * 0.06)
		_soaking.push_front(dish)
	await session.get_tree().create_timer(0.22 + dishes.size() * 0.06).timeout
	for i in 4:
		_ring(sink + Vector3(randf_range(-0.1, 0.1), 0.0, randf_range(-0.06, 0.06)), 0.012)
	session.burst(sink + Vector3(0.0, 0.03, 0.0), Color(0.75, 0.9, 1.0, 0.8), 24, 0.5)
	session.play_sound("plop", sink, -2.0, 0.7)
	session.pop_text("Splash!", sink, 1)
	_bin_back_home()
	_look_in()
	_phase = Phase.SOAK
	_busy = false


func _bin_back_home() -> void:
	var back := _bin.create_tween().set_parallel(true)
	back.tween_property(_bin, "position", _bin_home, 0.25).set_trans(Tween.TRANS_SINE)
	back.tween_property(_bin, "rotation:z", 0.0, 0.25).set_trans(Tween.TRANS_SINE)


# Where the i-th of n tipped dishes settles: in a row across the sink, each on
# its side leaning on the next like dominoes, its top edge peeking out of the
# water. The first (rightmost, lying on the rest) is grabbed first.
func _soak_spot(i: int, n: int) -> Vector3:
	var sink := session.surface(sink_surface).position
	var gap := minf(soak_spacing, (water_size.x - dish_size * 0.9) / maxf(n - 1, 1))
	return sink + Vector3(((n - 1) * 0.5 - i) * gap, water_level - 0.03, water_offset.y)


# Out of the water, flat, just over it: where a dish is scrubbed.
func _scrub_height() -> float:
	# Clear of the rims peeking out of the water: their top edges come up to
	# water_level - 0.03 + half a dish times sin(soak_tilt).
	return water_level - 0.03 + dish_size * 0.5 * sin(soak_tilt) + 0.025


# Something moves in the water: a ring runs out from it.
func _ring(at: Vector3, hard: float) -> void:
	var here := _suds.position
	_rings[_next_ring] = Vector4(at.x - here.x, at.z - here.z, 0.0, hard)
	_next_ring = (_next_ring + 1) % _rings.size()


# The water and the froth on it, rocking on the rings.
func _move_water(delta: float, moved: float) -> void:
	_time += delta
	_stirred = lerpf(_stirred, clampf(moved / maxf(delta, 0.001) / 0.5, 0.0, 1.0), 1.0 - exp(-3.0 * delta))
	_water_look.set_shader_parameter("stirred", _stirred)
	for i in _rings.size():
		_rings[i].z += delta
		_water_look.set_shader_parameter(["ring_a", "ring_b", "ring_c", "ring_d"][i], _rings[i])
	for i in _froth.size():
		var bubble := _froth[i]
		var home: Vector3 = bubble.get_meta("home")
		var push := Vector3.ZERO
		for ring in _rings:
			if ring.w > 0.0 and ring.z < 1.2:
				var off := Vector2(home.x - ring.x, home.z - ring.y)
				var wave := exp(-pow((off.length() - ring.z * 0.28) * 14.0, 2.0)) * ring.w * exp(-ring.z * 2.0)
				push += Vector3(off.normalized().x * wave * 2.2, wave, off.normalized().y * wave * 2.2)
		bubble.position = home + push + Vector3(sin(_time * 0.7 + i) * 0.002, sin(_time * 1.6 + i * 2.1) * 0.0012, cos(_time * 0.6 + i * 1.3) * 0.002)
	_bubbles.speed_scale = 0.6 + _stirred * 1.2


# Soap bubbles drifting up off the water: clear, with a bright rim.
func _soap_bubbles() -> void:
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 12
	_bubbles.lifetime = 3.2
	_bubbles.randomness = 0.8
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(water_size.x * 0.4, 0.0, water_size.y * 0.4)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 25.0
	_bubbles.initial_velocity_min = 0.02
	_bubbles.initial_velocity_max = 0.06
	_bubbles.gravity = Vector3(0.0, 0.012, 0.0)
	_bubbles.tangential_accel_min = -0.03
	_bubbles.tangential_accel_max = 0.03
	_bubbles.scale_amount_min = 0.3
	_bubbles.scale_amount_max = 1.0
	var pop := Curve.new()
	pop.add_point(Vector2(0.0, 0.1))
	pop.add_point(Vector2(0.2, 1.0))
	pop.add_point(Vector2(0.95, 1.0))
	pop.add_point(Vector2(1.0, 0.0))
	_bubbles.scale_amount_curve = pop
	var ball := SphereMesh.new()
	ball.radius = 0.011
	ball.height = 0.022
	ball.radial_segments = 20
	ball.rings = 10
	ball.material = session.soap_skin()
	_bubbles.mesh = ball
	_bubbles.position.y = 0.01
	_suds.add_child(_bubbles)


# Half a sink of soapy water, with foam round the edges.
func _build_suds() -> void:
	_suds = Node3D.new()
	var sink := session.surface(sink_surface).position
	_suds.position = sink + Vector3(water_offset.x, water_level, water_offset.y)
	var water := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = water_size
	sheet.subdivide_width = 72
	sheet.subdivide_depth = 54
	water.mesh = sheet
	_water_look.shader = preload("res://assets/shaders/sink_water.gdshader")
	_water_look.set_shader_parameter("size", water_size)
	water.material_override = _water_look
	water.custom_aabb = AABB(Vector3(-water_size.x, -0.03, -water_size.y), Vector3(water_size.x * 2.0, 0.06, water_size.y * 2.0))
	_suds.add_child(water)
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color(0.94, 0.97, 1.0)
	foam.roughness = 0.35
	foam.emission_enabled = true
	foam.emission = Color(0.8, 0.88, 1.0)
	foam.emission_energy_multiplier = 0.15
	foam.set_meta(ToonStyle.SKIP, true)
	_soap_bubbles()
	for i in 90:
		var bubble := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = randf_range(0.004, 0.015)
		ball.height = ball.radius * 1.5
		ball.radial_segments = 14
		ball.rings = 7
		ball.material = foam
		bubble.mesh = ball
		# Mostly round the edges, where suds gather.
		var edge := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if absf(edge.x) < 0.75 and absf(edge.y) < 0.75:
			edge = edge.normalized() * 0.85 if edge != Vector2.ZERO else Vector2(0.85, 0.0)
		bubble.position = Vector3(edge.x * water_size.x * 0.46, 0.001, edge.y * water_size.y * 0.42)
		bubble.set_meta("home", bubble.position)
		_suds.add_child(bubble)
		_froth.append(bubble)
	session.add_child(_suds)


func _bin_spot() -> Vector3:
	return session.surface(bin_surface).transform * _bin.next_spot()


# The clean version of a dirty dish's model (bowl_dirty -> bowl).
func _clean_model(dish: Node3D) -> String:
	var fit := dish as ModelFit
	var path := fit.model.resource_path if fit != null and fit.model != null else ""
	return path.replace("_dirty", "")


# Grime spots on each dish: one fewer in a big load, so 8 dishes isn't a chore.
func _spot_count() -> int:
	return maxi(1, spots_per_dish - (1 if _load >= big_load else 0))


func _add_spots() -> void:
	_spots.clear()
	var material := StandardMaterial3D.new()
	material.albedo_color = grime_color
	material.roughness = 0.5
	material.set_meta(ToonStyle.FOOD, "cooked")
	var count := _spot_count()
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count + randf_range(-0.4, 0.4)) * dish_size * randf_range(0.15, 0.3)
		var blob := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = spot_radius
		mesh.height = spot_radius * 0.5
		mesh.material = material
		blob.mesh = mesh
		var place := Vector3(offset.x, 0.025, offset.y)
		blob.position = place
		_dish.add_child(blob)
		_spots.append({ "node": blob, "dirt": 1.0, "offset": place })


# A soft yellow sponge with a green scrubby top.
func _build_sponge() -> void:
	var body := KitchenProps.soft_block(Vector3(0.1, 0.032, 0.066), KitchenProps.BRASS)
	body.position.y = 0.016
	_sponge.add_child(body)
	var scrub := KitchenProps.soft_block(Vector3(0.096, 0.014, 0.062), Color("#7FAE4A"))
	scrub.position.y = 0.036
	_sponge.add_child(scrub)
	_sponge.visible = false
	session.add_child(_sponge)


# --- For a reel -----------------------------------------------------------------

var _scripted_angle := 0.0


# The bin tipped into the sink (or a lone dish dropped in), then each dish:
# small circles over each grime spot.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _busy:
		return false
	match _phase:
		Phase.PICK:
			if _carrying or _carrying_bin:
				return not input.move_to(session.surface(sink_surface).position, delta, 0.9)
			return input.move_to(session.surface(bin_surface).position, delta, 1.0) and not input.held and _bin.top() != null
		Phase.SCRUB:
			for entry in _spots:
				if entry["dirt"] > 0.0:
					_scripted_angle += delta * 12.0
					var round_it := Vector3(cos(_scripted_angle), 0.0, sin(_scripted_angle)) * spot_radius
					input.move_to(_dish.position + entry["offset"] + round_it, delta, 0.8)
					return true
			return false
	return false
