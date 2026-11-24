# DishIcons: small pictures for the order tickets: each dish, taken of its served
# model (data/dish_kitchen.json) on a plate, and each customer's face, taken of
# their model. Each is drawn once,
# the first time it's asked for, in a little world of its own off screen; until
# it's ready (or with nothing to draw with) the ticket goes without.
class_name DishIcons
extends Node

signal ready_to_show

const PIXELS := 160
const PLATE := "res://design/restaurant/plate.glb"
const PLATE_WIDTH := 0.44
const FACE_HEIGHT := 1.0   # A customer is stood this tall...
const FACE_SHARE := 0.5    # ...and this much of them, from the top, is in the picture.

static var _icons := {}  # Dish id, or a customer's model path -> Texture2D.

var _waiting: Array[Dictionary] = []
var _sitters := {}  # Portrait key -> whose picture it is.
var _viewport: SubViewport = null
var _camera := Camera3D.new()
var _busy := false


func _exit_tree() -> void:
	if _camera.get_parent() == null:
		_camera.queue_free()


# The dish's picture, or null till it's been drawn (ready_to_show then).
func icon(dish: Dictionary) -> Texture2D:
	return _get_or_draw(String(dish.get("id", "")), dish)


# This customer's face, the same way (a placeholder's, from its shapes).
func face(display: CustomerDisplay) -> Texture2D:
	var key := display.portrait_key()
	if not _icons.has(key):
		_sitters[key] = display
	return _get_or_draw(key, {})


func _get_or_draw(key: String, dish: Dictionary) -> Texture2D:
	if _icons.has(key):
		return _icons[key]
	if DisplayServer.get_name() != "headless" and not _waiting.any(func(w): return w["key"] == key) and not key.is_empty():
		_waiting.append({ "key": key, "dish": dish })
		_draw_next()
	return null


func _draw_next() -> void:
	if _busy or _waiting.is_empty():
		return
	_busy = true
	if _viewport == null:
		_build()
	var key: String = _waiting[0]["key"]
	var dish: Dictionary = _waiting[0]["dish"]
	var holder := Node3D.new()
	_viewport.add_child(holder)
	if dish.is_empty():
		_set_face(key, holder)
	else:
		_set_dish(dish, holder)
	ToonStyle.apply_bare(holder)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for i in 2:  # Asked for in one frame, drawn in the next.
		await RenderingServer.frame_post_draw
		if not is_inside_tree():
			return
	var image := _viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.generate_mipmaps()
		if holder.get_child_count() > 0:  # (Gone before their picture was taken.)
			_icons[key] = ImageTexture.create_from_image(image)
	holder.queue_free()
	_waiting.pop_front()
	_busy = false
	ready_to_show.emit()
	_draw_next()


func _set_dish(dish: Dictionary, holder: Node3D) -> void:
	var plate := ModelFit.place(PLATE, holder, Vector3.ZERO, Vector3(PLATE_WIDTH, 0.046, PLATE_WIDTH))
	if plate != null:
		plate.stretch = true
	var width := PLATE_WIDTH * 0.75
	ModelFit.place(String(dish.get("model", "")), holder, Vector3(0.0, 0.03, 0.0), Vector3(width, 0.0, width))
	_camera.size = PLATE_WIDTH * 1.12
	_camera.look_at_from_position(Vector3(0.0, 0.85, 0.75), Vector3(0.0, 0.05, 0.0))


func _set_face(path: String, holder: Node3D) -> void:
	var model: Node3D = _sitters[path].portrait() if is_instance_valid(_sitters.get(path)) else null
	_sitters.erase(path)
	if model == null:
		return
	holder.add_child(model)
	var box := CustomerDisplay.bounds(model)
	if box.size.y > 0.0:
		model.scale = Vector3.ONE * FACE_HEIGHT / box.size.y
	var middle := FACE_HEIGHT * (1.0 - FACE_SHARE * 0.5)
	_camera.size = FACE_HEIGHT * FACE_SHARE * 1.06
	_camera.look_at_from_position(Vector3(0.0, middle + 0.1, 3.0), Vector3(0.0, middle, 0.0))


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i.ONE * PIXELS
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var camera := _camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(camera)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_CLEAR_COLOR
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color("fff4e4")
	camera.environment.ambient_light_energy = 0.55
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_color = Color("fff1dc")
	_viewport.add_child(sun)
