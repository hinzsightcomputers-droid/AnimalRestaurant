# SauceSheet: a sauce poured over food on a plate: it heaps where it lands,
# spreads, levels, runs over the food's edge and down its side, and pools on the
# plate, as thick or runny as it is. A grid of depths over a rectangle (a thin
# layer of liquid flowing downhill from cell to cell), drawn by sauce.gdshader.
# pour() adds to it; it settles by itself and then stops.
class_name SauceSheet
extends Node3D

const SHADER := preload("res://assets/shaders/sauce.gdshader")
const CELLS := 80
const TICK := 1.0 / 30.0
const DRY := 0.00008          # Thinner than this it doesn't flow.
const WALL := 1.0e6           # Nothing flows here (off the plate).

# What each sauce is like. runny: how quickly it spreads (0..1). stiff: the step
# (m) between cells it'll hold without slumping. absorb, least, gloss, lumps: how
# it looks. light: what its color goes to where it's thin.
const KINDS := {
	"syrup": { "runny": 0.62, "stiff": 0.00012, "absorb": 420.0, "least": 0.62, "gloss": 1.0, "lumps": 0.0, "light": Color(0.86, 0.4, 0.05) },
	"chocolate": { "runny": 0.5, "stiff": 0.0004, "absorb": 1500.0, "least": 0.75, "gloss": 0.85, "lumps": 0.0, "light": null },
	"ketchup": { "runny": 0.14, "stiff": 0.0042, "absorb": 5000.0, "least": 0.97, "gloss": 0.9, "lumps": 0.0, "light": null },
	"cheese": { "runny": 0.5, "stiff": 0.0005, "absorb": 2200.0, "least": 0.85, "gloss": 0.7, "lumps": 0.0, "light": null },
	"butter": { "runny": 0.8, "stiff": 0.00005, "absorb": 500.0, "least": 0.45, "gloss": 1.0, "lumps": 0.0, "light": Color(1.0, 0.86, 0.4) },
	"foam": { "runny": 0.1, "stiff": 0.0035, "absorb": 3000.0, "least": 0.92, "gloss": 0.25, "lumps": 1.0, "light": null },
	"thin": { "runny": 1.0, "stiff": 0.0, "absorb": 260.0, "least": 0.3, "gloss": 1.0, "lumps": 0.0, "light": Color(0.96, 0.86, 0.4) },
}

var rect := Rect2()           # What it covers (x, z in the session).
var cell := 0.004
var _base := PackedFloat32Array()    # What's under it (m over this node).
var _depth := PackedFloat32Array()
var _give := PackedFloat32Array()    # How easily it flows in each cell: not quite even, so its front runs in fingers.
var _pixels := PackedFloat32Array()  # base, depth, base, depth...
var _wet := {}                       # Cells with any sauce in them.
var _image: Image
var _texture: ImageTexture
var _look := ShaderMaterial.new()
var _runny := 0.9
var _stiff := 0.0
var _left_over := 0.0
var _still := 0.0
var _under: Callable
var _calm := false


# Over `on` (session coordinates), lying on whatever `under` says is there:
# under.call(Vector2) -> its height in the session, or INF where nothing can flow.
static func make(session: Node3D, on: Rect2, height: float, kind: String, color: Color, under: Callable) -> SauceSheet:
	var sheet := SauceSheet.new()
	sheet.rect = on
	sheet.cell = on.size.x / CELLS
	sheet._under = under
	sheet.position = Vector3(on.get_center().x, height, on.get_center().y)
	var like: Dictionary = KINDS.get(kind, KINDS["syrup"])
	sheet._runny = like["runny"]
	sheet._stiff = like["stiff"]
	sheet._look.shader = SHADER
	sheet._look.render_priority = 1
	var light: Color = like["light"] if like["light"] is Color else color.lightened(0.12)
	for pair in [["cells", float(CELLS)], ["size", on.size], ["sauce", color], ["thin_color", light], ["absorb", like["absorb"]], ["least_alpha", like["least"]], ["gloss", like["gloss"]], ["lumps", like["lumps"]]]:
		sheet._look.set_shader_parameter(pair[0], pair[1])
	session.add_child(sheet)
	return sheet


func _ready() -> void:
	var total := CELLS * CELLS
	_base.resize(total)
	_depth.resize(total)
	_give.resize(total)
	_pixels.resize(total * 2)
	for i in total:
		_give[i] = randf_range(0.55, 1.0)
	_image = Image.create_empty(CELLS, CELLS, false, Image.FORMAT_RGF)
	refresh_base()
	_texture = ImageTexture.create_from_image(_image)
	_look.set_shader_parameter("heights", _texture)
	var net := PlaneMesh.new()
	net.size = rect.size
	net.subdivide_width = CELLS - 1
	net.subdivide_depth = CELLS - 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = net
	mesh.material_override = _look
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.custom_aabb = AABB(Vector3(-rect.size.x * 0.5, -0.05, -rect.size.y * 0.5), Vector3(rect.size.x, 0.25, rect.size.y))
	add_child(mesh)


