# ChopAction: chop a carrot into even pieces, in rhythm. It lies on the
# board (the peeled one from PeelAction, the session's context "carrot", or a
# fresh one) with faint marks where the cuts go. The knife waits over the next
# mark: press and it comes down there, then moves on to the next by itself, so
# the pieces always come out the right size. Each cut scores how close the
# press falls to the beat, which ticks (and pulses the next mark), or how even it
# is with the cook's own pace, whichever's better: they can chop as fast as they
# like. vegetable names another (Veg): a skinned onion, a peeled potato, celery.
# With slides it comes onto the board for its turn (from where it was set aside,
# or from the right), and its pieces move over to `rest` after.
class_name ChopAction
extends CookAction

@export var on_surface := "Board"
@export_enum("carrot", "onion", "potato", "celery") var vegetable := "carrot"
@export var cuts := 0                      # Cuts in all (a Sharp Knife takes fewer); 0 = the ingredients' own count ("chops" in data/dish_kitchen.json).
@export_group("Carrot")
@export var piece_length := 0.34           # A fresh one, when nothing was peeled first.
@export var piece_radius := 0.034
@export var slides := false
@export var rest := Vector2.ZERO           # Where on the board (from its middle) its pieces go after (zero: they stay put).
@export var offset_x := 0.0                # How far right of the board's middle it lies...
@export var offset_z := 0.0                # ...and how far in front of it.
@export var taper := 0.45                  # How much thinner the right end is (0 = straight, like a cucumber).
@export var piece_color := Color(0.95, 0.55, 0.15)  # When there are no ingredients to take the color from.
@export_group("Feel")
@export var beat_seconds := 0.45           # The rhythm to chop to.
@export var beat_tolerance := 0.18         # Seconds off the beat that scores nothing.
@export var perfect_seconds := 0.06        # This close to the beat (either side) is a perfect chop; the score falls off from here to beat_tolerance.
@export var knife_height := 0.08           # How high the knife hovers between chops.
@export var knife_tilt := 25.0             # Degrees the knife leans, so you see the blade from above.
@export var pace_slack := 0.25             # A gap this share off the cook's own pace is still perfect...
@export var pace_worst := 0.8              # ...and this far off it scores nothing.
@export var slowest_pace := 1.0            # A longer wait between chops than this isn't a pace.
@export var chop_seconds := 0.07           # The knife's way down (and twice that back up).
@export var slice_gap := 0.007             # How far apart the pieces sit once cut (enough to see the cut faces).

var _piece := {}                           # { node, left, right, z, radius, taper, color, marks (x, left to right), cuts, mark_nodes }
var _board_y := 0.0
var _knife: Node3D
var _arriving := false                     # Still sliding in.
var _chopping := false
var _falling := []                         # The chop on its way down: [x, score].
var _swing: Tween
var _last_press := -1.0                    # When they last pressed (_time)...
var _pace := 0.0                           # ...and the seconds between presses they've settled into (0: none yet).
var _time := 0.0
var _last_beat := -1
var _rhythm: Array[float] = []
var _tick_at := 0.0                        # When the last tick was played (_time).

# How long after a tick is played the player hears it and presses: the sound
# card's delay (much more with Bluetooth headphones) plus how they hear the
# beat. Learned from their chops, so pressing right on the sound is perfect
# whatever they're listening on. Kept for the whole run.
static var _heard_after := -1.0
const SLIDE_SECONDS := 0.35
const FROM_RIGHT := 0.6
const HEARD_AFTER_START := 0.04            # Before anything's learned, on top of the reported output latency.
const HEARD_AFTER_MAX := 0.3
const HEARD_AFTER_LEARN := 0.5             # How much each close chop moves it.


# Lay `node` along the board from x `left` to `right` (radius `left_radius` to
# `right_radius`), resting on it: its own x runs down the middle of the food,
# 0 at the middle, tipped so the thin end rests on the board too.
static func lay_along(node: Node3D, left: float, right: float, left_radius: float, right_radius: float, z: float, board_y: float) -> void:
	node.position = Vector3((left + right) * 0.5, board_y + (left_radius + right_radius) * 0.5, z)
	node.rotation.z = -atan2(left_radius - right_radius, right - left)


