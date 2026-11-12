# WashAction: wash a bin of dirty dishes at the sink. With more than one dish,
# hold the button on the bin and let go over the sink: it tips them all into the
# soapy water at once. Then for each: press in the sink to grab one, scrub its
# grime off with the sponge (hold and rub), and hold on it again and carry it to
# the rack. A single dish is lifted out of the bin and dropped in by itself. The session's context gives "dishes" (the dirty models, the
# bin's order), "rack_spot" (a Callable: where the next clean dish goes, in
# world space) and "on_racked" (a Callable, called as each one goes on).
class_name WashAction
extends CookAction

enum Phase { PICK, SOAK, SCRUB, RACK }  # SOAK: dishes in the water, waiting to be grabbed.

@export var bin_surface := "Bin"           # Its DishBinModel child, "Bin", holds the dirty dishes.
@export var sink_surface := "Sink"
@export var rack_surface := "Rack"
@export var dish_size := 0.26
@export var carry_height := 0.16
@export var water_level := -0.035          # The soapy water's top, below the counter top: the sink's half full.
@export var water_size := Vector2(0.62, 0.3)
@export var water_offset := Vector2(0.0, -0.07)  # From the sink surface's middle.
@export var soak_tilt := 0.6               # Radians: dishes in the water lean on their sides, one against the next.
@export var soak_spacing := 0.1           # Between dishes in the water (closer when there are lots, to fit).
@export var spots_per_dish := 3
@export var spot_radius := 0.035
@export var scrub_needed := 0.45           # Meters of rubbing over a spot to clean it.
@export var grime_color := Color(0.45, 0.33, 0.2)

var _phase := Phase.PICK
var _bin: DishBinModel
var _dish: Node3D = null                   # The one being washed.
var _carrying := false
var _spots: Array[Dictionary] = []         # { node, dirt, offset } on the dish being washed.
var _sponge := Node3D.new()
var _last := Vector3.ZERO
var _left := 0
var _busy := false                         # A dish is flying somewhere.
var _water: AudioStreamPlayer3D
var _soaking: Array[Node3D] = []           # Tipped into the sink, still dirty, top last.
var _carrying_bin := false
var _bin_home := Vector3.ZERO
var _suds: Node3D                          # The water and its foam.


func _begin() -> void:
	_bin = session.surface(bin_surface).get_node("Bin")
	_left = _bin.contents.get_child_count()
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
	_sponge.visible = _phase == Phase.SCRUB
	match _phase:
		Phase.PICK:
			_update_pick(delta, input, spot)
		Phase.SOAK:
			if not _busy and input.just_pressed and session.surface(sink_surface).contains(spot, 0.06) and not _soaking.is_empty():
				_dish = _soaking.pop_back()  # The top one comes up to be scrubbed.
				_into_sink()
		Phase.SCRUB:
			_update_scrub(delta, input, spot)
		Phase.RACK:
			_update_rack(delta, input, spot)
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


func _update_rack(delta: float, input: CookInput, spot: Vector3) -> void:
	if _busy:
		return
	if _carrying:
		_follow(delta, spot)
		if not input.held:
			_carrying = false
			if session.surface(rack_surface).contains(spot, 0.06):
				_onto_rack()
			else:
				_back_to_sink()
	elif input.just_pressed and Vector2(spot.x - _dish.position.x, spot.z - _dish.position.z).length() <= dish_size * 0.5 + 0.03:
		_carrying = true
		session.play_sound("clack", _dish.position, -8.0, 1.8)


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


func _back_to_sink() -> void:
	var sink := session.surface(sink_surface).position
	_busy = true
	var tween := _dish.create_tween()
	tween.tween_property(_dish, "position", Vector3(sink.x, sink.y + _scrub_height(), sink.z), 0.2).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	_busy = false
	session.pop_text("Onto the rack!", session.surface(rack_surface).position, 0)


func _onto_rack() -> void:
	_busy = true
	var rack_spot: Callable = session.context.get("rack_spot", Callable())
	var goal := session.to_local(rack_spot.call()) if rack_spot.is_valid() else session.surface(rack_surface).position
	var tween := _dish.create_tween().set_parallel(true)
	tween.tween_property(_dish, "position", goal + Vector3(0.0, 0.05, 0.0), 0.22).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_dish, "rotation:x", PI * 0.5, 0.22)  # Stood up in the rack.
	tween.tween_property(_dish, "scale", Vector3.ONE * 0.7, 0.22)
	await tween.finished
	session.play_sound("clack", _dish.position, -4.0, 2.0)
	_dish.queue_free()
	_dish = null
	var on_racked: Callable = session.context.get("on_racked", Callable())
	if on_racked.is_valid():
		on_racked.call()
	_left -= 1
	_phase = Phase.SOAK if not _soaking.is_empty() else Phase.PICK
	_busy = false


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
	session.burst(sink + Vector3(0.0, 0.03, 0.0), Color(0.75, 0.9, 1.0, 0.8), 24, 0.5)
	session.play_sound("plop", sink, -2.0, 0.7)
	session.pop_text("Splash!", sink, 1)
	_bin_back_home()
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
	return water_level + 0.02


