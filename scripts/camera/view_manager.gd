# ViewManager: hybrid split screen. Every player has their own PlayerView
# (SubViewport + CameraRig); this decides which views are on screen and where.
#
# With 3 or 4 players the screen is simply split four ways, a quarter each
# (player 1 top left, 2 top right, 3 bottom left, 4 bottom right) that never
# moves, whatever anyone is doing. A quarter nobody has (3 players) shows the
# whole restaurant from above. With 2 players the views are dynamic:
#
# Each frame players are sorted into groups:
#   - A player whose camera wants to zoom in (cooking, cleaning, taking an order),
#     or who has something open just for them (a dialogue box, the drinks list),
#     is always a group of one, so they get their own view to see it in.
#   - Everyone else is grouped with anyone close by. Groups split when players
#     drift further than split_distance apart and merge again once they're within
#     merge_distance (the gap stops the screen flickering at the edge).
# Each group gets one view on screen: the view of its lowest-numbered player,
# with that player's rig following the whole group. Views slide into place.
# The smaller the views, the smaller the UI drawn in them (dialogue boxes,
# popups: see PlayerView.set_ui_scale) and the HUD's text (UiScale), and the
# closer each camera follows its chef, so they don't look far away.
class_name ViewManager
extends CanvasLayer

const PLAYER_VIEW_SCENE := preload("res://scenes/camera/player_view.tscn")

# Screen areas (left, top, right, bottom as fractions of the screen): one view,
# two side by side, and the four-way split.
const LAYOUTS := {
	1: [Rect2(0, 0, 1, 1)],
	2: [Rect2(0, 0, 0.5, 1), Rect2(0.5, 0, 0.5, 1)],
	4: [Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)],
}
const FOLLOW_ZOOM := { 1: 1.0, 2: 0.95, 4: 0.8 }  # Camera follow distance for each layout (the solo view is already close).
const FOCUS_ZOOM := { 1: 1.0, 2: 0.9, 4: 0.78 }    # Close-up (minigame) distance for each layout.
const OVERVIEW_LOOK_AT := Vector3(0.0, 0.0, -2.0)  # The overview's camera: the dining room and kitchen.
const OVERVIEW_OFFSET := Vector3(0.0, 10.0, 6.0)

@export var player_manager: PlayerManager
@export var fixed_split_players := 3  # This many players or more: the fixed four-way split.
@export var split_distance := 6.5     # Meters apart before a shared view splits.
@export var merge_distance := 5.0     # Meters apart before split views join again.
@export var transition_time := 0.45   # Seconds for views to slide into a new layout.
@export var camera_glide_extra := 0.3 # A splitting view's camera keeps gliding this much longer.
@export var divider_pixels := 4.0     # Gap between views.
@export var divider_color := Color(0.25, 0.18, 0.12)

var _views: Dictionary = {}     # player_index -> PlayerView
var _groups: Array = []         # Current groups, e.g. [[0, 2], [1]], each sorted, lowest first.
var _layout_tween: Tween = null
var _fixed := false             # Using the fixed four-way split.
var _overview: SubViewportContainer = null  # The whole room, in a quarter of the split nobody has.
var ui_scale := 1.0             # Size of the UI for the current layout (UiScale).


func _ready() -> void:
	var divider := ColorRect.new()
	divider.color = divider_color
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(divider)
	_overview = _make_overview()
	add_child(_overview)

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


# A player's own view (null if they have none yet), e.g. to show UI just for them.
func view_for(player_index: int) -> Control:
	return _views.get(player_index)


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
	_fixed = indices.size() >= fixed_split_players
	# The fixed split, or two players with the hybrid camera turned off (Settings): a view each.
	if _fixed or (indices.size() == 2 and not Settings.hybrid_camera):
		for index in indices:
			result.append([index])
		return result

	var free: Array = []
	for index in indices:
		if _views[index].rig.focus_requested or _views[index].has_own_ui():
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

	var slots := 4 if _fixed else clampi(new_groups.size(), 1, 2)
	var layout: Array = LAYOUTS[slots]
	var owners := []
	for i in new_groups.size():
		var group: Array = new_groups[i]
		var view: PlayerView = _views[group[0]]
		var rect: Rect2 = layout[group[0] % 4 if _fixed else mini(i, slots - 1)]  # Fixed: each player's own corner.
		owners.append(group[0])

		var targets: Array[Node3D] = []
		for index in group:
			targets.append(_views[index].rig.player)
		view.rig.set_follow_targets(targets)

		# A view coming on screen starts as an exact copy of the view its player
		# was in (same screen area, same camera), then slides and glides away.
		if not view.visible:
			var shown_in: int = _group_of(group[0])
			if shown_in != -1 and shown_in != group[0]:
				view.rig.copy_view_from(_views[shown_in].rig, transition_time + camera_glide_extra)
			view.set_active(true)
			_set_rect(view, old_rects.get(group[0], rect), slots)
		move_child(view, -1)  # Views on screen draw above ones leaving it.
		_tween_rect(view, rect, slots)

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
	_show_overview(layout, owners)
	_groups = new_groups
	ui_scale = UiScale.for_view_count(slots)
	for view in _views.values():
		view.set_ui_scale(ui_scale)
		view.rig.view_zoom = FOLLOW_ZOOM[slots]
		view.rig.focus_zoom = FOCUS_ZOOM[slots]


# A view of the whole restaurant from above, sharing the main 3D world like a PlayerView.
func _make_overview() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.name = "Overview"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.visible = false
	var viewport := SubViewport.new()
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(viewport)
	var camera := Camera3D.new()
	camera.transform = Transform3D(Basis.looking_at(-OVERVIEW_OFFSET), OVERVIEW_LOOK_AT + OVERVIEW_OFFSET)
	viewport.add_child(camera)
	return container


# In the four-way split, the overview fills the first quarter no player has.
func _show_overview(layout: Array, owners: Array) -> void:
	var free_corner := -1
	if _fixed:
		for corner in layout.size():
			if not owners.any(func(index): return index % 4 == corner):
				free_corner = corner
				break
	var viewport: SubViewport = _overview.get_child(0)
	if free_corner == -1:
		_overview.visible = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_set_rect(_overview, layout[free_corner], layout.size())
	_overview.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


# Where on screen views are zoomed in on something (a minigame, a chat), in
# split screen only: the HUD keeps clear of them.
func close_up_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if _groups.size() <= 1:
		return rects
	for view in _views.values():
		if view.visible and view.rig.focus_requested:
			rects.append(view.get_global_rect())
	return rects


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
