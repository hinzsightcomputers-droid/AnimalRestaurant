@tool
# WoodForest: the woods round the restaurant's clearing. Scatters trees
# (WoodPiece: pines, oaks, birches, the odd apple tree) over `area`, thicker
# the farther out they are, with bushes, ferns, rocks and flowers under
# them, keeping out of every rect in `keep_clear` (the grounds, the lane, the
# cottages). Seeded, so it's the same woods every time; shows in the editor.
# All scenery: nothing here is solid. Drawn in batches (one MultiMesh per
# part of each kind of piece, per CHUNK of ground), so hundreds of trees stay
# cheap in 4-player split screen.
class_name WoodForest
extends Node3D

@export var area := Rect2(-60.0, -50.0, 120.0, 105.0):
	set(value):
		area = value
		_rebuild()
# Places the woods stay out of (x, z).
@export var keep_clear: Array[Rect2] = []:
	set(value):
		keep_clear = value
		_rebuild()
# The middle of the clearing: the woods thin out toward it.
@export var clearing := Rect2(-22.0, -20.0, 44.0, 30.0):
	set(value):
		clearing = value
		_rebuild()
@export var spacing := 3.2:  # Meters between trees, at the thickest.
	set(value):
		spacing = value
		_rebuild()
@export var undergrowth := 0.6:  # Bushes, ferns and so on per tree.
	set(value):
		undergrowth = value
		_rebuild()
@export var seed_value := 5:
	set(value):
		seed_value = value
		_rebuild()

const CHUNK := 48.0  # Meters: each batch covers one square this size, so ones out of view are skipped.

const TREES := [["wood_tree_pine", 4.0], ["wood_tree_oak", 3.0], ["wood_tree_birch", 2.0], ["wood_tree_fruit", 0.6]]
const SMALL := [["wood_bush_round", 3.0], ["wood_fern", 3.0], ["wood_bush_berry", 1.2], ["wood_rock_big", 1.0],
	["wood_rock_pile", 1.0], ["wood_flower_patch", 1.5], ["wood_bush_flower", 0.8], ["wood_rock_flat", 0.6]]
const TALL := { "wood_tree_pine": [5.0, 7.5], "wood_tree_oak": [4.2, 6.0], "wood_tree_birch": [4.0, 5.5], "wood_tree_fruit": [3.4, 4.2] }


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children(true):
		if String(child.name).begins_with("_Woods"):
			remove_child(child)
			child.queue_free()
	var holder := Node3D.new()
	holder.name = "_Woods"
	add_child(holder, false, Node.INTERNAL_MODE_FRONT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# A jittered grid: one tree per cell, skipped more often near the clearing.
	var trees: Array[Vector2] = []
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.y
		while z < area.end.y:
			var spot := Vector2(x + rng.randf_range(0.1, 0.9) * spacing, z + rng.randf_range(0.1, 0.9) * spacing)
			var roll := rng.randf()
			if _open(spot, 1.6) and roll < _thickness(spot):
				trees.append(spot)
			z += spacing
		x += spacing
	var placed := []  # [kind, at (Vector3), height, turn (radians)]
	for spot in trees:
		var kind := _pick(TREES, rng)
		var tall: Array = TALL[kind]
		placed.append([kind, Vector3(spot.x, 0.0, spot.y), rng.randf_range(tall[0], tall[1]), rng.randf_range(-PI, PI)])
		if rng.randf() < undergrowth:
			var near := spot + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.2, 2.0)
			if _open(near, 0.6):
				var small := _pick(SMALL, rng)
				placed.append([small, Vector3(near.x, 0.0, near.y), WoodPiece.size_of(small).z * rng.randf_range(0.8, 1.3), rng.randf_range(-PI, PI)])
	_batch(holder, placed)


# Every placed piece drawn as MultiMeshes: one piece of each kind is built
# (the Meshy model or the placeholder) at its usual height, and each of its
# meshes is copied to every spot of that kind, chunk by chunk.
func _batch(holder: Node3D, placed: Array) -> void:
	var parts := {}  # kind -> [[mesh, transform in the piece, override material or null], ...]
	var batches := {}  # "kind|part|chunk" -> [part, [Transform3D...]]
	for entry in placed:
		var kind: String = entry[0]
		if not parts.has(kind):
			parts[kind] = _parts_of(kind, holder)
		var usual := WoodPiece.size_of(kind).z
		var at: Vector3 = entry[1]
		var place := Transform3D(Basis(Vector3.UP, entry[3]).scaled(Vector3.ONE * (float(entry[2]) / usual)), at)
		var chunk := Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))
		for i in parts[kind].size():
			var key := "%s|%d|%s" % [kind, i, chunk]
			if not batches.has(key):
				batches[key] = [parts[kind][i], []]
			batches[key][1].append(place * parts[kind][i][1])
	for key in batches:
		var part: Array = batches[key][0]
		var spots: Array = batches[key][1]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part[0]
		multi.instance_count = spots.size()
		for i in spots.size():
			multi.set_instance_transform(i, spots[i])
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = multi
		if part[2] != null:
			drawn.material_override = part[2]
		if not String(key).begins_with("wood_tree"):  # Only the trees cast shadows: the little things don't need them.
			drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(drawn)


# The meshes of one kind of piece at its usual height: [mesh (with the
# materials it's shown with), its transform within the piece, override or null].
func _parts_of(kind: String, holder: Node3D) -> Array:
	var sample := WoodPiece.make(kind, holder, Vector3.ZERO)
	var parts := []
	var base := sample.global_transform.affine_inverse()
	for node in _meshes(sample):
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh == null:
			continue
		var mesh := mesh_node.mesh
		if mesh is ArrayMesh:  # Keep the materials it's shown with (ToonStyle may have swapped them in).
			mesh = mesh.duplicate()
			for s in mesh.get_surface_count():
				var shown := mesh_node.get_active_material(s)
				if shown != null:
					mesh.surface_set_material(s, shown)
		parts.append([mesh, base * mesh_node.global_transform, mesh_node.material_override])
	holder.remove_child(sample)
	sample.free()
	return parts


func _meshes(node: Node) -> Array:
	var found := []
	for child in node.get_children(true):
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_meshes(child))
	return found


# 0 to 1: how likely a tree is here, from thin at the clearing's edge to thick far out.
func _thickness(spot: Vector2) -> float:
	var out_x := maxf(clearing.position.x - spot.x, spot.x - clearing.end.x)
	var out_z := maxf(clearing.position.y - spot.y, spot.y - clearing.end.y)
	var out := maxf(out_x, out_z)
	return clampf(0.35 + out * 0.08, 0.0, 0.92)


func _open(spot: Vector2, margin: float) -> bool:
	for rect in keep_clear:
		if rect.grow(margin).has_point(spot):
			return false
	return true


func _pick(table: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for entry in table:
		total += float(entry[1])
	var roll := rng.randf() * total
	for entry in table:
		roll -= float(entry[1])
		if roll <= 0.0:
			return String(entry[0])
	return String(table[0][0])
