# ChefFace: the chef's face, drawn by one shader (chef_face.gdshader) that
# layers the eyes, brows, nose, mouth and face paint from data/appearance.json
# on a 0..1 face canvas. Drawn on the head's "Face" surface if the head mesh
# has one (see docs/character_asset_spec.md), else on a face plate: a thin
# patch over the front of the stand-in head, its UVs laid out the same way.
# Blinks now and then, and set_expression() swaps in happy, surprised or sad
# eyes and mouth for a while. ChefModel owns it.
class_name ChefFace
extends Node

const SHADER := preload("res://assets/shaders/chef_face.gdshader")
const PAINT_LAYERS := 3
const PLATE_STEPS := 16  # Grid squares across the face plate.
const PLATE_LIFT := 1.012  # Just outside the head, so it doesn't flicker into it.

var material := ShaderMaterial.new()
var expression := ""  # "", or a key of data/appearance.json's face.expressions.

var _look: CharacterAppearance
var _expression_left := 0.0  # Seconds until it goes back to "" (0: stays).
var _blink_in := 0.0
var _blink_left := 0.0


func _init() -> void:
	material.shader = SHADER
	material.render_priority = 1  # Over the head, which is opaque anyway.


func _ready() -> void:
	var face := _face_data()
	for feature in ["eyes", "brows", "nose", "mouth"]:
		var layout: Dictionary = face.get("layout", {}).get(feature, {})
		var center: Array = layout.get("center", [])
		if center.size() == 2:
			material.set_shader_parameter(feature + "_center", Vector2(center[0], center[1]))
		if layout.has("size"):
			material.set_shader_parameter(feature + "_size", float(layout["size"]))
		if layout.has("spacing"):
			material.set_shader_parameter(feature + "_spacing", float(layout["spacing"]))
	_blink_in = _next_blink()


func _process(delta: float) -> void:
	if _expression_left > 0.0:
		_expression_left -= delta
		if _expression_left <= 0.0:
			set_expression("")
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_show_eyes()
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		blink()


# A face plate shaped to the stand-in head (an ellipsoid: `center`, `radii`),
# in the character's own space; its UVs are the face canvas.
static func make_plate(center: Vector3, radii: Vector3, plate_size: Vector2) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lifted := radii * PLATE_LIFT
	for row in PLATE_STEPS + 1:
		for column in PLATE_STEPS + 1:
			var uv := Vector2(float(column) / PLATE_STEPS, float(row) / PLATE_STEPS)
			# Across the front: u is the chef's right to left as we look at them.
			var flat := Vector2((uv.x - 0.5) * plate_size.x, (0.5 - uv.y) * plate_size.y)
			if flat.length() > 0.98:
				flat = flat.normalized() * 0.98  # The corners wrap onto the rim.
			var depth := sqrt(maxf(0.0, 1.0 - flat.length_squared()))
			var unit := Vector3(flat.x, flat.y, depth)
			tool.set_uv(uv)
			tool.set_normal((unit / radii).normalized())
			tool.add_vertex(center + unit * lifted)
	for row in PLATE_STEPS:
		for column in PLATE_STEPS:
			var i := row * (PLATE_STEPS + 1) + column
			var below := i + PLATE_STEPS + 1
			for corner in [i, i + 1, below, i + 1, below + 1, below]:  # Clockwise from the front.
				tool.add_index(corner)
	return tool.commit()


func apply(look: CharacterAppearance) -> void:
	_look = look
	material.set_shader_parameter("eye_color", look.eye_color)
	material.set_shader_parameter("brow_color", look.hair_color.darkened(0.15))
	for feature in ["eyes", "brows", "nose", "mouth"]:
		material.set_shader_parameter(feature + "_offset", look.feature_offset(feature))
		material.set_shader_parameter(feature + "_scale", look.feature_scale(feature))
	material.set_shader_parameter("brows_texture", _texture("brows", look.feature_id("brows")))
	material.set_shader_parameter("nose_texture", _texture("nose", look.feature_id("nose")))
	for layer in PAINT_LAYERS:
		var paint_id: String = look.face_paint[layer] if layer < look.face_paint.size() else ""
		material.set_shader_parameter("paint_%d" % (layer + 1), _texture("face_paint", paint_id))
	_show_eyes()
	_show_mouth()


# "happy", "surprised", "sad" (or "" for their own face), for `seconds` (0:
# until changed).
func set_expression(new_expression: String, seconds := 0.0) -> void:
	expression = new_expression
	_expression_left = seconds
	_show_eyes()
	_show_mouth()


func blink() -> void:
	_blink_in = _next_blink()
	if _expression_texture("eyes", "blink") == null:
		return
	_blink_left = float(_face_data().get("blink_seconds", 0.12))
	_show_eyes()


func is_blinking() -> bool:
	return _blink_left > 0.0


func _show_eyes() -> void:
	if _look == null:
		return
	var texture: Texture2D = null
	if is_blinking():
		texture = _expression_texture("eyes", "blink")
	elif not expression.is_empty():
		texture = _expression_texture("eyes", expression)
	material.set_shader_parameter("eyes_texture", texture if texture != null else _texture("eyes", _look.feature_id("eyes")))


func _show_mouth() -> void:
	if _look == null:
		return
	var texture: Texture2D = _expression_texture("mouth", expression) if not expression.is_empty() else null
	material.set_shader_parameter("mouth_texture", texture if texture != null else _texture("mouth", _look.feature_id("mouth")))


# The texture standing in for this chef's `kind` ("eyes"/"mouth") while
# showing `which` (an expression, or "blink"): the part's own "<which>_<kind>"
# if it has one, else the shared one; null if there's none.
func _expression_texture(kind: String, which: String) -> Texture2D:
	var own: String = Wardrobe.face_part(kind, _look.feature_id(kind)).get("%s_%s" % [which, kind], "") if _look != null else ""
	var path: String = own if not own.is_empty() else String(_face_data().get("expressions", {}).get(which, {}).get(kind, ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


static func _texture(kind: String, id: String) -> Texture2D:
	var path: String = Wardrobe.face_part(kind, id).get("texture", "")
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _next_blink() -> float:
	var every: Array = _face_data().get("blink_every", [2.0, 5.0])
	return randf_range(float(every[0]), float(every[1]))


static func _face_data() -> Dictionary:
	return Wardrobe.looks().get("face", {})