# A carrot's green top on `parent` at its thick end (local x `at_x`, pointing
# -x): a little crown and a fan of stems. Leaf green from the style guide.
static func add_greens(parent: Node3D, at_x: float, radius: float) -> void:
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color("#8DBE3E")
	leaf.roughness = 0.8
	leaf.set_meta(ToonStyle.FOOD, "veg")
	var stem := StandardMaterial3D.new()
	stem.albedo_color = Color("#6E9A33")
	stem.roughness = 0.8
	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = radius * 0.45
	crown_mesh.bottom_radius = radius * 0.7
	crown_mesh.height = 0.012
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 1
	crown_mesh.material = stem
	crown.mesh = crown_mesh
	crown.rotation.z = PI * 0.5  # Its top toward -x.
	crown.position = Vector3(at_x - 0.004, 0.0, 0.0)
	parent.add_child(crown)
	for i in 7:
		var fan := (i - 3) * 0.38  # Spread round the end.
		var arm := Node3D.new()
		arm.position = Vector3(at_x - 0.008, 0.0, 0.0)
		arm.rotation = Vector3(fan, 0.0, PI * 0.5 - 0.3 - absf(i - 3) * 0.07)
		parent.add_child(arm)
		var blade := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.006 if i % 2 == 0 else 0.0045
		mesh.height = 0.095 - absf(i - 3) * 0.01
		mesh.radial_segments = 6
		mesh.rings = 2
		mesh.material = leaf if i % 2 == 0 else stem
		blade.mesh = mesh
		blade.position = Vector3(0.0, mesh.height * 0.5, 0.0)
		blade.scale = Vector3(1.0, 1.0, 0.55)  # Flat-ish, like a leaf stalk.
		arm.add_child(blade)


func _init() -> void:
	view_distance = 0.5  # Close in on the carrot.
	view_pitch = 58.0


func view_point() -> Vector3:
	return Vector3((_piece["left"] + _piece["right"]) * 0.5, _board_y, _piece["z"])


func _begin() -> void:
	var total := cuts
	if total <= 0:
		total = session.ingredients.chops_needed() if session.ingredients != null else 8
	elif session.ingredients != null:
		total = maxi(1, total + int(GameState.upgrade_bonus("chops")))
	_board_y = session.surface(on_surface).position.y
	var carrot: Dictionary = session.context.get(vegetable, {})
	if carrot.is_empty():
		var board := session.surface(on_surface).position
		var middle := board.x + offset_x
		carrot = { "left": middle - piece_length * 0.5, "right": middle + piece_length * 0.5, "z": board.z + offset_z,
			"radius": piece_radius, "taper": taper,
			"color": session.ingredients.color() if session.ingredients != null else piece_color,
			"greens": session.ingredients == null or session.ingredients.leafy_top() }
		if vegetable != "carrot":
			carrot["color"] = Veg.FLESH[vegetable]
			carrot["greens"] = false
	var came_from := Vector3.ZERO
	var came_turned := 0.0
	if carrot.has("node"):
		came_from = carrot["node"].position
		came_turned = carrot["node"].rotation.y
		carrot["node"].queue_free()  # Its pieces take over from here.
	_piece = carrot.duplicate()
	_piece["node"] = Node3D.new()
	_piece["cuts"] = []
	_piece["marks"] = []
	var length: float = _piece["right"] - _piece["left"]
	for m in total:
		_piece["marks"].append(_piece["left"] + length * (m + 1) / (total + 1))
	session.add_child(_piece["node"])
	lay_along(_piece["node"], _piece["left"], _piece["right"], _piece["radius"], _piece["radius"] * (1.0 - _piece["taper"]), _piece["z"], _board_y)
	_build()
	_knife = _make_knife()
	_knife.position = _over_next()
	if slides:
		_arriving = true
		var node: Node3D = _piece["node"]
		var home := node.position
		node.position = came_from if came_from != Vector3.ZERO else home + Vector3(FROM_RIGHT, 0.0, 0.0)
		node.rotation.y = came_turned
		var slide := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
		slide.tween_property(node, "position", home, SLIDE_SECONDS)
		slide.tween_property(node, "rotation:y", 0.0, SLIDE_SECONDS)
		slide.chain().tween_callback(func(): _arriving = false)


