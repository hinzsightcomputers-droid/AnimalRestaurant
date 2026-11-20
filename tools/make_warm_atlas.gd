extends SceneTree

# Makes the room art pass's colour sheets: copies of the KayKit restaurant
# colour sheet (restaurantbits_extra.png, 8 x 4 swatches) with the swatches the
# room uses moved into the art guide's palette. Each swatch keeps its own
# light-to-dark shading, just in the new colours. RoomLook puts them on.
#   assets/textures/room_warm_atlas.png       walls, floors, counters, furniture
#   assets/textures/room_appliance_atlas.png  the fridge, ovens and microwave:
#                                             the same, but teal goes sage steel
#   godot --headless --path . -s res://tools/make_warm_atlas.gd

const SOURCE := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/restaurantbits_extra.png"
const OUT := "res://assets/textures/room_warm_atlas.png"
const OUT_APPLIANCE := "res://assets/textures/room_appliance_atlas.png"

# Swatch (column, row) -> [light, dark] in the guide's palette. The bottom row
# is glass (2 wide), the logo (2 wide), then orange, white, orange, white.
const REMAP := {
	Vector2i(2, 1): ["#90523C", "#502312"],  # Teal wainscot -> warm wood.
	Vector2i(5, 0): ["#D29A68", "#71412C"],  # Orange counter tops -> honey wood.
	Vector2i(4, 3): ["#D29A68", "#71412C"],
	Vector2i(6, 3): ["#D29A68", "#71412C"],
	Vector2i(4, 0): ["#FFF0D2", "#E2AA7B"],  # White cabinets and tiles -> cream.
	Vector2i(5, 3): ["#FFF0D2", "#E2AA7B"],
	Vector2i(7, 3): ["#FFF0D2", "#E2AA7B"],
	Vector2i(1, 1): ["#DE4B3E", "#8A2216"],  # Red -> gingham red (tablecloths), a touch warmer.
	Vector2i(0, 0): ["#6B4A32", "#3A2416"],  # Black and charcoal (floor squares) -> dark wood brown.
	Vector2i(1, 0): ["#6B4A32", "#3A2416"],
	Vector2i(2, 0): ["#A3AB98", "#5E6450"],  # Greys (steel) -> soft sage grey.
	Vector2i(3, 0): ["#C4CBB8", "#7E8672"],
}
const APPLIANCE := {
	Vector2i(2, 1): ["#B4C0A6", "#5E6A55"],  # Teal enamel -> sage steel.
}


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	var warm := _remapped(source, REMAP)
	_save(warm, OUT)
	_save(_remapped(warm, APPLIANCE, source), OUT_APPLIANCE)
	quit()


# `image` with each swatch in `remap` recoloured, shaded by `shading` (the
# original sheet's light and dark in that swatch).
func _remapped(image: Image, remap: Dictionary, shading: Image = null) -> Image:
	var out := image.duplicate() as Image
	var shade := shading if shading != null else image
	var cell := Vector2i(image.get_width() / 8, image.get_height() / 4)
	for swatch: Vector2i in remap:
		var light := Color(remap[swatch][0])
		var dark := Color(remap[swatch][1])
		var origin := swatch * cell
		var low := INF
		var high := -INF
		for y in cell.y:
			for x in cell.x:
				var l := shade.get_pixel(origin.x + x, origin.y + y).get_luminance()
				low = minf(low, l)
				high = maxf(high, l)
		for y in cell.y:
			for x in cell.x:
				var l := shade.get_pixel(origin.x + x, origin.y + y).get_luminance()
				var t := (l - low) / maxf(high - low, 0.001)
				out.set_pixel(origin.x + x, origin.y + y, dark.lerp(light, t))
	return out


func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	image.save_png(ProjectSettings.globalize_path(path))
	print("WARM ATLAS saved ", path)
