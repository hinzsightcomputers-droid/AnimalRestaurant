# ArtStyle: the game's look in one place (res://assets/style/art_style.tres),
# so it can be tweaked in the editor's inspector: the palette from the Art
# Style Guide, and the soft toon settings every toon material gets (ToonStyle
# pushes them in; the pendant lamps take their colors from the palette).
@tool
class_name ArtStyle
extends Resource

@export_group("Palette")
@export var dark_wood := Color("#502312"):
	set(value):
		dark_wood = value
		emit_changed()
@export var wood := Color("#71412C"):
	set(value):
		wood = value
		emit_changed()
@export var light_wood := Color("#A97251"):
	set(value):
		light_wood = value
		emit_changed()
@export var brick := Color("#9A3A1B"):
	set(value):
		brick = value
		emit_changed()
@export var orange := Color("#E07228"):
	set(value):
		orange = value
		emit_changed()
@export var peach := Color("#FAA562"):
	set(value):
		peach = value
		emit_changed()
@export var cream := Color("#FBD6A0"):
	set(value):
		cream = value
		emit_changed()
@export var sage := Color("#94A189"):
	set(value):
		sage = value
		emit_changed()
@export var moss := Color("#6A7156"):
	set(value):
		moss = value
		emit_changed()

@export_group("Soft toon")
@export_range(1, 4) var shade_steps := 3:  # Bands of light, from shadow to fully lit.
	set(value):
		shade_steps = value
		emit_changed()
@export_range(0.0, 0.5) var step_softness := 0.12:  # 0 = hard edges between the bands.
	set(value):
		step_softness = value
		emit_changed()
@export var shadow_tint := Color(0.42, 0.25, 0.2):  # What the sun's shadow side leans to: warm, not grey.
	set(value):
		shadow_tint = value
		emit_changed()
@export_range(0.0, 1.0) var felt_sheen := 0.22:  # The soft glow at the edges of matte, felt-like things.
	set(value):
		felt_sheen = value
		emit_changed()
@export_range(0.0, 0.05) var outline_thickness := 0.006:  # Meters; 0 = no outline.
	set(value):
		outline_thickness = value
		emit_changed()
@export var outline_color := Color("#502312"):  # Dark wood.
	set(value):
		outline_color = value
		emit_changed()


# The toon settings as shader parameters.
func toon_parameters() -> Dictionary:
	return { "shade_steps": shade_steps, "step_softness": step_softness, "shadow_tint": shadow_tint, "felt_sheen": felt_sheen }


func outline_parameters() -> Dictionary:
	return { "outline_thickness": outline_thickness, "outline_color": outline_color }
