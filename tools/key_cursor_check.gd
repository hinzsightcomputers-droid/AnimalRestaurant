extends Node

# How far the keys move the cooking cursor: a one-frame tap should aim to a
# few millimeters, a long hold should still cross the board quickly.
#   godot --headless res://tools/key_cursor_check.tscn

func _ready() -> void:
	var input := CookInput.new(CookSession.new(), 0, null)
	var frame := 1.0 / 60.0
	var tap := input._cursor_speed(Vector2.RIGHT) * frame
	var travelled := 0.0
	var crossed_at := -1.0
	for i in 120:
		input._key_move_time += frame
		travelled += input._cursor_speed(Vector2.RIGHT) * frame
		if crossed_at < 0.0 and travelled >= 0.3:
			crossed_at = (i + 1) * frame
	var ok := tap < 0.003 and crossed_at > 0.0 and crossed_at < 1.0
	print("KEYS %s tap %.1f mm, 30 cm board crossed in %.2f s, %.0f cm in 2 s" % ["ok" if ok else "FAIL", tap * 1000.0, crossed_at, travelled * 100.0])
	input._session.free()
	get_tree().quit(0 if ok else 1)
