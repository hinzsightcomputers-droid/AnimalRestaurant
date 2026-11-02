# MenuTheme: one clear highlight for whatever's picked in every menu (the
# summary and shop, the name entry screens, the letters, the collections). Sets
# the focus look on Godot's default theme, so it applies to every control that
# doesn't bring its own, and has the mouse move that same highlight rather than
# show a second, different one: hovering a button picks it.
class_name MenuTheme
extends RefCounted

const RING_COLOR := Color(1.0, 0.62, 0.12)
const FILL_COLOR := Color(1.0, 0.8, 0.3, 0.35)
const PICKED_TEXT := Color(1.0, 0.97, 0.85)
const FOCUSABLE := ["Button", "CheckBox", "CheckButton", "OptionButton", "LineEdit", "HSlider", "VSlider", "SpinBox", "ItemList", "TabBar"]


static func apply() -> void:
	var theme := ThemeDB.get_default_theme()
	var ring := StyleBoxFlat.new()
	ring.bg_color = FILL_COLOR
	ring.set_border_width_all(4)
	ring.border_color = RING_COLOR
	ring.set_corner_radius_all(6)
	ring.set_expand_margin_all(3)
	for type in FOCUSABLE:
		theme.set_stylebox("focus", type, ring)
	theme.set_color("font_focus_color", "Button", PICKED_TEXT)
	# Hovering looks like the button's normal self: the ring is the only highlight.
	theme.set_stylebox("hover", "Button", theme.get_stylebox("normal", "Button"))
	theme.set_color("font_hover_color", "Button", theme.get_color("font_color", "Button"))


# Called for every node added to the tree (Settings): a button the mouse moves
# onto takes the focus, so mouse and gamepad share the one highlight.
static func watch(node: Node) -> void:
	var button := node as BaseButton
	if button != null and button.focus_mode != Control.FOCUS_NONE:
		button.mouse_entered.connect(func():
			if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
				button.grab_focus())
