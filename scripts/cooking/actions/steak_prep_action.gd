# SteakPrepAction: get a steak ready on a board before it's seared.
#   - pat_dry: it's wet, beaded with water all over its top. Hold the button and
#     rub the paper towel over it: the drops under the towel soak up. Done when
#     they're all gone (a dry steak sears; a wet one steams).
#   - season: shake salt, then pepper, over it: press to shake, and a pinch
#     lands round the shaker. Each wants its share on every part of the top
#     (a 3 x 3 grid); a pinch that misses the steak is wasted. Done when every
#     part has its share of both (or after plenty of shakes).
# The first one puts the board and the steak out (the session's context
# "steak_prep"); the season step takes them away after, as SearAction brings
# out the pan with its own cube of steak.
class_name SteakPrepAction
extends CookAction

@export_enum("pat_dry", "season") var job := "pat_dry"
@export var at := Vector3(0.0, 0.0, 0.04)          # The board's middle, on the counter.
@export var steak_size := 0.09
@export var towel_radius := 0.03
@export var drops := 22
@export var per_zone := 2                            # season: pinches of each for every part of the top.

const ZONES := 3
const RAW := Color(0.74, 0.32, 0.34)
const MAX_SHAKES := 40

var _prep := {}                      # board, steak, top (y of its top face).
var _tool: Node3D
var _drops: Array[MeshInstance3D] = []
var _zones := {}                     # season: Vector2i -> [salt, pepper] pinches there.
var _pepper := false                 # season: on to the pepper.
var _shakes := 0
var _missed := 0


func _init() -> void:
	view_distance = 0.42
	view_pitch = 62.0


func view_point() -> Vector3:
	return at + Vector3(0.0, 0.03, 0.0)


func uses_cursor() -> bool:
	return false


func marks_spot() -> bool:
	return true


func cursor_height() -> float:
	return _prep.get("top", at.y + 0.05)


func _begin() -> void:
	_prep = session.context.get("steak_prep", {})
	if _prep.is_empty() or not is_instance_valid(_prep.get("steak")):
		_prep = _set_out()
		session.context["steak_prep"] = _prep
	if job == "pat_dry":
		_tool = _make_towel()
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.85, 0.92, 1.0, 0.55)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.roughness = 0.05
		water.metallic_specular = 1.0
		for i in drops:
			var drop := MeshInstance3D.new()
			var bead := SphereMesh.new()
			bead.radius = randf_range(0.0028, 0.0045)
			bead.height = bead.radius * 1.2
			bead.material = water
			drop.mesh = bead
			var spot := Vector2(randf_range(-0.45, 0.45), randf_range(-0.45, 0.45)) * steak_size
			drop.position = Vector3(spot.x, steak_size * 0.5 + 0.001, spot.y)
			(_prep["steak"] as Node3D).add_child(drop)
			_drops.append(drop)
	else:
		for x in ZONES:
			for z in ZONES:
				_zones[Vector2i(x, z)] = [0, 0]
		_tool = _make_shaker(false)
	session.add_child(_tool)
	_tool.position = view_point() + Vector3(0.08, 0.08, 0.0)


func end() -> void:
	if is_instance_valid(_tool):
		_tool.queue_free()
	if job == "season":  # Off the board and into the pan (SearAction's own cube).
		for key in ["board", "steak"]:
			var node: Node3D = _prep.get(key)
			if is_instance_valid(node):
				node.queue_free()
		session.context.erase("steak_prep")


func update(delta: float, input: CookInput) -> void:
	if done:
		return
	var steak: Node3D = _prep["steak"]
	var spot := Vector3(input.cursor.x, _prep["top"], input.cursor.z)
	if job == "pat_dry":
		var lift := 0.004 if input.held else 0.03
		_tool.position = _tool.position.lerp(spot + Vector3(0.0, lift, 0.0), 1.0 - exp(-18.0 * delta))
		if input.held:
			_tool.rotation.y += delta * 6.0  # Rubbing round.
			for drop in _drops:
				if drop.visible and Vector2(steak.position.x + drop.position.x - spot.x, steak.position.z + drop.position.z - spot.z).length() <= towel_radius:
					drop.visible = false
		var left := _drops.filter(func(d): return d.visible).size()
		session.set_status("Pat it dry: %d drops left" % left)
		if left == 0:
			session.pop_text("Nice and dry!", steak.position + Vector3(0.0, 0.06, 0.0), 1)
			finish(1.0)
		return
	_tool.position = _tool.position.lerp(spot + Vector3(0.0, 0.09, 0.0), 1.0 - exp(-18.0 * delta))
	session.set_status("%s: shake it all over" % ("Pepper" if _pepper else "Salt"))
	if input.just_pressed:
		_shake(spot)


