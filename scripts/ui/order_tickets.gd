# OrderTickets: the HUD's orders, as a stack of little paper tickets: a picture of
# the dish, its name, who it's for (and their face) with their table's badge (TableSpot, the same
# one that's over that customer's head), and how far along it is. The most
# urgent come first, then "+2 more". The HUD says which orders and how big.
class_name OrderTickets
extends VBoxContainer

const PAPER := Color(0.99, 0.96, 0.88)
const INK := Color("#502312")
const FADED := Color("#90523C")
const WIDTH := 322.0
const ICON := 62.0
const BADGE := 24.0
const FACE := 46.0              # Whoever ordered it, on the right.
const STRIP := 7.0              # The colored edge that says how far along it is.
const STATES := {               # Words and color.
	Order.State.WAITING: ["Waiting", Color("#A97251")],
	Order.State.GATHERED: ["Ingredients out", Color("#FFB347")],
	Order.State.COOKING: ["Cooking", Color("#E07228")],
	Order.State.READY: ["Ready to serve!", Color("#8DBE3E")],
}
const OFF_WHEEL := ["Clip the ticket", Color("#D63C3C")]

var _icons := DishIcons.new()
var _shown := ""                # What the tickets say now, to leave them be till it changes.
var _orders: Array = []
var _more := 0
var _scale := 1.0
var _note: Callable


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icons)
	_icons.ready_to_show.connect(func():
		_shown = ""
		show_orders(_orders, _more, _scale, _note))


# Show these orders, then "+`more` more", at `ui_scale`. `note` gives an
# order's extra words (its time left), or "".
func show_orders(orders: Array, more: int, ui_scale: float, note: Callable) -> void:
	_orders = orders
	_more = more
	_scale = ui_scale
	_note = note
	var key := "%s %d" % [ui_scale, more]
	for order: Order in orders:
		key += "|%d %d %s %s %s %s" % [order.number, order.state, order.on_wheel, TableSpot.of(order.customer), order.for_name(), note.call(order)]
	if key == _shown:
		return
	_shown = key
	for child in get_children():
		if child != _icons:
			remove_child(child)
			child.queue_free()
	add_theme_constant_override("separation", roundi(7.0 * ui_scale))
	for order: Order in orders:
		add_child(_ticket(order, note.call(order)))
	if more > 0:
		var label := _label("+%d more" % more, 20, Color.WHITE)
		UiStyle.hud_label(label)
		label.add_theme_constant_override("outline_size", roundi(7.0 * ui_scale))
		add_child(label)
	reset_size()


func _ticket(order: Order, note: String) -> Control:
	var state: Array = STATES[order.state] if order.on_wheel or order.state != Order.State.WAITING else OFF_WHEEL
	var paper := PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.custom_minimum_size.x = WIDTH * _scale
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = state[1]
	style.border_width_left = roundi(STRIP * _scale)
	style.set_corner_radius_all(roundi(9.0 * _scale))
	style.shadow_color = Color(0.2, 0.1, 0.05, 0.35)
	style.shadow_size = roundi(5.0 * _scale)
	style.shadow_offset = Vector2(1.0, 3.0) * _scale
	style.content_margin_left = (STRIP + 5.0) * _scale
	style.content_margin_right = 10.0 * _scale
	style.content_margin_top = 3.0 * _scale
	style.content_margin_bottom = 4.0 * _scale
	paper.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi(7.0 * _scale))
	paper.add_child(row)
	row.add_child(_picture(_icons.icon(order.dish), ICON))
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lines.add_theme_constant_override("separation", roundi(-3.0 * _scale))
	row.add_child(lines)
	var dish := _label(String(order.dish.get("name", "?")), 20, INK)
	UiStyle.title(dish)
	_trim(dish)
	lines.add_child(dish)
	var who := HBoxContainer.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_theme_constant_override("separation", roundi(5.0 * _scale))
	lines.add_child(who)
	var spot := TableSpot.of(order.customer)
	if not spot.is_empty():
		who.add_child(_picture(TableSpot.badge(spot), BADGE))
	var whom := _label(order.for_name() if spot.is_empty() else "%s, %s" % [order.for_name(), TableSpot.title(spot)], 17, INK)
	_trim(whom)
	who.add_child(whom)
	var status := _label("#%d  %s%s" % [order.number, note, state[0]], 16, (state[1] as Color).darkened(0.35) if order.state != Order.State.WAITING or not order.on_wheel else FADED)
	_trim(status)
	lines.add_child(status)
	var display: CustomerDisplay = order.customer.get_node_or_null("Display") as CustomerDisplay if is_instance_valid(order.customer) else null
	if display != null:
		row.add_child(_picture(_icons.face(display), FACE))
	return paper


func _picture(texture: Texture2D, width: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.custom_minimum_size = Vector2.ONE * width * _scale
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	var size_now := maxi(9, roundi(font_size * _scale))
	label.add_theme_font_size_override("font_size", size_now)
	label.set_meta(UiScale.BASE_META, { &"font_size": font_size })  # So UiScale doesn't scale it again.
	return label


# Cut short with "..." rather than making the ticket wider.
func _trim(label: Label) -> void:
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
