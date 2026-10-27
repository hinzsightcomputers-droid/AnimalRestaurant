# ViewManager: gives every player their own PlayerView (SubViewport + CameraRig)
# and decides which views are on screen and where.
#
# For now there is one view on screen: the lowest-numbered player's, full screen,
# following every player (a shared view). The other players' views exist but
# are hidden and not rendering. Split screen will replace _update_layout().
class_name ViewManager
extends CanvasLayer

const PLAYER_VIEW_SCENE := preload("res://scenes/camera/player_view.tscn")

@export var player_manager: PlayerManager

var _views: Dictionary = {}  # player_index -> PlayerView


func _ready() -> void:
	player_manager.player_joined.connect(_add_view)
	# Players spawned before we were ready.
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		_add_view(node)


# The camera rig belonging to a player (null if they have none yet).
func rig_for(player_index: int) -> CameraRig:
	var view: PlayerView = _views.get(player_index)
	return view.rig if view != null else null


func _add_view(player: Player) -> void:
	if _views.has(player.player_index):
		return
	var view: PlayerView = PLAYER_VIEW_SCENE.instantiate()
	add_child(view)
	view.setup(player)
	_views[player.player_index] = view
	_update_layout()


func _update_layout() -> void:
	var indices := _views.keys()
	indices.sort()
	var everyone: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		everyone.append(node)

	for i in indices.size():
		var view: PlayerView = _views[indices[i]]
		var is_shared_view := i == 0
		view.set_active(is_shared_view)
		if is_shared_view:
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			view.rig.set_follow_targets(everyone)