func end() -> void:
	if _knife != null:
		_knife.queue_free()


func uses_cursor() -> bool:
	return false


func update(delta: float, input: CookInput) -> void:
	_time += delta
	var marks: Array = _piece["marks"]
	var beat := int(_time / beat_seconds)
	if beat != _last_beat and not marks.is_empty():
		_last_beat = beat
		_tick_at = _time
		if not _own_pace():  # Their own chops are the beat.
			session.play_sound("tick", _knife.position, -10.0, 0.8)
		if not _piece["mark_nodes"].is_empty():
			_pulse(_piece["mark_nodes"][0])
	session.set_status("Chops left: %d" % marks.size())
	if marks.is_empty():
		if not _chopping:
			if rest != Vector2.ZERO:
				var board := session.surface(on_surface).position
				var node: Node3D = _piece["node"]
				node.create_tween().tween_property(node, "position", Vector3(board.x + rest.x, node.position.y, board.z + rest.y), SLIDE_SECONDS).set_trans(Tween.TRANS_QUAD)
			finish(average(_rhythm))
		return
	if _arriving:
		return
	if not _chopping:
		_knife.position = _knife.position.lerp(_over_next(), 1.0 - exp(-18.0 * delta))
	if input.just_pressed:
		_chop()


# For a reel: press right on each tick.
func scripted_hold(_delta: float, _input: CookInput) -> bool:
	if _chopping or _arriving or _piece["marks"].is_empty():
		return false
	return fmod(_time, beat_seconds) < 0.04


# Over the next mark, ready to come down.
func _over_next() -> Vector3:
	var marks: Array = _piece["marks"]
	var x: float = marks[0] if not marks.is_empty() else _piece["right"]
	return Vector3(x, _board_y + knife_height, _piece["z"])


