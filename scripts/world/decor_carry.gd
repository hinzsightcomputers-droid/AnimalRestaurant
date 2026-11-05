# DecorCarry: lives on a chef and lets them move placed decor without opening
# Decorate mode. Holding interact or left click next to something (hands empty)
# lifts it; it then sits on the squares in front of the chef as they walk, slowly
# so it's easy to aim, green where it can go and red where it can't. Letting go drops it there, or back where it was.
# While carrying, a flick of the right stick or a sideways swipe of the mouse
# turns it a quarter turn. Wall decor goes to the free wall spot nearest the chef.
class_name DecorCarry
extends Node

const HOLD_SECONDS := 0.35  # Held this long, the press lifts what's beside the chef.
const CARRY_SPEED := 0.35   # The chef's walking speed while carrying, as a share of normal.
const FLOOR_REACH := 0.8    # How far from a floor item's edge the chef can lift it.
const WALL_REACH := 1.3     # How far from a wall spot.
const CARRY_GAP := 0.6      # From the chef to the near edge of what's carried.
const MOUSE_TURN := 120.0   # Pixels of sideways mouse movement to a quarter turn.
const STICK_ON := 0.7       # A flick: the stick out past this...
const STICK_OFF := 0.3      # ...and it has to come back inside this before the next one.
const MARKER_BORDER := 0.3  # How much wider the green or red square is than what it's under.

var chef: Player
var carried: Dictionary = {}  # What's being carried, as it was placed. Empty when nothing is.
var turn := 0

var _room: DecorRoom
var _can_lift := false        # This press started empty-handed.
var _by_mouse := false        # This press is left click, not interact.
var _held_for := 0.0
var _point := Vector2.ZERO    # Where it would go.
var _spot := -1               # The wall spot it would go to.
var _fits := false
var _mouse_x := 0.0
var _stick_out := false
var _ghost: Node3D
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D


# The chef's interact button just went down, before it's used on anything.
func press(empty_handed: bool) -> void:
	_can_lift = empty_handed
	_by_mouse = false
	_held_for = 0.0


# Unhandled, so a click on a button on screen doesn't count.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and InputSetup.pad_of(chef.player_index) < 0 and carried.is_empty():
		press(chef.held_item == null)
		_by_mouse = true


func _holding() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) if _by_mouse else chef.input.is_interact_pressed()


# What the chef's speed is multiplied by.
func speed_share() -> float:
	return 1.0 if carried.is_empty() else CARRY_SPEED


func _physics_process(delta: float) -> void:
	if carried.is_empty():
		_watch(delta)
		return
	if not _holding():
		_drop()
		return
	var pad := InputSetup.pad_of(chef.player_index)
	if pad >= 0:
		stick_turn(Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)))
	_follow()


func _input(event: InputEvent) -> void:
	if carried.is_empty() or not event is InputEventMouseMotion or InputSetup.pad_of(chef.player_index) >= 0:
		return
	var moved: float = event.relative.x
	if signf(moved) != signf(_mouse_x):
		_mouse_x = 0.0
	_mouse_x += moved
	if absf(_mouse_x) >= MOUSE_TURN:
		_turn_toward(_mouse_x)
		_mouse_x = 0.0


# One flick, one quarter turn: the stick has to come back before the next.
func stick_turn(stick: Vector2) -> void:
	if stick.length() < STICK_OFF:
		_stick_out = false
	elif stick.length() >= STICK_ON and not _stick_out:
		_stick_out = true
		_turn_toward(stick.x)


# Clockwise for a push to the right, as seen from above.
func _turn_toward(side: float) -> void:
	turn = posmod(turn + (-90 if side >= 0.0 else 90), 360)


func _watch(delta: float) -> void:
	if not _can_lift or not _holding():
		_can_lift = false
		return
	if chef.movement_locked or chef.in_conversation() or chef.held_item != null:
		_can_lift = false
		return
	_held_for += delta
	if _held_for >= HOLD_SECONDS:
		_can_lift = false
		var index := nearest()
		if index >= 0:
			_lift(index)


func _chef_at() -> Vector2:
	return Vector2(chef.global_position.x, chef.global_position.z)


