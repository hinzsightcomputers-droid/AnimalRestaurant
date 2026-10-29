# PlayerView: one player's view of the restaurant. A SubViewportContainer
# holding a SubViewport with that player's CameraRig inside. The SubViewport
# shares the main 3D world, so it shows the same restaurant from this rig's camera.
# ViewManager decides each view's place on screen and whether it is shown.
class_name PlayerView
extends SubViewportContainer

@onready var viewport: SubViewport = $SubViewport
@onready var rig: CameraRig = $SubViewport/CameraRig

var player_index := -1
var ui_scale := 1.0  # How big the UI in this view is drawn (smaller in split screen).


# UI added to the view (dialogue boxes, tickets, cooking screens) is laid out
# as if on a screen 1/ui_scale times the view's size, then shrunk to fit, so it
# keeps the proportions it has on the full screen: margins, borders and text alike.
func _ready() -> void:
	child_entered_tree.connect(func(child): _fit_ui.call_deferred(child))  # After it sets its own anchors.
	resized.connect(_fit_all_ui)


func set_ui_scale(scale: float) -> void:
	if is_equal_approx(scale, ui_scale):
		return
	ui_scale = scale
	_fit_all_ui()


func _fit_all_ui() -> void:
	for child in get_children():
		_fit_ui(child)


func _fit_ui(child: Variant) -> void:  # Untyped: it may be freed by now.
	if not is_instance_valid(child) or not child is Control or child.get_parent() != self:
		return
	var control := child as Control
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size = size / ui_scale
	control.scale = Vector2.ONE * ui_scale


func setup(player: Player) -> void:
	player_index = player.player_index
	name = "PlayerView%d" % player_index
	rig.set_player(player)


# Something just for this player is open in the view (a dialogue box, the
# drinks list, a ticket, a cooking screen): anything besides the SubViewport.
func has_own_ui() -> bool:
	for child in get_children():
		if child != viewport and not child.is_queued_for_deletion():
			return true
	return false


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
