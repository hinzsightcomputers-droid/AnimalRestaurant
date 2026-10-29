# UiScale: smaller UI in split screen, so it doesn't cover half of a small view.
# for_view_count is the scale for a layout: the views draw their dialogue boxes
# and popups that much smaller as a whole (PlayerView.set_ui_scale), and the HUD
# scales its text with apply. Each text control remembers the size it was made
# with and is set to that times the scale.
class_name UiScale
extends RefCounted

const BY_VIEW_COUNT := [1.0, 0.72, 0.6, 0.6]  # Scale for 1, 2, 3 and 4 views.
const BASE_META := &"ui_base_font_sizes"


static func for_view_count(count: int) -> float:
	return BY_VIEW_COUNT[clampi(count, 1, BY_VIEW_COUNT.size()) - 1]


# `root` and every control under it.
static func apply(root: Node, scale: float) -> void:
	apply_one(root, scale)
	for node in root.find_children("*", "Control", true, false):
		apply_one(node, scale)


static func apply_one(node: Node, scale: float) -> void:
	var control := node as Control
	if control == null:
		return
	var keys: Array[StringName] = []
	if control is RichTextLabel:
		keys = [&"normal_font_size", &"bold_font_size"]
	elif control is Label or control is Button or control is LineEdit:
		keys = [&"font_size"]
	else:
		return
	if not control.has_meta(BASE_META):
		var base := {}
		for key in keys:
			base[key] = control.get_theme_font_size(key)
		control.set_meta(BASE_META, base)
	var sizes: Dictionary = control.get_meta(BASE_META)
	for key in sizes:
		var size := maxi(9, roundi(sizes[key] * scale))
		if control.get_theme_font_size(key) != size:
			control.add_theme_font_size_override(key, size)
