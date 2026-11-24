# DrinkMachine: how a drink machine looks: a row of taps, each with its drink's
# badge over it, a button that goes in as it pours, and a tray to stand the
# glass on. A pop fountain (water, pop and everything cold) or a brewer
# (everything hot, with a bowl of mini marshmallows beside it). DrinkStation
# works it; this only builds and shows it. Its origin is the middle of the
# counter's top, its front toward +z.
class_name DrinkMachine
extends Node3D

const DEPTH := 0.34
const COUNTER_Z := -0.14       # The body's middle: the back of the counter.
const HEAD_BOTTOM := 0.31      # Over the counter: the overhang the taps hang from...
const HEAD_HEIGHT := 0.27      # ...and how tall it is.
const TAP_Z := 0.1             # The taps, and the glass under them.
const TAP_TIP := 0.265
const TRAY_TOP := 0.028        # What the glass stands on.
const CREAM := Color("#FBE6C4")
const RED := Color("#C8432F")
const BROWN := Color("#6A3B22")
const COPPER := Color("#C9793F")
const DARK := Color("#4A2A1C")

var taps: Array[Vector3] = []   # Where each drink comes out, in this node's space.

var _badges: Array[MeshInstance3D] = []
var _names: Array[Label3D] = []
var _buttons: Array[MeshInstance3D] = []
var _stream: MeshInstance3D
var _bowl: Node3D = null
var _shown := ""
var _paints: Array[StandardMaterial3D] = []


# Show these drinks' taps, `width` across. (Built again only when they change.)
func show_drinks(drinks: Array, width: float, hot: bool) -> void:
	var key := ",".join(drinks.map(func(d): return String(d["id"])))
	if key == _shown:
		return
	_shown = key
	for child in get_children():
		child.queue_free()
	taps.clear()
	_badges.clear()
	_names.clear()
	_buttons.clear()
	_paints.clear()
	_bowl = null
	_build_body(width, hot)
	var row := width - 0.1 - (0.24 if hot else 0.0)  # The marshmallow bowl's on the right of the brewer.
	var middle := -0.12 if hot else 0.0
	var step := minf(0.2, row / maxi(drinks.size(), 1))
	for i in drinks.size():
		_build_tap(drinks[i], middle + (i - (drinks.size() - 1) * 0.5) * step, step, hot)
	if hot:
		_build_bowl(Vector3(width * 0.5 - 0.13, 0.0, TAP_Z))
	_stream = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.007
	mesh.bottom_radius = 0.0055
	mesh.height = 1.0
	mesh.radial_segments = 12
	_stream.mesh = mesh
	_stream.visible = false
	add_child(_stream)


# Light up tap `index` (-1: none).
func pick(index: int) -> void:
	for i in _badges.size():
		var on := i == index
		_paints[i].emission_energy_multiplier = 0.55 if on else 0.0
		_badges[i].scale = Vector3.ONE * (1.12 if on else 1.0)
		_names[i].modulate = Color.WHITE if on else Color(1.0, 1.0, 1.0, 0.85)
		_names[i].position.z = _badges[i].position.z + (0.012 if on else 0.01)


# The stream from tap `index` down to `bottom`, or none, and its button in.
func pour(index: int, color: Color, bottom: float, on: bool) -> void:
	if _stream == null:
		return
	_stream.visible = on
	for i in _buttons.size():
		_buttons[i].position.z = _buttons[i].get_meta("out") - (0.012 if on and i == index else 0.0)
	if not on:
		return
	var top := taps[index]
	var paint := _stream.material_override as StandardMaterial3D
	if paint == null:
		paint = StandardMaterial3D.new()
		paint.roughness = 0.15
		_stream.material_override = paint
	paint.albedo_color = color
	var sway := sin(Time.get_ticks_msec() * 0.03) * 0.0008
	_stream.position = Vector3(top.x + sway, (top.y + bottom) * 0.5, top.z)
	var thick := 1.0 + sin(Time.get_ticks_msec() * 0.021) * 0.12
	_stream.scale = Vector3(thick, maxf(top.y - bottom, 0.005), thick)


# Where a hand takes marshmallows from (in this node's space).
func bowl_at() -> Vector3:
	return _bowl.position if _bowl != null else Vector3.ZERO


