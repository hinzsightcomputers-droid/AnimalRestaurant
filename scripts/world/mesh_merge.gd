# MeshMerge: turns a pile of little shape meshes (the placeholders and props
# built from boxes and balls: WoodPiece, CozyProp) into one mesh with a
# surface per material, so each costs a few draw calls instead of one per
# shape. That matters in 4-player split screen, where every call is made four
# times.
class_name MeshMerge
extends RefCounted


# Replaces every MeshInstance3D under `at` with one merged mesh, kept where
# they were (relative to `at`). Returns the merged MeshInstance3D.
static func merge(at: Node3D, cast_shadow := true) -> MeshInstance3D:
	var tools := {}  # Material -> SurfaceTool
	for node in at.find_children("*", "MeshInstance3D", true, false):
		var shape: MeshInstance3D = node
		if shape.mesh == null:
			continue
		var place := shape.transform
		var up := shape.get_parent()
		while up != at:
			place = (up as Node3D).transform * place
			up = up.get_parent()
		for surface in shape.mesh.get_surface_count():
			var paint: Material = shape.material_override
			if paint == null:
				paint = shape.mesh.material if shape.mesh is PrimitiveMesh else shape.mesh.surface_get_material(surface)
			if not tools.has(paint):
				tools[paint] = SurfaceTool.new()
				tools[paint].begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[paint].append_from(shape.mesh, surface, place)
	var merged := ArrayMesh.new()
	for paint in tools:
		tools[paint].commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, paint)
	for child in at.get_children():
		at.remove_child(child)
		child.free()
	var whole := MeshInstance3D.new()
	whole.name = "Merged"
	whole.mesh = merged
	if not cast_shadow:
		whole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at.add_child(whole)
	return whole