func _chop() -> void:
	if _swing != null:
		_swing.kill()  # Faster than the knife: the one on its way down lands now.
	if not _falling.is_empty():
		_land()
		if _piece["marks"].is_empty():
			_chopping = false
			return
	_chopping = true
	var x: float = _piece["marks"][0]
	_falling = [x, score_press()]
	_knife.position.x = x
	_swing = _knife.create_tween()
	_swing.tween_property(_knife, "position", Vector3(x, _board_y, _piece["z"]), chop_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing.tween_callback(_land)
	_swing.tween_property(_knife, "position:y", _board_y + knife_height, chop_seconds * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing.tween_callback(func(): _chopping = false)


# How good a press now is: on the beat, or as even as their own pace (the first
# press and the one that sets the pace are always good).
func score_press() -> float:
	var gap := _time - _last_press if _last_press >= 0.0 else -1.0
	_last_press = _time
	var off_beat := _off_beat(gap < 0.0 or absf(gap - beat_seconds) < beat_tolerance)
	var on_beat := 1.0 - clampf((off_beat - perfect_seconds) / (beat_tolerance - perfect_seconds), 0.0, 1.0)
	var even := 0.0
	if gap < 0.0:
		even = 1.0
	elif gap > slowest_pace:
		_pace = 0.0
	elif _pace <= 0.0:
		even = 1.0
		_pace = gap
	else:
		var slack := maxf(_pace * pace_slack, perfect_seconds)
		even = 1.0 - clampf((absf(gap - _pace) - slack) / maxf(maxf(_pace * pace_worst, beat_tolerance) - slack, 0.01), 0.0, 1.0)
		_pace = lerpf(_pace, gap, 0.5)
	return maxf(on_beat, even)


# Chopping away faster than the beat.
func _own_pace() -> bool:
	return _pace > 0.0 and _pace < beat_seconds * 0.8 and _time - _last_press < beat_seconds


# Seconds between this press and the nearest tick as the player hears it
# (judged when you press, not when the knife lands), learning their delay.
func _off_beat(learn := true) -> float:
	if _heard_after < 0.0:
		_heard_after = AudioServer.get_output_latency() + HEARD_AFTER_START
	# Early (negative) or late against the last tick heard, or the next one.
	var off := wrapf(_time - _tick_at - _heard_after, -beat_seconds * 0.5, beat_seconds * 0.5)
	if learn and absf(off) < beat_seconds * 0.49:  # Any press in a rhythm is a try at the beat: learn from it (not one dead between two ticks).
		_heard_after = clampf(_heard_after + off * HEARD_AFTER_LEARN, 0.0, HEARD_AFTER_MAX)
	return absf(off)


func _land() -> void:
	var x: float = _falling[0]
	var on_beat: float = _falling[1]
	_falling = []
	_piece["marks"].pop_front()
	_piece["cuts"].append(x)
	_rhythm.append(on_beat)
	_build()
	var at := Vector3(x, _board_y + _radius_at(x), _piece["z"])
	session.play_sound("chop", at, 0.0, lerpf(0.9, 1.15, on_beat))
	session.burst(at, _piece["color"], 10, 0.3)
	var words := "Perfect!" if on_beat >= 0.9 else ("On beat!" if on_beat >= 0.7 else ("Nice" if on_beat >= 0.45 else "Off beat!"))
	session.pop_text(words, at, CookSession.mood_of(on_beat))


# The carrot as pieces between its cuts (one whole before any), tapering to
# the right, with the marks still to cut above it.
func _build() -> void:
	var node: Node3D = _piece["node"]
	for child in node.get_children():
		child.queue_free()
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = _piece["color"]
	flesh.roughness = 0.5
	flesh.set_meta(ToonStyle.FOOD, "veg")
	var ring := StandardMaterial3D.new()  # A cut face: lighter, with a paler core.
	ring.albedo_color = (_piece["color"] as Color).lightened(0.14)
	ring.roughness = 0.4
	ring.set_meta(ToonStyle.FOOD, "veg")
	var core := StandardMaterial3D.new()
	core.albedo_color = (_piece["color"] as Color).lightened(0.32)
	core.roughness = 0.4
	core.set_meta(ToonStyle.FOOD, "veg")
	var middle_x: float = (_piece["left"] + _piece["right"]) * 0.5
	var edges: Array = [_piece["left"]]
	edges.append_array(_piece["cuts"])
	edges.append(_piece["right"])
	var count := edges.size() - 1
	for i in count:
		var a: float = edges[i] + (slice_gap * 0.5 if i > 0 else 0.0)
		var b: float = edges[i + 1] - (slice_gap * 0.5 if i < count - 1 else 0.0)
		var slice := MeshInstance3D.new()
		if vegetable == "celery":
			slice.mesh = Veg.stalk(b - a, _radius_at(a), _radius_at(b), _piece["color"])
		elif vegetable != "carrot":
			slice.mesh = Veg.turned(b - a, func(x): return _radius_at((a + b) * 0.5 + x), flesh)
		else:
			var mesh := CylinderMesh.new()
			mesh.bottom_radius = _radius_at(a)
			mesh.top_radius = _radius_at(b)
			mesh.height = b - a
			mesh.radial_segments = 16
			mesh.rings = 1
			mesh.material = flesh
			slice.mesh = mesh
			slice.rotation.z = -PI * 0.5  # Its top (the thin end) points right.
		# Pieces shuffle apart a touch from the middle once cut.
		var spread := (i - (count - 1) * 0.5) * slice_gap if count > 1 else 0.0
		# Each slice and its ends as one thing, so it can tip.
		var bit := Node3D.new()
		bit.position = Vector3((a + b) * 0.5 - middle_x + spread, 0.0, 0.0)
		node.add_child(bit)
		bit.add_child(slice)
		var half := (b - a) * 0.5
		if i > 0 and vegetable != "celery":  # Its left end is a cut.
			_add_face(bit, -half, _radius_at(a), -1.0, ring, core)
		if i < count - 1 and vegetable != "celery":
			_add_face(bit, half, _radius_at(b), 1.0, ring, core)
		if _is_onion() and i == 0:
			Veg.add_tip(bit, -half)
		if _is_onion() and i == count - 1:
			Veg.add_root(bit, half)
		if i == 0 and _piece.get("greens", false):
			add_greens(bit, -half, _radius_at(a))
		if i < count - 1:  # Cut off: leaning over a little on the one before; the one just cut tips over.
			var lean := 0.1 + 0.05 * sin(i * 2.7)
			bit.position.y = -_radius_at((a + b) * 0.5) * (1.0 - cos(lean)) * 0.5
			bit.rotation = Vector3(0.1 * sin(i * 4.1), 0.06 * sin(i * 1.9), lean)
			if i == count - 2:
				var rests := bit.position
				bit.rotation.z = -0.05
				bit.position = rests + Vector3(-0.002, 0.007, 0.0)
				var tip := bit.create_tween().set_parallel(true)
				tip.tween_property(bit, "rotation:z", lean, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tip.tween_property(bit, "position", rests, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var marks := []
	for mark: float in _piece["marks"]:
		marks.append(_make_mark(node, mark - middle_x, _radius_at(mark)))
	_piece["mark_nodes"] = marks


# A cut face at x (the carrot's own), facing `way` (-1 left, 1 right): a lighter
# ring with a paler core, a hair out from the piece so it shows.
func _add_face(parent: Node3D, x: float, radius: float, way: float, ring: Material, core: Material) -> void:
	var parts := [[radius * 0.97, ring, 0.0006], [radius * 0.45, core, 0.0012]]
	if _is_onion():  # Its layers, one inside another.
		parts = []
		for layer in 3:
			parts.append([radius * (0.97 - layer * 0.3), Veg.onion_paint(layer % 2 == 1), 0.0006 + layer * 0.0006])
	for part in parts:
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[0]
		mesh.height = 0.0008
		mesh.radial_segments = 16
		mesh.rings = 1
		mesh.material = part[1]
		disc.mesh = mesh
		disc.rotation.z = -PI * 0.5
		disc.position = Vector3(x + way * part[2], 0.0, 0.0)
		parent.add_child(disc)


# The next mark swells on each beat.
func _pulse(mark: Node3D) -> void:
	var tween := mark.create_tween()
	mark.scale = Vector3(2.2, 1.0, 1.25)
	tween.tween_property(mark, "scale", Vector3.ONE, beat_seconds * 0.6).set_ease(Tween.EASE_OUT)


func _radius_at(x: float) -> float:
	var t := clampf((x - _piece["left"]) / (_piece["right"] - _piece["left"]), 0.0, 1.0)
	return Veg.radius_at(vegetable, t, _piece["radius"], _piece["taper"])


func _is_onion() -> bool:
	return vegetable == "onion"


# A thin white line over the carrot where a cut goes.
func _make_mark(parent: Node3D, x: float, radius: float) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.003, 0.002, radius * 2.0 + 0.02)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	mark.mesh = mesh
	mark.position = Vector3(x, radius + 0.004, 0.0)
	parent.add_child(mark)
	return mark


# A chef's knife, its origin at the middle of the blade's edge. The blade runs
# front to back across the food, the handle toward the cook.
func _make_knife() -> Node3D:
	var knife := Node3D.new()
	knife.add_child(KitchenProps.knife())
	knife.rotation.z = deg_to_rad(knife_tilt)
	session.add_child(knife)
	return knife

