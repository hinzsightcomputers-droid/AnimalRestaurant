# EventBanner: a simple banner across the top of the screen for a special day
# (see EventCalendar), e.g. "Happy Halloween!". Fades in, stays for
# banner_seconds (design/calendar/calendar.json), fades out and goes away.
# Shows even while the game is paused (e.g. closed until tomorrow).
class_name EventBanner
extends CanvasLayer

const FADE_SECONDS := 0.6


# Show today's banner (one line per event), if there's anything today.
static func show_today(host: Node) -> void:
	var lines: Array = EventCalendar.events_on(GameClock.calendar_date()).map(func(e): return e["banner"])
	if not lines.is_empty():
		show_text(host, "\n".join(PackedStringArray(lines)))


static func show_text(host: Node, text: String) -> void:
	var banner := EventBanner.new()
	host.add_child(banner)
	banner._show(text)


func _show(text: String) -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 120  # Below the clock.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.9, 0.96)
	style.border_color = Color(0.55, 0.4, 0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.4, 0.26, 0.16))
	panel.add_child(label)
	add_child(panel)

	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(float(EventCalendar.data().get("banner_seconds", 6)))
	tween.tween_property(panel, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)
