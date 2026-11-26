# UiStyle: the look of the HUD and menus, read from data/ui_style.json (the Art
# Style Guide's palette and "rounded cream and wood panels with a thin darker
# outline"). Screens ask it for their panel box and colors instead of each
# keeping its own near-copy of cream and brown, so a change to the guide is one
# edit in the JSON. Reads its own file because Settings applies the theme before
# GameData has loaded.
class_name UiStyle
extends RefCounted

const PATH := "res://data/ui_style.json"
const FALLBACK := Color(1, 0, 1)  # A loud pink, so a misspelled color name shows.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"palette": {}}
	return _data


# A palette color by its name in the guide ("cream", "dark_wood"), or a
# "#rrggbb" written straight in.
static func color(name: String) -> Color:
	if name.begins_with("#"):
		return Color(name)
	var html: String = data().get("palette", {}).get(name, "")
	if html == "":
		push_warning("UiStyle: no palette color named '%s'" % name)
		return FALLBACK
	return Color(html)


# A color from one of the JSON's groups: role("text", "body").
static func role(group: String, key: String) -> Color:
	return color(String(data().get(group, {}).get(key, "")))


# The cream panel with its wood outline, for every menu, box and banner.
static func panel(margin: float = 24.0) -> StyleBoxFlat:
	var spec: Dictionary = data().get("panel", {})
	var style := StyleBoxFlat.new()
	style.bg_color = color(spec.get("fill", "cream"))
	style.bg_color.a = float(spec.get("opacity", 1.0))
	style.border_color = color(spec.get("outline", "wood"))
	style.set_border_width_all(int(spec.get("outline_width", 4)))
	style.set_corner_radius_all(int(spec.get("corner_radius", 16)))
	style.set_content_margin_all(margin)
	return style


# Gives a panel built in a scene file the shared look, keeping its margins.
static func restyle_panel(node: Control) -> void:
	var old := node.get_theme_stylebox("panel")
	var style := panel(old.content_margin_left if old != null else 24.0)
	if old != null:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, old.get_content_margin(side))
	node.add_theme_stylebox_override("panel", style)


# Outlined text over the game (the clock, money, orders): cream on dark wood.
static func hud_label(label: Label, key: String = "text") -> void:
	label.add_theme_color_override("font_color", role("hud", key))
	label.add_theme_color_override("font_outline_color", role("hud", "outline"))


# A little slate board in a wood frame for the HUD, like the menu chalkboard.
static func chalk_board(margin_x: float = 14.0, margin_y: float = 4.0) -> StyleBoxFlat:
	var spec: Dictionary = data().get("chalk", {})
	var box := StyleBoxFlat.new()
	box.bg_color = color(spec.get("slate", "#2E3B35"))
	box.border_color = color(spec.get("frame", "wood"))
	box.set_border_width_all(int(spec.get("frame_width", 5)))
	box.set_corner_radius_all(int(spec.get("corner_radius", 10)))
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0.0, 3.0)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box


# Chalk writing (chalk.text, .money, .streak or .warning) in the title font, a
# faint smudge of dust under it; on its own little board unless `board` is false.
static func chalk_label(label: Label, key: String = "text", board := true) -> void:
	var spec: Dictionary = data().get("chalk", {})
	var chalk := color(spec.get(key, "#F3EFE2"))
	label.add_theme_color_override("font_color", chalk)
	label.add_theme_color_override("font_outline_color", color(spec.get("slate", "#2E3B35")))
	label.add_theme_constant_override("outline_size", 6 if board else 10)
	label.add_theme_color_override("font_shadow_color", Color(chalk, float(spec.get("dust", 0.25))))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	title(label)
	if board:
		label.add_theme_stylebox_override("normal", chalk_board())


# Chalk writing floating in the room (a Label3D: "[E] Cook"): chalk on a slate outline.
static func chalk_3d(label: Label3D, key: String = "text") -> void:
	var spec: Dictionary = data().get("chalk", {})
	title(label)
	label.modulate = color(spec.get(key, "#F3EFE2"))
	label.outline_modulate = color(spec.get("slate", "#2E3B35"))


# Sets the default theme's buttons and font, so every button that doesn't bring
# its own look is a tan wood-edged one that sits well on a cream panel.
static func apply_to(theme: Theme) -> void:
	var spec: Dictionary = data().get("button", {})
	var normal := _button_box(spec.get("fill", "tan"), spec)
	var pressed := _button_box(spec.get("pressed_fill", "warm_wood"), spec)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color.a = 0.45
	disabled.border_color.a = 0.45
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	var text := color(spec.get("text", "dark_wood"))
	for key in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(key, "Button", text)
	for key in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(key, "Button", color(spec.get("pressed_text", "cream")))
	theme.set_color("font_disabled_color", "Button", Color(text, 0.5))
	var font := body_font()
	if font != null:
		theme.default_font = font


# The everyday font (fonts.body), or null for Godot's own.
static func body_font() -> Font:
	return _font("body")


# The round, chunky font for titles (fonts.title), or null for Godot's own.
static func title_font() -> Font:
	return _font("title")


# Puts the title font on a Label, Button or Label3D (the clock, a recipe's
# name, "Delicious!", a screen's heading).
static func title(node: Node) -> void:
	var font := title_font()
	if font == null:
		return
	if node is Label3D:
		(node as Label3D).font = font
	elif node is Control:
		(node as Control).add_theme_font_override("font", font)


static func _font(key: String) -> Font:
	var path: String = data().get("fonts", {}).get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Font


static func _button_box(fill: String, spec: Dictionary) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color(fill)
	box.border_color = color(spec.get("outline", "wood"))
	box.set_border_width_all(int(spec.get("outline_width", 3)))
	box.set_corner_radius_all(int(spec.get("corner_radius", 12)))
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
