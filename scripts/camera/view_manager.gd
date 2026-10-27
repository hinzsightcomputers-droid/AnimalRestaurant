# ViewManager: hybrid split screen. Every player has their own PlayerView
# (SubViewport + CameraRig); this decides which views are on screen and where.
#
# Each frame players are sorted into groups:
#   - A player whose camera wants to zoom in (cooking, cleaning, taking an order)
#     is always a group of one, so they get their own zoomed-in view.
#   - Everyone else is grouped with anyone close by. Groups split when players
#     drift further than split_distance apart and merge again once they're within
#     merge_distance (the gap stops the screen flickering at the edge).
# Each group gets one view on screen: the view of its lowest-numbered player,
# with that player's rig following the whole group. Views slide into place.
class_name ViewManager
extends CanvasLayer

const PLAYER_VIEW_SCENE := preload("res://scenes/camera/player_view.tscn")

# Screen areas (left, top, right, bottom as fractions of the screen) for 1-4 views.
const LAYOUTS := [
	[Rect2(0, 0, 1, 1)],
	[Rect2(0, 0, 0.5, 1), Rect2(0.5, 0, 0.5, 1)],
	[Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 1, 0.5)],
	[Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)],
]

@export var player_manager: PlayerManager
@export var split_distance := 6.5     # Meters apart before a shared view splits.
@export var merge_distance := 5.0     # Meters apart before split views join again.
@export var transition_time := 0.35   # Seconds for views to slide into a new layout.
@export var divider_pixels := 4.0     # Gap between views.
@export var divider_color := Color(0.25, 0.18, 0.12)

var _views: Dictionary = {}     # player_index -> PlayerView
var _groups: Array = []         # Current groups, e.g. [[0, 2], [1]], each sorted, lowest first.
var _layout_tween: Tween = null


func _ready() -> void:
	var divider := ColorRect.new()
	divider.color = divider_color
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(divider)

	player_manager.player_joined.connect(_add_view)
	# Players spawned before we were ready.
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		_add_view(node)


func _process(_delta: float) -> void:
	var groups := _find_groups()
	if groups != _groups:
		_apply_groups(groups)


# The camera rig belonging to a player (null if they have none yet).
func rig_for(player_index: int) -> CameraRig:
	var view: PlayerView = _views.get(player_index)
	return view.rig if view != null else null


# Groups currently on screen, e.g. [[0, 2], [1]].
func groups() -> Array:
	return _groups.duplicate(true)


func _add_view(player: Player) -> void:
	if _views.has(player.player_index):
		return
	var view: PlayerView = PLAYER_VIEW_SCENE.instantiate()
	add_child(view)
	view.setup(player)
	view.set_active(false)
	_views[player.player_index] = view
	_groups = []  # Force a fresh layout next frame.


func _find_groups() -> Array:
	var players := {}  # player_index -> Player
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if _views.has(node.player_index):
			players[node.player_index] = node
	var indices := players.keys()
	indices.sort()

	var result: Array = []
	var free: Array = []
	for index in indices:
		if _views[index].rig.focus_requested:
			result.append([index])
		else:
			free.append(index)

	# Join up close players (union-find: each player points at a group leader).
	var leader := {}
	for index in free:
		leader[index] = index
	for a in free.size():
		for b in range(a + 1, free.size()):
			var pa: Player = players[free[a]]
			var pb: Player = players[free[b]]
			var together_now := _group_of(free[a]) == _group_of(free[b])
			var limit := split_distance if together_now else merge_distance
			var gap := Vector2(pa.global_position.x - pb.global_position.x, pa.global_position.z - pb.global_position.z)
			if gap.length() < limit:
				leader[_find_leader(leader, free[b])] = _find_leader(leader, free[a])

	var by_leader := {}
	for index in free:
		var top: int = _find_leader(leader, index)
		if not by_leader.has(top):
			by_leader[top] = []
		by_leader[top].append(index)
	result.append_array(by_leader.values())

	for group in result:
		group.sort()
	result.sort_custom(func(x, y): return x[0] < y[0])
	return result


func _find_leader(leader: Dictionary, index: int) -> int:
	while leader[index] != index:
		index = leader[index]
	return index


# Which group (by its first player) a player is in right now, or -1.
func _group_of(player_index: int) -> int:
	for group in _groups:
		if player_index in group:
			return group[0]
	return -1


func _apply_groups(new_groups: Array) -> void:
	var old_rects := {}  # player_index -> screen area of the view they were shown in
	for index in _views:
		var shown_in: int = _group_of(index)
		if shown_in != -1:
			old_rects[index] = _rect_of(_views[shown_in])

	if _layout_tween != null:
		_layout_tween.kill()
	_layout_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var layout: Array = LAYOUTS[clampi(new_groups.size(), 1, LAYOUTS.size()) - 1]
	var owners := []
	for i in new_groups.size():
		var group: Array = new_groups[i]
		var view: PlayerView = _views[group[0]]
		owners.append(group[0])

		var targets: Array[Node3D] = []
		for index in group:
			targets.append(_views[index].rig.player)
		view.rig.set_follow_targets(targets)

		# A view coming on screen starts where its player was being shown.
		if not view.visible:
			view.set_active(true)
			_set_rect(view, old_rects.get(group[0], layout[mini(i, layout.size() - 1)]), new_groups.size())
		move_child(view, -1)  # Views on screen draw above ones leaving it.
		_tween_rect(view, layout[mini(i, layout.size() - 1)], new_groups.size())

	# Views no longer on screen go back to following just their own player,
	# and hide once the others have slid over them.
	for index in _views:
		if index in owners:
			continue
		var view: PlayerView = _views[index]
		var just_them: Array[Node3D] = [view.rig.player]
		view.rig.set_follow_targets(just_them)
		if view.visible:
			_layout_tween.chain().tween_callback(view.set_active.bind(false))
	_groups = new_groups


func _rect_of(view: Control) -> Rect2:
	return Rect2(view.anchor_left, view.anchor_top, view.anchor_right - view.anchor_left, view.anchor_bottom - view.anchor_top)


func _set_rect(view: Control, rect: Rect2, view_count: int) -> void:
	for property in _rect_properties(rect, view_count):
		view.set(property[0], property[1])


func _tween_rect(view: Control, rect: Rect2, view_count: int) -> void:
	for property in _rect_properties(rect, view_count):
		_layout_tween.tween_property(view, property[0], property[1], transition_time)


# Anchors for the area, plus offsets that leave a divider gap on inside edges.
func _rect_properties(rect: Rect2, view_count: int) -> Array:
	var half_gap := divider_pixels * 0.5 if view_count > 1 else 0.0
	return [
		["anchor_left", rect.position.x],
		["anchor_top", rect.position.y],
		["anchor_right", rect.end.x],
		["anchor_bottom", rect.end.y],
		["offset_left", half_gap if rect.position.x > 0.0 else 0.0],
		["offset_top", half_gap if rect.position.y > 0.0 else 0.0],
		["offset_right", -half_gap if rect.end.x < 1.0 else 0.0],
		["offset_bottom", -half_gap if rect.end.y < 1.0 else 0.0],
	]
