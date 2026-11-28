# Fireplace: a stone fireplace for the dining room, like the concept art's:
# rounded stones up a chimney breast to the top of the wall, a fire of logs
# crackling in its opening (flickering flames and a warm light, brighter once
# it's dark outside), a wooden mantel with candles, a jar and a little plant,
# a stone hearth, and a stack of logs beside it. Pure looks, but solid. Its
# back stands on this node's spot against the wall, and it faces +z. Built
# from simple shapes (merged, as CottageDressing's); the flames move, so they
# stay apart.
class_name Fireplace
extends Node3D

const WIDTH := 1.4
const DEPTH := 0.42
const TALL := 3.0
const OPENING := Vector2(0.84, 0.72)  # The firebox's width and height.
const MANTEL_HEIGHT := 1.05  # Under the wall phone beside it.
const STONES := [Color("CDBCA4"), Color("BBA990"), Color("D9CAB3"), Color("A99A84"), Color("C4AE94")]
const MORTAR := Color("8F8070")
const SOOT := Color("2A1C16")
const WOOD := Color("8A5A3C")
const DARK_WOOD := Color("5E3B28")
const LOG := Color("7A4E32")
const EMBER := Color("FF8A3A")
const FLAME_COLORS := [Color("FF7A2A"), Color("FFB347"), Color("FFE08A")]
const LIGHT_DAY := 0.7     # The fire's light by day...
const LIGHT_NIGHT := 1.6   # ...and once it's dark (DayManager.indoor_darkness).

var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	var shapes := Node3D.new()
	shapes.name = "Shapes"
	add_child(shapes)
	_build_breast(shapes)
	_build_mantel(shapes)
	_build_fire_bed(shapes)
	_build_log_stack(shapes)
	MeshMerge.merge(shapes)
	_build_flames()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH + 0.3, 1.4, DEPTH + 0.4)  # Not the log stack: the wall phone is just beside it.
	shape.shape = box
	shape.position = Vector3(0.0, 0.7, (DEPTH + 0.4) / 2.0)
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
	_time += delta
	for i in _flames.size():
		var flame := _flames[i]
		var wobble := sin(_time * (7.0 + i * 1.7) + i * 2.1) * 0.5 + sin(_time * (11.0 + i * 2.3)) * 0.5
		flame.scale = Vector3(1.0 + wobble * 0.08, 1.0 + wobble * 0.22, 1.0 + wobble * 0.08)
		flame.rotation.z = sin(_time * (3.0 + i) + i) * 0.12
	var flicker := 1.0 + sin(_time * 9.0) * 0.06 + sin(_time * 23.0) * 0.04
	_light.light_energy = lerpf(LIGHT_DAY, LIGHT_NIGHT, DayManager.indoor_darkness) * flicker


# The chimney breast: two stone pillars either side of the opening and stone
# all the way up, with a sooty firebox behind the opening.
func _build_breast(at: Node3D) -> void:
	var side := (WIDTH - OPENING.x) / 2.0
	for side_sign in [-1.0, 1.0]:
		CottageDressing._box(at, Vector3(side_sign * (OPENING.x + side) / 2.0, OPENING.y / 2.0, DEPTH / 2.0), Vector3(side, OPENING.y, DEPTH), MORTAR)
	CottageDressing._box(at, Vector3(0, (TALL + OPENING.y) / 2.0, DEPTH / 2.0), Vector3(WIDTH, TALL - OPENING.y, DEPTH), MORTAR)
	CottageDressing._box(at, Vector3(0, OPENING.y / 2.0, 0.03), Vector3(OPENING.x, OPENING.y, 0.06), SOOT)  # The firebox's back...
	for side_sign in [-1.0, 1.0]:  # ...and sides.
		CottageDressing._box(at, Vector3(side_sign * (OPENING.x / 2.0 - 0.02), OPENING.y / 2.0, DEPTH / 2.0), Vector3(0.04, OPENING.y, DEPTH - 0.02), SOOT)
	CottageDressing._box(at, Vector3(0, OPENING.y - 0.02, DEPTH / 2.0), Vector3(OPENING.x, 0.04, DEPTH - 0.02), SOOT)
	# Rounded stones over the front, in rows, not over the opening or the mantel.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var row := 0
	var y := 0.0
	while y < TALL - 0.05:
		var tall := rng.randf_range(0.16, 0.24)
		var x := -WIDTH / 2.0 - (0.08 if row % 2 == 1 else 0.0)
		while x < WIDTH / 2.0:
			var wide := minf(rng.randf_range(0.18, 0.32), WIDTH / 2.0 - x)
			var middle := Vector2(x + wide / 2.0, y + tall / 2.0)
			var in_opening := absf(middle.x) < OPENING.x / 2.0 + 0.02 and middle.y < OPENING.y
			var at_mantel := absf(middle.y - MANTEL_HEIGHT) < 0.1
			if wide > 0.08 and not in_opening and not at_mantel:
				var stone := CottageDressing._ball(at, Vector3(maxf(middle.x, -WIDTH / 2.0 + 0.05), middle.y, DEPTH), 0.5, STONES[rng.randi() % STONES.size()])
				stone.scale = Vector3(wide - 0.03, tall - 0.03, 0.07)
			x += wide
		y += tall
		row += 1
	# A row of bigger, paler stones arching over the opening.
	for i in 5:
		var t := (i + 0.5) / 5.0
		var stone := CottageDressing._ball(at, Vector3(-OPENING.x / 2.0 - 0.06 + t * (OPENING.x + 0.12), OPENING.y + 0.06 + sin(t * PI) * 0.05, DEPTH + 0.01), 0.5, Color("DCCDB6"))
		stone.scale = Vector3(0.2, 0.17, 0.08)


