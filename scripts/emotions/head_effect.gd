class_name HeadEffect
extends Sprite3D
## A small billboarded icon that pops up around a character's head, then removes itself.
## You normally don't use this directly: EmotionPlayer spawns it for you.


static func spawn(parent: Node, tex: Texture2D, style: StringName, origin: Vector3,
		index: int = 0, count: int = 1, size: float = 0.45) -> HeadEffect:
	var fx := HeadEffect.new()
	fx.texture = tex
	fx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fx.shaded = false
	fx.transparent = true
	fx.double_sided = true
	fx.no_depth_test = true
	fx.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fx.pixel_size = size / maxf(float(tex.get_width()), 1.0)
	parent.add_child(fx)
	fx.global_position = origin
	fx._run(String(style), index, count)
	return fx


func _camera_axes() -> Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return [Vector3.RIGHT, Vector3.UP]
	var b := cam.global_transform.basis
	return [b.x.normalized(), b.y.normalized()]


func _run(style: String, index: int, count: int) -> void:
	var start := global_position
	var axes := _camera_axes()
	var right: Vector3 = axes[0]
	var up: Vector3 = axes[1]
	var spread := (float(index) - float(count - 1) * 0.5) * 0.3
	var delay := float(index) * 0.1

	scale = Vector3.ZERO
	var tw := create_tween()
	tw.finished.connect(queue_free)
	if delay > 0.0:
		tw.tween_interval(delay)

	match style:
		"float_up":
			var from := start + right * spread + up * randf_range(0.0, 0.1)
			global_position = from
			tw.tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "global_position", from + up * 0.75, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(1.0)
		"burst":
			var angle := TAU * float(index) / float(maxi(count, 1)) + randf_range(-0.25, 0.25) + PI * 0.5
			var dir := (right * cos(angle) + up * sin(angle)).normalized()
			global_position = start + dir * 0.12
			tw.tween_property(self, "scale", Vector3.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "global_position", start + dir * 0.8, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.35)
		"drop":
			var from := start + right * spread + up * 0.2
			global_position = from
			tw.tween_property(self, "scale", Vector3.ONE, 0.15)
			tw.parallel().tween_property(self, "global_position:y", from.y - 0.7, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.75)
		"pop":
			global_position = start + up * 0.15
			tw.tween_property(self, "scale", Vector3.ONE * 1.25, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "scale", Vector3.ONE, 0.1)
			tw.parallel().tween_property(self, "global_position", start + up * 0.3, 1.2)
			tw.tween_property(self, "modulate:a", 0.0, 0.3)
		_:
			tw.kill()
			queue_free()