func look_under(under: Callable) -> void:
	_under = under
	refresh_base()


# Look again at what's under it (a pat of butter melting).
func refresh_base() -> void:
	for z in CELLS:
		for x in CELLS:
			var i := z * CELLS + x
			var under: float = _under.call(_point(x, z))
			_base[i] = WALL if under == INF else under - position.y
			_pixels[i * 2] = 0.0 if under == INF else _base[i]
	for z in range(1, CELLS - 1):  # (Where nothing flows is drawn as high as what's beside it, so the sauce doesn't dip there.)
		for x in range(1, CELLS - 1):
			var i := z * CELLS + x
			if _base[i] < WALL:
				continue
			for j in [i - 1, i + 1, i - CELLS, i + CELLS]:
				if _base[j] < WALL:
					_pixels[i * 2] = _base[j]
	_calm = false
	_upload()


# `amount` (m³) lands round `point`, over a circle `spread` in radius.
func pour(point: Vector2, amount: float, spread: float) -> void:
	var middle := (point - rect.position) / cell
	var reach := ceili(spread / cell) + 1
	var cells: Array[int] = []
	var shares: Array[float] = []
	var total := 0.0
	for z in range(maxi(int(middle.y) - reach, 0), mini(int(middle.y) + reach + 1, CELLS)):
		for x in range(maxi(int(middle.x) - reach, 0), mini(int(middle.x) + reach + 1, CELLS)):
			var i := z * CELLS + x
			if _base[i] >= WALL:
				continue
			var gap := Vector2(x + 0.5 - middle.x, z + 0.5 - middle.y).length() * cell / spread
			if gap >= 1.0:
				continue
			var share := (1.0 - gap * gap) * (1.0 - gap * gap)
			cells.append(i)
			shares.append(share)
			total += share
	for n in cells.size():
		_depth[cells[n]] += amount / (cell * cell) * shares[n] / total
		_wet[cells[n]] = true
	_still = 0.0
	_calm = false


# How deep it is at a point (m).
func depth_at(point: Vector2) -> float:
	var at := (point - rect.position) / cell
	var x := int(at.x)
	var z := int(at.y)
	if x < 0 or z < 0 or x >= CELLS or z >= CELLS:
		return 0.0
	return _depth[z * CELLS + x]


# Its top at a point, in the session (m).
func top_at(point: Vector2) -> float:
	var at := ((point - rect.position) / cell).clamp(Vector2.ZERO, Vector2.ONE * (CELLS - 1))
	var i := int(at.y) * CELLS + int(at.x)
	return position.y + (_base[i] if _base[i] < WALL else 0.0) + _depth[i]


func _process(delta: float) -> void:
	if _calm:
		return
	_left_over += minf(delta, 0.1)
	if _left_over < TICK:
		return
	_left_over = fmod(_left_over, TICK)
	var moved := _flow()
	_upload()
	_still = _still + TICK if moved < 2.0e-5 else 0.0
	if _still > 1.0:
		_calm = true


# One step: each wet cell gives some of what's in it to its lower neighbors, more
# the deeper it is (a thin film hardly moves). Returns how much moved (m, summed).
func _flow() -> float:
	var give := PackedFloat32Array()
	var to := PackedInt32Array()
	var moved := 0.0
	var last := CELLS - 1
	var rate := 0.21 * _runny
	for i: int in _wet:
		var h := _depth[i]
		if h < DRY:
			continue
		var x := i % CELLS
		@warning_ignore("integer_division")
		var z := i / CELLS
		var top := _base[i] + h - _stiff
		var ease_in := minf(h / 0.0028, 1.0)
		var flow_rate := rate * ease_in * ease_in * _give[i]
		var most := h * 0.22
		for way in 4:
			var j := i
			if way == 0:
				if x == 0:
					continue
				j = i - 1
			elif way == 1:
				if x == last:
					continue
				j = i + 1
			elif way == 2:
				if z == 0:
					continue
				j = i - CELLS
			else:
				if z == last:
					continue
				j = i + CELLS
			var drop := top - _base[j] - _depth[j]
			if drop > 0.0:
				give.append(minf(minf(drop, 0.012) * flow_rate, most))
				to.append(i)
				to.append(j)
	for n in give.size():
		var q := give[n]
		_depth[to[n * 2]] -= q
		var j := to[n * 2 + 1]
		_depth[j] += q
		_wet[j] = true
		moved += q
	return moved


func _upload() -> void:
	for i: int in _wet:
		_pixels[i * 2 + 1] = _depth[i]
	_image.set_data(CELLS, CELLS, false, Image.FORMAT_RGF, _pixels.to_byte_array())
	if _texture != null:
		_texture.update(_image)


func _point(x: int, z: int) -> Vector2:
	return rect.position + Vector2(x + 0.5, z + 0.5) * cell
