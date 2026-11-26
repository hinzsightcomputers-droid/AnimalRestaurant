@tool
# WoodPiece: one piece of the woodland outdoors (docs/art/woodland_exterior_prompts.md),
# by id: wood_tree_oak, wood_cottage_thatch, wood_lantern_post and so on. Shows
# the Meshy model design/woodland/<id>.glb once it's there; until then a
# chunky placeholder of simple shapes in the style's colors, the same size
# (design/woodland/parts.json), so the outdoors can be laid out now and the
# real models drop in by themselves later. Bottom at this node, centered on it,
# front (a door, a lantern's arm) toward +z. Shows in the editor too.
class_name WoodPiece
extends Node3D

const DIR := "res://design/woodland/"
const PARTS := "res://design/woodland/parts.json"
const IDS := ["wood_tree_oak", "wood_tree_pine", "wood_tree_birch", "wood_tree_fruit",
	"wood_bush_round", "wood_bush_berry", "wood_bush_flower", "wood_rock_big", "wood_rock_flat",
	"wood_rock_pile", "wood_fern", "wood_flower_patch", "wood_cottage_thatch", "wood_cottage_mushroom",
	"wood_cottage_stump", "wood_cottage_stone", "wood_cottage_mill", "wood_cottage_shop",
	"wood_lantern_post", "wood_well", "wood_mailbox", "wood_cart",
	"wood_house_mabel", "wood_house_stitches", "wood_house_cheddar"]

# The style sheet's palette (woodland_exterior_prompts.md).
const DARK_WOOD := Color("502312")
const WOOD := Color("71412C")
const WARM_WOOD := Color("90523C")
const LIGHT_WOOD := Color("A97251")
const BRICK := Color("9A3A1B")
const RUST := Color("C2542A")
const ORANGE := Color("E07228")
const PEACH := Color("FAA562")
const TAN := Color("E2AA7B")
const CREAM := Color("FBD6A0")
const SAGE := Color("94A189")
const MOSS := Color("6A7156")
const OLIVE := Color("494433")
const LANTERN := Color("FFD15C")
const LEAF := Color("8DBE3E")
const DEEP_LEAF := Color("5E8C36")
const PINE := Color("3F6B3A")
const STONE := Color("8C8478")
const BERRY := Color("C7303A")
const WHITE := Color("FFF6E8")

@export_enum("wood_tree_oak", "wood_tree_pine", "wood_tree_birch", "wood_tree_fruit",
	"wood_bush_round", "wood_bush_berry", "wood_bush_flower", "wood_rock_big", "wood_rock_flat",
	"wood_rock_pile", "wood_fern", "wood_flower_patch", "wood_cottage_thatch", "wood_cottage_mushroom",
	"wood_cottage_stump", "wood_cottage_stone", "wood_cottage_mill", "wood_cottage_shop",
	"wood_lantern_post", "wood_well", "wood_mailbox", "wood_cart",
	"wood_house_mabel", "wood_house_stitches", "wood_house_cheddar") var piece := "wood_tree_oak":
	set(value):
		piece = value
		_rebuild()
# How tall, in meters (0: its usual height from parts.json).
@export var height := 0.0:
	set(value):
		height = value
		_rebuild()
@export_range(-180.0, 180.0, 1.0) var turn_degrees := 0.0:
	set(value):
		turn_degrees = value
		_rebuild()

static var _parts := {}
static var _paints := {}


# A WoodPiece of `id` under `parent` at `at` (height 0: its usual one).
static func make(id: String, parent: Node, at: Vector3, tall := 0.0, turn := 0.0) -> WoodPiece:
	var wood := WoodPiece.new()
	wood.piece = id
	wood.height = tall
	wood.turn_degrees = turn
	wood.position = at
	wood.name = id.trim_prefix("wood_").to_pascal_case()
	parent.add_child(wood, true)
	return wood