# The placed decor in reach of the chef (its index in decor_placed), or -1.
func nearest() -> int:
	var best := -1
	var best_gap := INF
	var at := _chef_at()
	for i in GameState.decor_placed.size():
		var placed: Dictionary = GameState.decor_placed[i]
		var item := Decor.get_item(String(placed.get("id", "")))
		if item.is_empty():
			continue
		var gap := INF
		var spot := int(placed.get("spot", -1))
		if spot >= 0:
			var wall := Decor.spot_position(spot)
			gap = at.distance_to(Vector2(wall.x, wall.z))
			if gap > WALL_REACH:
				continue
		else:
			var half := Decor.footprint(item, int(placed.get("turn", 0))) * 0.5
			var middle := Vector2(float(placed["x"]), float(placed["z"]))
			gap = at.distance_to(at.clamp(middle - half, middle + half))
			if gap > FLOOR_REACH:
				continue
		if gap < best_gap:
			best = i
			best_gap = gap
	return best


func _lift(index: int) -> void:
	_room = get_tree().get_first_node_in_group(DecorRoom.GROUP) as DecorRoom
	if _room == null:
		return
	carried = GameState.decor_placed[index].duplicate()
	turn = int(carried.get("turn", 0))
	GameState.decor_take_back(index)
	_room.refresh()
	_room.collect_stations()
	chef.decorating = true  # Interact belongs to this until it's let go.
	_mouse_x = 0.0
	_stick_out = false
	_ghost = Decor.build(Decor.get_item(String(carried["id"])))
	_room.add_sibling(_ghost)
	var plane := PlaneMesh.new()
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = _marker_material
	_marker = MeshInstance3D.new()
	_marker.mesh = plane
	_room.add_sibling(_marker)
	_follow()


# Keeps what's carried on the squares in front of the chef.
func _follow() -> void:
	var item := Decor.get_item(String(carried["id"]))
	var size := Decor.footprint(item, turn)
	if item.get("kind", "floor") == "wall":
		_spot = _nearest_free_spot()
		_fits = _spot >= 0
		if _fits:
			var wall := Decor.spot_position(_spot)
			_point = Vector2(wall.x, wall.z)
			_ghost.position = wall
			_ghost.rotation_degrees.y = Decor.spot_turn(_spot)
	else:
		var yaw := chef.visual.rotation.y
		var ahead := Vector2(sin(yaw), cos(yaw)) * (CARRY_GAP + maxf(size.x, size.y) * 0.5)
		_point = Decor.snap(item, _chef_at() + ahead, turn)
		_fits = _room.can_go(item, _point, turn)
		_ghost.position = Vector3(_point.x, 0.0, _point.y)
		_ghost.rotation_degrees.y = turn
	_marker.position = Vector3(_point.x, 0.05, _point.y)
	(_marker.mesh as PlaneMesh).size = size + Vector2.ONE * MARKER_BORDER  # Bigger than the item, so it shows around it.
	_marker_material.albedo_color = DecorateMode.OK_COLOR if _fits else DecorateMode.NO_COLOR


func _nearest_free_spot() -> int:
	var best := -1
	var best_distance := INF
	for spot in Decor.settings().get("wall_spots", []).size():
		var at := Decor.spot_position(spot)
		var distance := Vector2(at.x, at.z).distance_to(_chef_at())
		if distance < best_distance and not Decor.spot_taken(spot):
			best = spot
			best_distance = distance
	return best


func _drop() -> void:
	if _fits:
		GameState.decor_place(String(carried["id"]), _point.x, _point.y, turn, _spot if _spot >= 0 else -1)
	else:
		_put_back()
	carried = {}
	_spot = -1
	_ghost.queue_free()
	_marker.queue_free()
	chef.decorating = false
	_room.refresh()
	SaveGame.save_game()


func _put_back() -> void:
	GameState.decor_place(String(carried["id"]), float(carried["x"]), float(carried["z"]), int(carried.get("turn", 0)), int(carried.get("spot", -1)))


# The restaurant reloaded mid-carry: it goes back where it was.
func _exit_tree() -> void:
	if not carried.is_empty():
		_put_back()
		carried = {}