# Half a sink of soapy water, with foam round the edges.
func _build_suds() -> void:
	_suds = Node3D.new()
	var sink := session.surface(sink_surface).position
	_suds.position = sink + Vector3(water_offset.x, water_level, water_offset.y)
	var water := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(water_size.x, 0.004, water_size.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.86, 0.96, 0.92)  # Cloudy with soap: you can't see what's under.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Stays soapy blue under the warm kitchen light.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	sheet.material = material
	water.mesh = sheet
	_suds.add_child(water)
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color(0.97, 0.98, 1.0)
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 18:
		var bubble := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = randf_range(0.012, 0.028)
		ball.height = ball.radius * 0.9
		ball.material = foam
		bubble.mesh = ball
		# Mostly round the edges, where suds gather.
		var edge := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if absf(edge.x) < 0.75 and absf(edge.y) < 0.75:
			edge = edge.normalized() * 0.85 if edge != Vector2.ZERO else Vector2(0.85, 0.0)
		bubble.position = Vector3(edge.x * water_size.x * 0.46, 0.003, edge.y * water_size.y * 0.42)
		_suds.add_child(bubble)
	session.add_child(_suds)


func _bin_spot() -> Vector3:
	return session.surface(bin_surface).transform * _bin.next_spot()


# The clean version of a dirty dish's model (bowl_dirty -> bowl).
func _clean_model(dish: Node3D) -> String:
	var fit := dish as ModelFit
	var path := fit.model.resource_path if fit != null and fit.model != null else ""
	return path.replace("_dirty", "")


func _add_spots() -> void:
	_spots.clear()
	var material := StandardMaterial3D.new()
	material.albedo_color = grime_color
	material.roughness = 0.9
	for i in spots_per_dish:
		var offset := Vector2.from_angle(TAU * i / spots_per_dish + randf_range(-0.4, 0.4)) * dish_size * randf_range(0.15, 0.3)
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


# A yellow sponge with a green scrubby top.
func _build_sponge() -> void:
	for part in [[Vector3(0.1, 0.03, 0.065), Color(1.0, 0.85, 0.3), 0.015], [Vector3(0.1, 0.012, 0.065), Color(0.3, 0.65, 0.35), 0.036]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = part[1]
		material.roughness = 0.95
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = material
		var pad := MeshInstance3D.new()
		pad.mesh = box
		pad.position.y = part[2]
		_sponge.add_child(pad)
	_sponge.visible = false
	session.add_child(_sponge)


# --- For a reel -----------------------------------------------------------------

var _scripted_angle := 0.0
var _scripted_soak := 0.0  # A reel lets the dishes sit in the water a moment before grabbing one.


# The bin tipped into the sink (or a lone dish dropped in), then each dish:
# grabbed from the water, small circles over each grime spot, onto the rack.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _busy:
		return false
	match _phase:
		Phase.PICK:
			if _carrying or _carrying_bin:
				return not input.move_to(session.surface(sink_surface).position, delta, 0.9)
			return input.move_to(session.surface(bin_surface).position, delta, 1.0) and not input.held and _bin.top() != null
		Phase.SOAK:
			_scripted_soak += delta
			if _scripted_soak < 0.8:
				return false
			if input.move_to(session.surface(sink_surface).position, delta, 1.0) and not input.held:
				_scripted_soak = 0.0
				return true
			return false
		Phase.SCRUB:
			for entry in _spots:
				if entry["dirt"] > 0.0:
					_scripted_angle += delta * 12.0
					var round_it := Vector3(cos(_scripted_angle), 0.0, sin(_scripted_angle)) * spot_radius
					input.move_to(_dish.position + entry["offset"] + round_it, delta, 0.8)
					return true
			return false
		Phase.RACK:
			if _carrying:
				return not input.move_to(session.surface(rack_surface).position, delta, 0.9)
			return input.move_to(_dish.position, delta, 1.0) and not input.held
	return false
