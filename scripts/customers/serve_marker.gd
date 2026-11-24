# ServeMarker: shows which seated customer is which. Over their head, the badge
# of their table's spot (TableSpot), the same one as on their ticket. While a
# chef carries their plate (or a drink they ordered), a big arrow bounces over
# them and a ring pulses round their chair, in that chef's color. Display only:
# CustomerDisplay puts the badge over the text above their head.
class_name ServeMarker
extends Node3D

const BADGE_PIXEL := 0.0009
const ARROW_OVER_HEAD := 0.75
const ARROW_BOB := 0.12
const BOB_SPEED := 5.0
const RING_RADIUS := 0.62
const CHECK_EVERY := 0.15  # Seconds between looks at what everyone's carrying.

var customer: Customer
var badge := Sprite3D.new()
var rest_offset := 0.0     # The badge's offset (its own pixels) up from its place.
var beside := false        # Something else (the WaitIcon, the receipt) sits over the text: stand to its left.
var head_top := 1.2

var _arrow := MeshInstance3D.new()
var _ring := MeshInstance3D.new()
var _arrow_paint := StandardMaterial3D.new()
var _ring_paint := StandardMaterial3D.new()
var _spot := ""
var _check := 0.0
var _carrier: Player = null


func _ready() -> void:
	badge.pixel_size = BADGE_PIXEL
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.fixed_size = true
	badge.no_depth_test = true
	badge.render_priority = 2
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	badge.layers = 1 << (CustomerDisplay.TEXT_LAYER - 1)
	badge.visible = false
	add_child(badge)
	for paint in [_arrow_paint, _ring_paint]:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.set_meta(ToonStyle.SKIP, true)
	_arrow_paint.no_depth_test = true
	_arrow_paint.render_priority = 3
	var cone := CylinderMesh.new()  # Point down.
	cone.top_radius = 0.17
	cone.bottom_radius = 0.0
	cone.height = 0.3
	cone.radial_segments = 4
	_arrow.mesh = cone
	_arrow.material_override = _arrow_paint
	_arrow.layers = 1 << (CustomerDisplay.TEXT_LAYER - 1)
	var ring := TorusMesh.new()
	ring.inner_radius = RING_RADIUS - 0.05
	ring.outer_radius = RING_RADIUS + 0.05
	_ring.mesh = ring
	_ring.scale.y = 0.2
	_ring.position.y = 0.04
	_ring.material_override = _ring_paint
	for node in [_arrow, _ring]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_EVERY
		_carrier = _who_has_theirs()
		var spot := TableSpot.of(customer) if customer != null and customer.is_seated() else ""
		if spot != _spot:
			_spot = spot
			badge.texture = TableSpot.badge(spot) if not spot.is_empty() else null
		badge.visible = not _spot.is_empty() and not customer.quiet and not ReelSandbox.active()
	badge.offset = Vector2(-TableSpot.PIXELS * 1.05 if beside else 0.0, rest_offset)
	var shown := is_instance_valid(_carrier)
	_arrow.visible = shown
	_ring.visible = shown
	if not shown:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var color := PlayerVisual.color_for(_carrier.player_index)
	_arrow_paint.albedo_color = color
	_ring_paint.albedo_color = color
	_arrow.position.y = head_top + ARROW_OVER_HEAD + sin(time * BOB_SPEED) * ARROW_BOB
	_arrow.rotation.y = time * 2.0
	var pulse := 1.0 + 0.08 * sin(time * BOB_SPEED)
	_ring.scale = Vector3(pulse, 0.2, pulse)


# The chef carrying this customer's plate, or a drink they're waiting for.
func _who_has_theirs() -> Player:
	if customer == null or not customer.is_seated() or ReelSandbox.active():
		return null
	var wants_food := customer.state == Customer.State.WAITING_FOR_FOOD
	var wants_drink := customer.state == Customer.State.WAITING_FOR_DRINK
	if not wants_food and not wants_drink:
		return null
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		for item in player.carried():
			if wants_food and item is CookedDish and item.order.customer == customer:
				return player
			if wants_drink and item is Drink and item.id() == customer.drink.get("id", ""):
				return player
	return null
