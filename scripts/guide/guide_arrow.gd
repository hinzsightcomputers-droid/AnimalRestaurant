# GuideArrow: one player's arrow for the Guide, a flat arrow on the floor just
# out from their feet that turns to point the way and nudges forward and back,
# drawn over everything so furniture never hides it. With it, a line low in
# that player's view (above the HUD's messages) saying what the step is. Display only.
class_name GuideArrow
extends Node3D

const OUT := 0.6            # How far from the player the arrow starts (meters).
const NUDGE := 0.12         # How far it nudges out and back...
const NUDGE_SPEED := 5.0    # ...and how fast.
const TURN_SPEED := 10.0
const SIZE := 1.5           # The arrow's scale.
const FILL := Color(1.0, 0.82, 0.25)
const EDGE := Color(0.35, 0.22, 0.1)
const HINT_FROM_BOTTOM := 200.0  # Pixels from the view's bottom to the hint's, clear of the HUD's messages.
const HINT_GAP := 46.0           # Between the hints of players sharing a view.

var _shape := Node3D.new()
var _hint := Control.new()  # Covers the view (PlayerView sizes and scales it)...
var _row := CenterContainer.new()  # ...with a row near its bottom, centering the pill.
var _pill := PanelContainer.new()
var _hint_text := Label.new()
var _time := 0.0
var _shown := false


func _ready() -> void:
	top_level = true
	visible = false
	add_child(_shape)
	_shape.add_child(_mesh(SIZE * 1.25, EDGE, 0))
	_shape.add_child(_mesh(SIZE, FILL, 1))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(EDGE, 0.8)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_pill.add_theme_stylebox_override("panel", style)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(_row)
	_row.add_child(_pill)
	_hint_text.add_theme_font_size_override("font_size", int(Guide.settings().get("hint_font_size", 24)))
	_hint_text.add_theme_color_override("font_color", FILL)
	_pill.add_child(_hint_text)
	_hint.visible = false


func _exit_tree() -> void:
	if is_instance_valid(_hint):
		_hint.queue_free()


func point(player: Player, heading: Vector3, hint: String, view: Control) -> void:
	_time += get_process_delta_time()
	global_position = player.global_position + Vector3(0.0, 0.05, 0.0)
	var angle := atan2(-heading.x, -heading.z)  # The arrow's tip is along -z.
	rotation.y = angle if not _shown else lerp_angle(rotation.y, angle, 1.0 - exp(-TURN_SPEED * get_process_delta_time()))
	_shape.position.z = -(OUT + NUDGE * (0.5 + 0.5 * sin(_time * NUDGE_SPEED)))
	visible = true
	_shown = true
	show_hint(player, hint, view)


func hide_arrow() -> void:
	visible = false
	_shown = false
	_hint.visible = false


func show_hint(player: Player, hint: String, view: Control) -> void:
	if view == null:
		_hint.visible = false
		return
	if _hint.get_parent() != view:
		if _hint.get_parent() != null:
			_hint.get_parent().remove_child(_hint)
		view.add_child(_hint)
	var several := InputSetup.active_players().size() > 1
	_hint_text.text = "P%d: %s" % [player.player_index + 1, hint] if several else hint
	_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var bottom := -(HINT_FROM_BOTTOM + player.player_index * HINT_GAP)
	_row.offset_left = 0.0
	_row.offset_right = 0.0
	_row.offset_top = bottom - _pill.get_combined_minimum_size().y
	_row.offset_bottom = bottom
	_hint.visible = true


# A flat arrow, tip along -z, lying on the floor.
static func _mesh(scale: float, color: Color, priority: int) -> MeshInstance3D:
	var outline := PackedVector2Array([
		Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.07, -0.3), Vector2(0.2, -0.3),
		Vector2(0.0, -0.6), Vector2(-0.2, -0.3), Vector2(-0.07, -0.3)])
	var center := Vector2(0.0, -0.3)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in Geometry2D.triangulate_polygon(outline):
		var p := center + (outline[i] - center) * scale
		tool.add_vertex(Vector3(p.x, 0.0, p.y))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = priority
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
