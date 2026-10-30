# FishingMeter: a bar on the fisher's own view, sized by its share of the view
# so it shrinks with split screen. Vertical (the reel's tension, with its safe
# band and a marker) or horizontal (the cast's power, how far in the fish is).
# Values are 0-1. Display only.
class_name FishingMeter
extends Control

const BACK := Color(0.12, 0.09, 0.07, 0.75)
const FILL := Color(0.98, 0.85, 0.45)
const BAND := Color(0.35, 0.75, 0.4, 0.85)
const MARKER := Color(1.0, 1.0, 1.0)
const DANGER := Color(0.95, 0.35, 0.3)

var vertical := false
var _band := ColorRect.new()
var _fill := ColorRect.new()
var _marker := ColorRect.new()
var _label := Label.new()


# A meter on `parent` (a CookSession.overlay()), filling the given share of it:
# left, top, right, bottom as 0-1 of the view.
static func make(parent: Control, area: Rect2, is_vertical: bool, caption := "") -> FishingMeter:
	var meter := FishingMeter.new()
	meter.vertical = is_vertical
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(meter)
	meter.anchor_left = area.position.x
	meter.anchor_top = area.position.y
	meter.anchor_right = area.end.x
	meter.anchor_bottom = area.end.y
	meter.offset_left = 0.0
	meter.offset_top = 0.0
	meter.offset_right = 0.0
	meter.offset_bottom = 0.0
	meter._build(caption)
	return meter


func _build(caption: String) -> void:
	var back := ColorRect.new()
	back.color = BACK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for part in [_band, _fill, _marker]:
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(part)
	_band.color = BAND
	_band.visible = false
	_fill.color = FILL
	_marker.color = MARKER
	_marker.visible = false
	_label.text = caption
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color(0.2, 0.13, 0.08))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP if not vertical else Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN if not vertical else Control.GROW_DIRECTION_END
	set_fill(0.0)


# How full: from the bottom (vertical) or the left.
func set_fill(value: float, color := FILL) -> void:
	_fill.color = color
	_span(_fill, 0.0, clampf(value, 0.0, 1.0))


# The safe band, from `low` to `high`.
func set_band(low: float, high: float) -> void:
	_band.visible = true
	_span(_band, low, high)


# A thin line at `value` (e.g. the tension), red when it's out of the band.
func set_marker(value: float, danger := false) -> void:
	_marker.visible = true
	_marker.color = DANGER if danger else MARKER
	var at := clampf(value, 0.0, 1.0)
	_span(_marker, at, at)
	if vertical:
		_marker.offset_top = -3.0
		_marker.offset_bottom = 3.0
	else:
		_marker.offset_left = -3.0
		_marker.offset_right = 3.0


func set_caption(text: String) -> void:
	_label.text = text


# Part of the bar from `from` to `to` along its length (0 = bottom or left).
func _span(part: Control, from: float, to: float) -> void:
	if vertical:
		part.anchor_left = 0.0
		part.anchor_right = 1.0
		part.anchor_top = 1.0 - to
		part.anchor_bottom = 1.0 - from
	else:
		part.anchor_top = 0.0
		part.anchor_bottom = 1.0
		part.anchor_left = from
		part.anchor_right = to
	part.offset_left = 0.0
	part.offset_right = 0.0
	part.offset_top = 0.0
	part.offset_bottom = 0.0
