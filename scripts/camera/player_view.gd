# PlayerView: one player's view of the restaurant. A SubViewportContainer
# holding a SubViewport with that player's CameraRig inside. The SubViewport
# shares the main 3D world, so it shows the same restaurant from this rig's camera.
# ViewManager decides each view's place on screen and whether it is shown.
class_name PlayerView
extends SubViewportContainer

@onready var viewport: SubViewport = $SubViewport
@onready var rig: CameraRig = $SubViewport/CameraRig

var player_index := -1


func setup(player: Player) -> void:
	player_index = player.player_index
	name = "PlayerView%d" % player_index
	rig.set_player(player)


# Hidden views stop rendering so they cost nothing. A view coming back renders
# one frame before it is shown, so it never flashes an old picture.
func set_active(active: bool) -> void:
	if not active:
		visible = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not visible:
		modulate.a = 0.0
		visible = true
		await get_tree().process_frame  # By now the SubViewport has drawn a fresh frame.
		modulate.a = 1.0