# A model named in data (Cheddar's car, say): a woodland piece if `model` is a
# wood_ id, sized to `fit` (its height, or else its length or width), or else
# a ModelFit of that file. Null if there's no such model.
static func place(model: String, parent: Node3D, at: Vector3, fit: Vector3) -> Node3D:
	if not model.begins_with("wood_"):
		return ModelFit.place(model, parent, at, fit)
	var usual := size_of(model)
	var tall := fit.y
	if tall <= 0.0 and fit.z > 0.0:
		tall = usual.z * fit.z / maxf(usual.x, usual.y)
	elif tall <= 0.0 and fit.x > 0.0:
		tall = usual.z * fit.x / usual.x
	return make(model, parent, at, tall)


# [width, depth, height] in meters from parts.json, or a guess.
static func size_of(id: String) -> Vector3:
	if _parts.is_empty():
		var text := FileAccess.get_file_as_string(PARTS)
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		if parsed is Dictionary:
			for item: Dictionary in parsed.get("items", []):
				var footprint: Array = item.get("size", [1, 1])
				_parts[String(item["id"])] = Vector3(float(footprint[0]), float(footprint[1]), float(item.get("height", 1.0)))
	return _parts.get(id, Vector3(1.0, 1.0, 1.0))


# Whether the real (Meshy) model is in yet.
static func has_model(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children(true):
		if String(child.name).begins_with("_Piece"):
			remove_child(child)
			child.queue_free()
	var usual := size_of(piece)
	var tall := height if height > 0.0 else usual.z
	var holder := Node3D.new()
	holder.name = "_Piece"
	holder.rotation_degrees.y = turn_degrees
	add_child(holder, false, Node.INTERNAL_MODE_FRONT)
	if has_model(piece):
		var fit := ModelFit.new()
		fit.size = Vector3(0.0, tall, 0.0)
		holder.add_child(fit)
		fit.model = load(DIR + piece + ".glb")
		if not Engine.is_editor_hint():
			ToonStyle.apply_bare(fit)
		return
	var shape := Node3D.new()  # Built at the usual size, then scaled to fit.
	holder.add_child(shape)
	_build(shape, piece)
	shape.scale = Vector3.ONE * (tall / usual.z)


# --- The placeholders --------------------------------------------------------

func _build(at: Node3D, id: String) -> void:
	match id:
		"wood_tree_oak":
			_trunk(at, 0.32, 0.42, 2.0, WOOD)
			for clump in [[Vector3(0, 3.3, 0), 1.6], [Vector3(1.0, 2.9, 0.4), 1.1], [Vector3(-1.0, 3.0, -0.3), 1.15], [Vector3(0.2, 3.0, -1.0), 1.0], [Vector3(-0.3, 4.2, 0.2), 0.9]]:
				_ball(at, clump[0], clump[1], LEAF)
		"wood_tree_pine":
			_trunk(at, 0.25, 0.32, 1.4, DARK_WOOD)
			for tier in [[0.9, 1.5, 2.2], [2.3, 1.2, 1.9], [3.6, 0.85, 1.7]]:
				_cone(at, Vector3(0, tier[0], 0), tier[1], tier[2], PINE)
		"wood_tree_birch":
			_trunk(at, 0.16, 0.2, 3.4, WHITE)
			for band in [0.7, 1.4, 2.2, 2.9]:
				_cyl(at, Vector3(0, band, 0), 0.205, 0.205, 0.08, OLIVE)
			for clump in [[Vector3(0, 3.9, 0), 0.95], [Vector3(0.55, 3.3, 0.2), 0.7], [Vector3(-0.5, 3.4, -0.15), 0.72]]:
				_ball(at, clump[0], clump[1], Color("A9D46A"))
		"wood_tree_fruit":
			var lean := _trunk(at, 0.22, 0.3, 1.8, WARM_WOOD)
			lean.rotation_degrees.z = 6.0
			_ball(at, Vector3(0.1, 2.7, 0), 1.45, LEAF)
			for i in 9:
				var angle := i * TAU / 9.0 + 0.3
				_ball(at, Vector3(0.1 + cos(angle) * 1.3, 2.5 + sin(i * 1.7) * 0.6, sin(angle) * 1.3), 0.17, BERRY)
		"wood_bush_round":
			for clump in [[Vector3(0, 0.45, 0), 0.45], [Vector3(0.32, 0.35, 0.1), 0.34], [Vector3(-0.3, 0.36, -0.08), 0.35], [Vector3(0.05, 0.38, 0.32), 0.3]]:
				_ball(at, clump[0], clump[1], DEEP_LEAF)
		"wood_bush_berry":
			for clump in [[Vector3(0, 0.38, 0), 0.5, 0.75], [Vector3(0.42, 0.3, 0.1), 0.36, 0.8], [Vector3(-0.42, 0.3, -0.05), 0.38, 0.8]]:
				_ball(at, clump[0], clump[1], DEEP_LEAF, clump[2])
			for spot in [Vector3(0.2, 0.62, 0.3), Vector3(-0.3, 0.52, 0.3), Vector3(0.55, 0.42, 0.25), Vector3(-0.1, 0.66, -0.2), Vector3(-0.6, 0.4, 0.1)]:
				_ball(at, spot, 0.07, BERRY)
		"wood_bush_flower":
			for clump in [[Vector3(0, 0.45, 0), 0.42], [Vector3(0.28, 0.34, 0.12), 0.3], [Vector3(-0.27, 0.35, -0.08), 0.31]]:
				_ball(at, clump[0], clump[1], LEAF)
			for i in 10:
				var angle := i * 2.4
				var up := 0.35 + fmod(i * 0.37, 0.5)
				_ball(at, Vector3(cos(angle) * 0.36, up, sin(angle) * 0.36), 0.08, CREAM if i % 2 == 0 else PEACH)
		"wood_rock_big":
			_ball(at, Vector3(0, 0.32, 0), 0.55, STONE, 0.65)
			_ball(at, Vector3(0.05, 0.5, 0.02), 0.42, MOSS, 0.4)
		"wood_rock_flat":
			_ball(at, Vector3(0, 0.13, 0), 0.5, STONE, 0.28)
			_ball(at, Vector3(0.32, 0.2, 0.1), 0.18, MOSS, 0.45)
		"wood_rock_pile":
			_ball(at, Vector3(-0.15, 0.16, 0), 0.22, STONE, 0.75)
			_ball(at, Vector3(0.17, 0.15, 0.05), 0.2, Color("9B9286"), 0.75)
			_ball(at, Vector3(0.0, 0.36, 0.0), 0.16, STONE, 0.8)
			_cyl(at, Vector3(0.32, 0.06, 0.18), 0.02, 0.025, 0.12, CREAM)
			_ball(at, Vector3(0.32, 0.13, 0.18), 0.06, RUST, 0.6)
		"wood_fern":
			for i in 6:
				var frond := _ball(at, Vector3.ZERO, 0.12, DEEP_LEAF)
				frond.scale = Vector3(1.0, 0.6, 3.0)
				var angle := i * TAU / 6.0
				frond.rotation = Vector3(-0.7, angle, 0.0)
				frond.position = Vector3(sin(angle) * 0.18, 0.28, cos(angle) * 0.18)
		"wood_flower_patch":
			_ball(at, Vector3(0, 0.08, 0), 0.32, LEAF, 0.35)
			for i in 7:
				var angle := i * 2.2
				var spot := Vector3(cos(angle) * 0.2, 0.0, sin(angle) * 0.2)
				_cyl(at, spot + Vector3(0, 0.15, 0), 0.012, 0.012, 0.3, DEEP_LEAF)
				_ball(at, spot + Vector3(0, 0.32, 0), 0.06, WHITE if i % 2 == 0 else ORANGE, 0.6)
		"wood_cottage_thatch":
			_cottage(at, Vector3(4.0, 2.4, 3.4), CREAM, DARK_WOOD, Color("D9A55B"), Color("4E7A3A"), true)
		"wood_cottage_mushroom":
			_cyl(at, Vector3(0, 1.4, 0), 1.3, 1.5, 2.8, CREAM)
			var cap := _ball(at, Vector3(0, 3.3, 0), 2.1, RUST, 0.55)
			cap.name = "Cap"
			for spot in [Vector3(0.9, 3.95, 1.0), Vector3(-1.1, 3.85, 0.6), Vector3(0.2, 4.35, -0.4), Vector3(-0.3, 3.7, 1.55), Vector3(1.5, 3.6, -0.5)]:
				_ball(at, spot, 0.3, WHITE, 0.5)
			_door(at, Vector3(0, 0, 1.48), 0.9, 1.6, Color("4E7A3A"))
			_window(at, Vector3(0.85, 1.7, 1.2), 0.45)
			_window(at, Vector3(-0.85, 1.7, 1.2), 0.45)
		"wood_cottage_stump":
			_cyl(at, Vector3(0, 1.6, 0), 1.6, 1.85, 3.2, WARM_WOOD)
			_cyl(at, Vector3(0, 3.25, 0), 1.65, 1.65, 0.12, LIGHT_WOOD)
			_ball(at, Vector3(0.3, 3.3, 0.2), 1.2, MOSS, 0.25)
			_cyl(at, Vector3(0.8, 3.9, -0.5), 0.25, 0.25, 1.0, STONE)
			_door(at, Vector3(0, 0, 1.78), 0.95, 1.7, LIGHT_WOOD)
			_window(at, Vector3(0.95, 2.0, 1.5), 0.42)
			_window(at, Vector3(-0.95, 2.0, 1.5), 0.42)
		"wood_cottage_stone":
			_cottage(at, Vector3(3.6, 2.3, 3.2), STONE, OLIVE, RUST, LIGHT_WOOD, false)
			_box(at, Vector3(1.1, 3.6, -0.6), Vector3(0.6, 1.6, 0.6), Color("7A7268"))
			_lantern(at, Vector3(0.85, 1.6, 1.68))
		"wood_cottage_mill":
			_cottage(at, Vector3(3.2, 2.6, 3.2), LIGHT_WOOD, DARK_WOOD, WARM_WOOD, DARK_WOOD, false, 2.2)
			var wheel := Node3D.new()
			wheel.position = Vector3(1.95, 1.5, 0)
			wheel.rotation_degrees.z = 90.0
			at.add_child(wheel)
			var rim := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 1.05
			torus.outer_radius = 1.35
			torus.material = _paint(WOOD)
			rim.mesh = torus
			wheel.add_child(rim)
			for i in 4:
				var spoke := _box(wheel, Vector3.ZERO, Vector3(2.2, 0.18, 0.14), DARK_WOOD)
				spoke.rotation.y = i * PI / 4.0
		"wood_cottage_shop":
			_cottage(at, Vector3(4.0, 2.4, 3.2), CREAM, WOOD, BRICK, WARM_WOOD, false)
			for i in 7:  # The striped awning over the window.
				var stripe := _box(at, Vector3(-0.3 + (i - 3) * 0.32, 2.05, 1.95), Vector3(0.32, 0.08, 0.8), CREAM if i % 2 == 0 else RUST)
				stripe.rotation_degrees.x = 22.0
			_box(at, Vector3(-0.3, 1.25, 1.62), Vector3(2.0, 1.1, 0.06), Color("BFE3F0"))
			_box(at, Vector3(1.6, 2.6, 1.9), Vector3(0.7, 0.45, 0.06), LIGHT_WOOD)
		"wood_lantern_post":
			_cyl(at, Vector3(0, 1.15, 0), 0.08, 0.11, 2.3, WARM_WOOD)
			_box(at, Vector3(0, 2.25, 0.25), Vector3(0.1, 0.1, 0.55), WARM_WOOD)
			_lantern(at, Vector3(0, 1.95, 0.5))
		"wood_well":
			_cyl(at, Vector3(0, 0.4, 0), 0.7, 0.75, 0.8, STONE)
			_cyl(at, Vector3(0, 0.81, 0), 0.52, 0.52, 0.02, Color("2C3D4A"))
			for x in [-0.62, 0.62]:
				_box(at, Vector3(x, 1.25, 0), Vector3(0.12, 1.3, 0.12), WOOD)
			_prism(at, Vector3(0, 2.05, 0), Vector3(1.7, 0.55, 1.2), WARM_WOOD)
			_box(at, Vector3(0, 1.45, 0), Vector3(1.3, 0.08, 0.08), DARK_WOOD)
			_cyl(at, Vector3(0, 1.1, 0), 0.13, 0.11, 0.22, LIGHT_WOOD)
		"wood_mailbox":
			_cyl(at, Vector3(0, 0.45, 0), 0.05, 0.06, 0.9, WOOD)
			_box(at, Vector3(0, 0.98, 0), Vector3(0.3, 0.26, 0.44), LIGHT_WOOD)
			_prism(at, Vector3(0, 1.18, 0), Vector3(0.36, 0.16, 0.48), RUST)
			_box(at, Vector3(0.17, 1.05, -0.05), Vector3(0.03, 0.22, 0.04), DARK_WOOD)
			_ball(at, Vector3(0.18, 1.18, -0.05), 0.06, RUST, 0.4)
		"wood_cart":
			var body := Node3D.new()  # Built along x, then turned so its front is toward +z like the rest.
			body.rotation_degrees.y = -90.0
			at.add_child(body)
			at = body
			_box(at, Vector3(0, 0.75, 0), Vector3(2.2, 0.4, 1.2), WARM_WOOD)
			_box(at, Vector3(-0.3, 1.05, 0), Vector3(0.18, 0.35, 1.1), LIGHT_WOOD)
			_box(at, Vector3(0.5, 1.05, 0), Vector3(0.18, 0.35, 1.1), LIGHT_WOOD)
			var cover := _cyl(at, Vector3(-0.1, 1.15, 0), 0.68, 0.68, 1.7, CREAM)
			cover.rotation_degrees.z = 90.0
			cover.scale = Vector3(1.0, 1.0, 0.95)
			for x in [-0.75, 0.75]:
				for z in [-0.62, 0.62]:
					var wheel := MeshInstance3D.new()
					var torus := TorusMesh.new()
					torus.inner_radius = 0.22
					torus.outer_radius = 0.34
					torus.material = _paint(DARK_WOOD)
					wheel.mesh = torus
					wheel.position = Vector3(x, 0.34, z)
					wheel.rotation_degrees.x = 90.0
					at.add_child(wheel)
			_lantern(at, Vector3(1.2, 1.2, 0))
		# The regulars' houses (House puts its own door, windows and porch on
		# the front, at z = depth / 2, so these keep that face flat and bare).
		"wood_house_mabel":  # A mossy old stone cottage by the pond.
			_box(at, Vector3(0, 1.25, 0), Vector3(4.4, 2.5, 4.0), Color("9A9184"))
			for i in 26:  # Rounded stones poking out of the sides and back.
				var side := i % 3
				var along := fmod(i * 0.618, 1.0)
				var up := 0.3 + fmod(i * 0.37, 1.0) * 1.9
				var spot := Vector3(-2.2, up, -1.8 + along * 3.6) if side == 0 else (Vector3(2.2, up, -1.8 + along * 3.6) if side == 1 else Vector3(-2.0 + along * 4.0, up, -2.0))
				_ball(at, spot, 0.22 + fmod(i * 0.29, 0.12), Color("8A8174") if i % 2 == 0 else Color("A39A8C"), 0.7)
			var roof := _prism(at, Vector3(0, 3.2, -0.05), Vector3(5.0, 1.5, 4.3), MOSS)
			roof.scale.y = 1.1
			for i in 8:  # Lumps of moss on the roof.
				_ball(at, Vector3(-1.8 + i * 0.5, 2.75 + fmod(i * 0.4, 0.5), -1.2 + fmod(i * 0.7, 1.4)), 0.28, Color("7C8A5A"), 0.6)
			_box(at, Vector3(-1.3, 3.7, -0.9), Vector3(0.55, 1.4, 0.55), Color("7A7268"))  # Chimney.
			for x in [-1.75, 1.75]:  # Potted plants by the door.
				_cyl(at, Vector3(x, 0.2, 2.35), 0.2, 0.15, 0.4, RUST)
				_ball(at, Vector3(x, 0.55, 2.35), 0.25, DEEP_LEAF)
		"wood_house_stitches":  # A patchwork log cabin among the big trees.
			for row in 8:  # Logs, front and back along x, sides along z.
				var up := 0.16 + row * 0.3
				for z in [-1.85, 1.85]:
					var log := _cyl(at, Vector3(0, up, z), 0.16, 0.16, 4.6, WARM_WOOD if row % 2 == 0 else WOOD)
					log.rotation_degrees.z = 90.0
				for x in [-2.05, 2.05]:
					var log := _cyl(at, Vector3(x, up + 0.15, 0), 0.16, 0.16, 4.2, WOOD if row % 2 == 0 else WARM_WOOD)
					log.rotation_degrees.x = 90.0
			_box(at, Vector3(0, 1.25, 0), Vector3(4.0, 2.5, 3.6), LIGHT_WOOD)  # Inside the logs.
			_prism(at, Vector3(0, 3.15, 0), Vector3(5.0, 1.5, 4.5), DARK_WOOD)
			for patch in [[Vector3(-1.2, 3.0, 0.9), Color("E6B0A0")], [Vector3(0.9, 3.3, -0.6), Color("A3C9A0")], [Vector3(1.4, 2.8, 1.3), Color("D9CF8F")], [Vector3(-0.6, 3.4, -1.0), Color("C7A6D9")]]:
				var square := _box(at, patch[0], Vector3(0.7, 0.05, 0.6), patch[1])
				square.rotation_degrees.x = 34.0 if patch[0].z > 0 else -34.0
			_box(at, Vector3(1.4, 3.9, -0.9), Vector3(0.5, 1.2, 0.5), STONE)  # Chimney.
			_box(at, Vector3(-2.6, 0.75, 1.2), Vector3(0.08, 0.08, 1.6), DARK_WOOD)  # A rail with a quilt airing on it.
			for i in 4:
				_box(at, Vector3(-2.62, 0.45, 0.6 + i * 0.4), Vector3(0.04, 0.6, 0.4), [Color("E6B0A0"), Color("A3C9A0"), Color("8FB3D9"), Color("D9CF8F")][i])
		"wood_house_cheddar":  # A painted showbiz caravan with a stage porch and marquee bulbs.
			_box(at, Vector3(0, 1.35, 0), Vector3(4.4, 2.4, 2.6), Color("F2C94C"))
			_box(at, Vector3(0, 0.35, 0), Vector3(4.5, 0.3, 2.7), RUST)  # The painted skirt.
			var top := _cyl(at, Vector3(0, 2.55, 0), 1.35, 1.35, 4.5, RUST)  # A rounded roof.
			top.rotation_degrees.z = 90.0
			top.scale = Vector3(1.0, 1.0, 0.45)
			for x in [-1.8, 1.8]:  # Out past the windows.
				for z in [-1.32, 1.32]:
					var wheel := MeshInstance3D.new()
					var torus := TorusMesh.new()
					torus.inner_radius = 0.3
					torus.outer_radius = 0.45
					torus.material = _paint(DARK_WOOD)
					wheel.mesh = torus
					wheel.position = Vector3(x, 0.45, z)
					wheel.rotation_degrees.x = 90.0
					at.add_child(wheel)
			for i in 14:  # Marquee bulbs round where the door goes.
				var angle := PI * i / 13.0
				_ball(at, Vector3(cos(angle) * 0.75, 1.0 + sin(angle) * 1.3, 1.33), 0.06, LANTERN if i % 2 == 0 else WHITE).material_override = _paint(LANTERN if i % 2 == 0 else WHITE, true)
			var star := _cyl(at, Vector3(0, 3.55, 0.2), 0.42, 0.42, 0.08, LANTERN)  # The star sign on top.
			star.rotation_degrees.x = 90.0
			(star.mesh as CylinderMesh).radial_segments = 5
			_box(at, Vector3(0, 3.2, 0.2), Vector3(0.08, 0.5, 0.08), DARK_WOOD)
		_:
			_box(at, Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)


# A cottage: walls, a pitched roof (a thick soft thatch or a plain one), a
# door and two windows on the front (+z), timber corners.
func _cottage(at: Node3D, walls: Vector3, wall_color: Color, timber: Color, roof: Color, door: Color, thatch: bool, roof_height := 1.6) -> void:
	_box(at, Vector3(0, walls.y / 2.0, 0), walls, wall_color)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box(at, Vector3(x * walls.x / 2.0, walls.y / 2.0, z * walls.z / 2.0), Vector3(0.18, walls.y, 0.18), timber)
	_box(at, Vector3(0, walls.y - 0.05, walls.z / 2.0 + 0.02), Vector3(walls.x, 0.16, 0.06), timber)
	var over := 0.5 if thatch else 0.3
	var top := _prism(at, Vector3(0, walls.y + roof_height / 2.0, 0), Vector3(walls.x + over, roof_height, walls.z + over), roof)
	if thatch:
		top.scale.y = 1.15
	_door(at, Vector3(-walls.x * 0.18, 0, walls.z / 2.0 + 0.02), 0.85, 1.6, door)
	_window(at, Vector3(walls.x * 0.25, 1.3, walls.z / 2.0 + 0.02), 0.55)
	_box(at, Vector3(walls.x * 0.25, 0.92, walls.z / 2.0 + 0.12), Vector3(0.7, 0.16, 0.2), PEACH)


func _door(at: Node3D, spot: Vector3, wide: float, tall: float, color: Color) -> void:
	_box(at, spot + Vector3(0, tall / 2.0, 0), Vector3(wide, tall, 0.08), color)
	_ball(at, spot + Vector3(wide * 0.3, tall * 0.5, 0.06), 0.05, LANTERN)


func _window(at: Node3D, spot: Vector3, size: float) -> void:
	_box(at, spot, Vector3(size + 0.1, size + 0.1, 0.06), DARK_WOOD)
	_box(at, spot + Vector3(0, 0, 0.02), Vector3(size, size, 0.06), LANTERN, true)


func _lantern(at: Node3D, spot: Vector3) -> void:
	_box(at, spot, Vector3(0.22, 0.28, 0.22), LANTERN, true)
	_prism(at, spot + Vector3(0, 0.2, 0), Vector3(0.28, 0.12, 0.28), DARK_WOOD)


func _trunk(at: Node3D, top: float, bottom: float, tall: float, color: Color) -> MeshInstance3D:
	return _cyl(at, Vector3(0, tall / 2.0, 0), top, bottom, tall, color)


func _ball(at: Node3D, spot: Vector3, radius: float, color: Color, squash := 1.0) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0 * squash
	sphere.radial_segments = 16
	sphere.rings = 8
	return _mesh(at, sphere, spot, color)


func _cyl(at: Node3D, spot: Vector3, top: float, bottom: float, tall: float, color: Color) -> MeshInstance3D:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = tall
	tube.radial_segments = 16
	return _mesh(at, tube, spot, color)


func _cone(at: Node3D, spot: Vector3, radius: float, tall: float, color: Color) -> MeshInstance3D:
	return _cyl(at, spot + Vector3(0, tall / 2.0, 0), 0.08, radius, tall, color)


func _box(at: Node3D, spot: Vector3, size: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var cube := BoxMesh.new()
	cube.size = size
	var mesh := _mesh(at, cube, spot, color)
	if glow:
		mesh.material_override = _paint(color, true)
	return mesh


func _prism(at: Node3D, spot: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var roof := PrismMesh.new()
	roof.size = size
	return _mesh(at, roof, spot, color)


func _mesh(at: Node3D, primitive: PrimitiveMesh, spot: Vector3, color: Color) -> MeshInstance3D:
	primitive.material = _paint(color)
	var mesh := MeshInstance3D.new()
	mesh.mesh = primitive
	mesh.position = spot
	at.add_child(mesh)
	return mesh


# One shared material per color (and one glowing one), so many pieces stay cheap.
static func _paint(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html() + ("g" if glow else "")
	if not _paints.has(key):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = color
		paint.roughness = 0.9
		if glow:
			paint.emission_enabled = true
			paint.emission = color
			paint.emission_energy_multiplier = 1.2
		_paints[key] = paint
	return _paints[key]