func _build_body(width: float, hot: bool) -> void:
	var body := _paint(BROWN if hot else RED)
	var trim := _paint(COPPER if hot else CREAM)
	_box(Vector3(width, HEAD_BOTTOM + HEAD_HEIGHT, DEPTH * 0.55), Vector3(0.0, (HEAD_BOTTOM + HEAD_HEIGHT) * 0.5, COUNTER_Z - 0.06), body)
	_box(Vector3(width, HEAD_HEIGHT, DEPTH), Vector3(0.0, HEAD_BOTTOM + HEAD_HEIGHT * 0.5, COUNTER_Z + 0.04), body)
	_box(Vector3(width * 1.02, 0.035, DEPTH + 0.02), Vector3(0.0, HEAD_BOTTOM + HEAD_HEIGHT + 0.01, COUNTER_Z + 0.04), trim)
	_box(Vector3(width * 1.005, 0.018, DEPTH + 0.012), Vector3(0.0, HEAD_BOTTOM, COUNTER_Z + 0.04), trim)
	if hot:  # Two copper domes on top, like an old espresso machine.
		for side in [-1.0, 1.0]:
			var dome := SphereMesh.new()
			dome.radius = 0.085
			dome.height = 0.14
			_mesh(dome, Vector3(side * width * 0.22, HEAD_BOTTOM + HEAD_HEIGHT + 0.03, COUNTER_Z), trim)
	else:  # A rounded sign.
		_box(Vector3(width * 0.5, 0.12, 0.05), Vector3(0.0, HEAD_BOTTOM + HEAD_HEIGHT + 0.08, COUNTER_Z + 0.08), trim)
		var sign_text := _text("DRINKS", 0.0011, 64)
		sign_text.position = Vector3(0.0, HEAD_BOTTOM + HEAD_HEIGHT + 0.08, COUNTER_Z + 0.108)
		sign_text.modulate = RED
		sign_text.outline_modulate = CREAM
		add_child(sign_text)
	var steel := KitchenProps.steel()
	_box(Vector3(width * 0.96, TRAY_TOP - 0.006, 0.2), Vector3(0.0, (TRAY_TOP - 0.006) * 0.5, TAP_Z), steel)
	var slot := _paint(Color(0.2, 0.18, 0.17))
	var slots := roundi(width * 0.9 / 0.035)
	for i in slots:  # The drip tray's slots.
		_box(Vector3(0.012, 0.002, 0.16), Vector3((i - (slots - 1) * 0.5) * 0.035, TRAY_TOP - 0.006, TAP_Z), slot)


func _build_tap(drink: Dictionary, x: float, step: float, hot: bool) -> void:
	var color := Color(drink.get("color", "#888888"))
	var front := COUNTER_Z + 0.04 + DEPTH * 0.5
	var wide := minf(step * 0.9, 0.17)
	var paint := _paint(color if color.get_luminance() < 0.75 else color.darkened(0.12))
	paint.emission_enabled = true
	paint.emission = paint.albedo_color
	paint.emission_energy_multiplier = 0.0
	_paints.append(paint)
	_box(Vector3(wide + 0.014, 0.15, 0.012), Vector3(x, HEAD_BOTTOM + HEAD_HEIGHT * 0.63, front + 0.006), _paint(CREAM))
	var badge := _box(Vector3(wide, 0.13, 0.016), Vector3(x, HEAD_BOTTOM + HEAD_HEIGHT * 0.63, front + 0.008), paint)
	_badges.append(badge)
	var words := String(drink.get("name", "?")).replace(" ", "\n").replace("-", "-\n")
	var longest := 1
	for word in words.split("\n"):
		longest = maxi(longest, word.length())
	var lettering := _text(words, minf(0.00085, wide * 0.95 / (longest * 25.0)), 48)
	lettering.position = Vector3(x, badge.position.y, badge.position.z + 0.01)
	_names.append(lettering)
	add_child(lettering)
	var round_button := CylinderMesh.new()  # The button.
	round_button.top_radius = minf(wide * 0.28, 0.024)
	round_button.bottom_radius = round_button.top_radius
	round_button.height = 0.026
	var button := _mesh(round_button, Vector3(x, HEAD_BOTTOM + 0.062, front + 0.012), _paint(Color("#FFD15C")))
	button.rotation.x = PI * 0.5
	button.set_meta("out", button.position.z)
	_buttons.append(button)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.02
	spout.bottom_radius = 0.012
	spout.height = HEAD_BOTTOM - TAP_TIP
	_mesh(spout, Vector3(x, (HEAD_BOTTOM + TAP_TIP) * 0.5, TAP_Z), KitchenProps.steel() if not hot else _paint(COPPER))
	taps.append(Vector3(x, TAP_TIP, TAP_Z))


# A little bowl heaped with mini marshmallows.
func _build_bowl(at: Vector3) -> void:
	_bowl = Node3D.new()
	_bowl.position = at
	add_child(_bowl)
	var shell := CylinderMesh.new()
	shell.top_radius = 0.085
	shell.bottom_radius = 0.05
	shell.height = 0.06
	var bowl := MeshInstance3D.new()
	bowl.mesh = shell
	bowl.material_override = _paint(CREAM)
	bowl.position.y = 0.03
	_bowl.add_child(bowl)
	var white := _paint(Color(1.0, 0.97, 0.94))
	var pink := _paint(Color(1.0, 0.82, 0.86))
	var bit := CapsuleMesh.new()
	bit.radius = 0.012
	bit.height = 0.03
	bit.radial_segments = 10
	bit.rings = 3
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	for i in 34:
		var one := MeshInstance3D.new()
		one.mesh = bit
		one.material_override = pink if i % 4 == 0 else white
		var out := sqrt(dice.randf()) * 0.07
		var angle := dice.randf() * TAU
		one.position = Vector3(cos(angle) * out, 0.058 + (0.07 - out) * 0.4 * dice.randf(), sin(angle) * out)
		one.rotation = Vector3(dice.randf() * TAU, dice.randf() * TAU, 0.0)
		_bowl.add_child(one)


func _text(words: String, pixel: float, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.pixel_size = pixel
	label.font_size = font_size
	label.outline_size = 14
	label.outline_modulate = Color(0.22, 0.1, 0.05)
	label.line_spacing = -10.0
	var font := UiStyle.title_font()
	if font != null:
		label.font = font
	return label


func _paint(color: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.55
	return paint


func _box(size: Vector3, at: Vector3, paint: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, at, paint)


func _mesh(mesh: Mesh, at: Vector3, paint: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = paint
	node.position = at
	add_child(node)
	return node