func _build_mantel(at: Node3D) -> void:
	CottageDressing._box(at, Vector3(0, MANTEL_HEIGHT, DEPTH + 0.1), Vector3(WIDTH + 0.15, 0.12, 0.3), WOOD)
	for side_sign in [-1.0, 1.0]:  # Corbels under it.
		CottageDressing._box(at, Vector3(side_sign * (WIDTH / 2.0 - 0.05), MANTEL_HEIGHT - 0.14, DEPTH + 0.04), Vector3(0.1, 0.16, 0.16), DARK_WOOD)
	var top := MANTEL_HEIGHT + 0.06
	for x in [-0.56, 0.55]:  # Candles, one taller.
		var tall := 0.22 if x < 0.0 else 0.15
		CottageDressing._cyl(at, Vector3(x, top + 0.01, DEPTH + 0.12), 0.06, 0.06, 0.02, Color("C9A15A"))
		CottageDressing._cyl(at, Vector3(x, top + 0.02 + tall / 2.0, DEPTH + 0.12), 0.03, 0.03, tall, Color("F6EBD6"))
		CottageDressing._ball(at, Vector3(x, top + 0.05 + tall, DEPTH + 0.12), 0.022, Color("FFD27A"), 1.6).material_override = CottageDressing._paint(Color("FFD27A"), true)
	CottageDressing._cyl(at, Vector3(0.32, top + 0.07, DEPTH + 0.12), 0.07, 0.055, 0.14, Color("C2643C"))  # A little potted plant.
	for i in 5:
		var angle := i * TAU / 5.0
		CottageDressing._ball(at, Vector3(0.32 + cos(angle) * 0.05, top + 0.18 + (i % 2) * 0.03, DEPTH + 0.12 + sin(angle) * 0.04), 0.06, Color("5E9A4A") if i % 2 == 0 else Color("8DB84A"), 0.7)
	CottageDressing._cyl(at, Vector3(-0.3, top + 0.09, DEPTH + 0.1), 0.055, 0.055, 0.18, Color(0.85, 0.93, 0.92))  # A jar of wooden spoons.
	CottageDressing._cyl(at, Vector3(-0.3, top + 0.19, DEPTH + 0.1), 0.06, 0.06, 0.03, WOOD)
	CottageDressing._box(at, Vector3(0.0, top + 0.13, DEPTH + 0.02), Vector3(0.3, 0.24, 0.03), DARK_WOOD)  # A little framed picture, leaning.
	CottageDressing._box(at, Vector3(0.0, top + 0.13, DEPTH + 0.04), Vector3(0.22, 0.16, 0.01), Color("F2B880"))
	# The hearth, a slab of stone in front.
	CottageDressing._box(at, Vector3(0, 0.05, DEPTH + 0.2), Vector3(WIDTH + 0.4, 0.1, 0.5), Color("B9A992"))
	CottageDressing._box(at, Vector3(0, 0.1, DEPTH + 0.44), Vector3(WIDTH + 0.4, 0.015, 0.02), Color("9A8A74"))


# Logs and glowing embers in the firebox.
func _build_fire_bed(at: Node3D) -> void:
	CottageDressing._box(at, Vector3(0, 0.11, 0.22), Vector3(0.6, 0.03, 0.26), EMBER).material_override = CottageDressing._paint(EMBER, true)
	for spec in [[-0.12, 0.6], [0.12, -0.6], [0.0, 0.0]]:
		var wood := CottageDressing._cyl(at, Vector3(spec[0], 0.17 + (0.06 if spec[1] == 0.0 else 0.0), 0.22), 0.055, 0.055, 0.5, LOG)
		wood.rotation = Vector3(0.0, float(spec[1]), PI / 2.0)


# A tidy stack of firewood beside the hearth.
func _build_log_stack(at: Node3D) -> void:
	var x := WIDTH / 2.0 + 0.3
	for layer in 3:
		for i in 3 - layer:
			var wood := CottageDressing._cyl(at, Vector3(x, 0.07 + layer * 0.12, 0.15 + (i - (2 - layer) / 2.0) * 0.13 + 0.15), 0.065, 0.065, 0.45, LOG if (i + layer) % 2 == 0 else Color("8E6040"))
			wood.rotation.z = PI / 2.0
			CottageDressing._cyl(at, wood.position + Vector3(0.226, 0, 0), 0.055, 0.055, 0.005, Color("D9B98A")).rotation.z = PI / 2.0  # The cut end.


func _build_flames() -> void:
	var spots := [Vector3(-0.12, 0.14, 0.24), Vector3(0.1, 0.14, 0.22), Vector3(0.0, 0.16, 0.26), Vector3(-0.02, 0.14, 0.18)]
	var sizes := [[0.11, 0.34], [0.1, 0.3], [0.08, 0.42], [0.06, 0.24]]
	for i in spots.size():
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = sizes[i][0]
		cone.height = sizes[i][1]
		cone.radial_segments = 8
		cone.rings = 1
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = FLAME_COLORS[i % 3] if i < 3 else FLAME_COLORS[2]
		glow.emission_enabled = true
		glow.emission = glow.albedo_color
		glow.emission_energy_multiplier = 2.2
		cone.material = glow
		var pivot := MeshInstance3D.new()  # Scaled from its foot.
		pivot.position = spots[i]
		add_child(pivot)
		var flame := MeshInstance3D.new()
		flame.mesh = cone
		flame.position.y = sizes[i][1] / 2.0
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(flame)
		_flames.append(pivot)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.32)
	_light.omni_range = 3.8
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.45, DEPTH + 0.5)
	add_child(_light)