func _shake(spot: Vector3) -> void:
	_shakes += 1
	var steak: Node3D = _prep["steak"]
	var shake := _tool.create_tween()
	shake.tween_property(_tool, "rotation:z", deg_to_rad(-35.0), 0.06)
	shake.tween_property(_tool, "rotation:z", 0.0, 0.1)
	session.play_sound("tick", spot, -10.0, 1.8 if _pepper else 2.2)
	var color := Color(0.12, 0.1, 0.09) if _pepper else Color(0.98, 0.98, 0.96)
	var on_steak := 0
	for i in 5:  # A pinch: specks round the shaker.
		var land := Vector2(spot.x, spot.z) + Vector2.from_angle(randf() * TAU) * randf() * 0.016
		var local := land - Vector2(steak.position.x, steak.position.z)
		var fleck := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.0022
		var paint := StandardMaterial3D.new()
		paint.albedo_color = color
		mesh.material = paint
		fleck.mesh = mesh
		if absf(local.x) <= steak_size * 0.5 and absf(local.y) <= steak_size * 0.5:
			on_steak += 1
			fleck.position = Vector3(local.x, steak_size * 0.5 + 0.0012, local.y)
			fleck.rotation.y = randf() * TAU
			steak.add_child(fleck)
			var zone := Vector2i(clampi(floori((local.x / steak_size + 0.5) * ZONES), 0, ZONES - 1), clampi(floori((local.y / steak_size + 0.5) * ZONES), 0, ZONES - 1))
			_zones[zone][1 if _pepper else 0] += 1
		else:
			fleck.position = Vector3(land.x, (_prep["board"] as Node3D).position.y + 0.032, land.y)
			session.add_child(fleck)
	if on_steak == 0:
		_missed += 1
		session.pop_text("On the steak!", spot, -1)
	var which := 1 if _pepper else 0
	if _zones.values().all(func(z): return z[which] >= per_zone * 3):  # Every part has its share (5 specks a pinch).
		if not _pepper:
			_pepper = true
			_tool.queue_free()
			_tool = _make_shaker(true)
			session.add_child(_tool)
			_tool.position = spot + Vector3(0.0, 0.09, 0.0)
			session.pop_text("Now the pepper!", steak.position + Vector3(0.0, 0.06, 0.0), 1)
		else:
			_finish_season()
	elif _shakes >= MAX_SHAKES:
		_finish_season()


func _finish_season() -> void:
	var covered := 0.0
	for zone in _zones.values():
		covered += (minf(zone[0] / (per_zone * 3.0), 1.0) + minf(zone[1] / (per_zone * 3.0), 1.0)) * 0.5
	var score := clampf(covered / _zones.size() - _missed * 0.05, 0.0, 1.0)
	session.pop_text("Well seasoned!" if score >= 0.9 else "Patchy", (_prep["steak"] as Node3D).position + Vector3(0.0, 0.06, 0.0), CookSession.mood_of(score))
	finish(score)


# For a reel: rub across every drop; shake over each part in turn.
func scripted_hold(delta: float, input: CookInput) -> bool:
	var steak: Node3D = _prep.get("steak")
	if steak == null:
		return false
	if job == "pat_dry":
		for drop in _drops:
			if drop.visible:
				input.move_to(steak.position + drop.position, delta, 1.2)
				return true
		return false
	var which := 1 if _pepper else 0
	for key: Vector2i in _zones:
		if _zones[key][which] < per_zone * 3:
			var goal := steak.position + Vector3(((key.x + 0.5) / ZONES - 0.5) * steak_size, 0.0, ((key.y + 0.5) / ZONES - 0.5) * steak_size)
			return input.move_to(goal, delta, 1.2) and not input.held
	return false


# The board, and a thick raw steak on it.
func _set_out() -> Dictionary:
	var board := Node3D.new()
	board.position = at
	ModelFit.place("res://design/restaurant/cutting_board.glb", board, Vector3.ZERO, Vector3(0.3, 0.03, 0.2))
	session.add_child(board)
	var steak := MeshInstance3D.new()
	steak.mesh = PlaceAction.rounded_block(Vector3.ONE * steak_size, 0.012)
	var meat := StandardMaterial3D.new()
	meat.albedo_color = RAW
	meat.roughness = 0.6
	meat.set_meta(ToonStyle.FOOD, "meat")
	steak.material_override = meat
	steak.position = at + Vector3(0.0, 0.03 + steak_size * 0.5, 0.0)
	session.add_child(steak)
	return { "board": board, "steak": steak, "top": steak.position.y + steak_size * 0.5 }


func _make_towel() -> Node3D:
	var towel := MeshInstance3D.new()
	var pad := BoxMesh.new()  # A folded paper towel.
	pad.size = Vector3(towel_radius * 2.0, 0.008, towel_radius * 2.0)
	towel.mesh = pad
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.98, 0.98, 0.95)
	paper.roughness = 0.95
	paper.set_meta(ToonStyle.FOOD, "baked")
	pad.material = paper
	return towel


func _make_shaker(pepper: bool) -> Node3D:
	var shaker := Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.013
	mesh.bottom_radius = 0.015
	mesh.height = 0.05
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.22, 0.2) if pepper else Color(0.97, 0.97, 0.96)
	mesh.material = glass
	body.mesh = mesh
	shaker.add_child(body)
	var cap := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 0.009
	top.bottom_radius = 0.0135
	top.height = 0.014
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.83)
	steel.metallic = 0.6
	top.material = steel
	cap.mesh = top
	cap.position.y = -0.032  # Upside down over the steak.
	cap.rotation.x = PI
	shaker.add_child(cap)
	return shaker
