extends Node

# Chopping judged against when the tick is heard: a player who always presses
# right on the sound, with different audio delays, should end up perfect.
#   godot --headless res://tools/chop_timing_check.tscn

func _ready() -> void:
	var ok := true
	for delay in [0.0, 0.05, 0.12, 0.25]:
		ChopAction._heard_after = -1.0
		var chop := ChopAction.new()
		var words := []
		for i in 16:
			chop._tick_at = i * chop.beat_seconds
			chop._time = chop._tick_at + delay + randf_range(-0.015, 0.015)
			var off: float = chop._off_beat()
			var on_beat: float = 1.0 - clampf((off - chop.perfect_seconds) / (chop.beat_tolerance - chop.perfect_seconds), 0.0, 1.0)
			words.append("P" if on_beat >= 0.9 else ("o" if on_beat >= 0.7 else ("n" if on_beat >= 0.45 else "x")))
		var last := "".join(words.slice(8))
		var passed := last == "PPPPPPPP"
		ok = ok and passed
		print("CHOP %s delay %.2f s: %s (learned %.3f s)" % ["ok  " if passed else "FAIL", delay, "".join(words), ChopAction._heard_after])
	print("CHOP ", "ALL OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)
