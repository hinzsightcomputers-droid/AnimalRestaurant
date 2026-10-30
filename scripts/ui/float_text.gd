# FloatText: a word or two that pops up beside something in the world ("+2
# friendship", "+$24"), rises and fades away. Display only.
class_name FloatText
extends RefCounted

const RISE := 0.6
const SECONDS := 1.8


static func pop(parent: Node, at: Vector3, text: String, color: Color, font_size := 44) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", at.y + RISE, SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, SECONDS * 0.55).set_delay(SECONDS * 0.45)
	tween.tween_property(label, "outline_modulate:a", 0.0, SECONDS * 0.55).set_delay(SECONDS * 0.45)
	tween.chain().tween_callback(label.queue_free)
	return label
