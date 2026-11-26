# SauteAction: soften what's in the pot in butter before the stock goes in.
# A pat of butter melts in the hot pot as the meter rises, the vegetables
# sizzle and go from raw to soft and golden, then brown, then burnt. Press the
# button in the green to pour the stock in (FillAction after). Like
# PressAction without hold: full marks in the band, less either side.
class_name SauteAction
extends PressAction

const GOLDEN := Color(0.93, 0.74, 0.38)
const BURNT := Color(0.32, 0.2, 0.1)
const BUTTER := Color(1.0, 0.88, 0.45)

@export var butter := true

var _pieces: Array[MeshInstance3D] = []
var _raw: Array[Color] = []
var _paints: Array[StandardMaterial3D] = []
var _pat: MeshInstance3D
var _melt: MeshInstance3D
var _jiggle := 0.0


func _init() -> void:
	hold = false
	surface = "Pot"
	low_word = "Still raw"
	high_word = "Burnt!"
	good_word = "Soft and golden!"


func _begin() -> void:
	var pot := session.surface(surface)
	for piece in pot.contents:
		if piece is MeshInstance3D and is_instance_valid(piece):
			var paint := _paint_of(piece)
			if paint != null:
				_pieces.append(piece)
				_paints.append(paint)
				_raw.append(paint.albedo_color)
	if butter:
		var gold := StandardMaterial3D.new()
		gold.albedo_color = BUTTER
		gold.roughness = 0.2
		gold.set_meta(ToonStyle.FOOD, "butter")
		_pat = MeshInstance3D.new()
		_pat.mesh = PlaceAction.rounded_block(Vector3(0.05, 0.02, 0.035), 0.006)
		_pat.material_override = gold
		_pat.position = Vector3(0.03, 0.012, -0.02)
		pot.add_child(_pat)
		_melt = MeshInstance3D.new()  # The melted butter spreading over the bottom.
		var film := CylinderMesh.new()
		film.top_radius = pot.radius() * 0.85
		film.bottom_radius = film.top_radius
		film.height = 0.001
		var shine := gold.duplicate() as StandardMaterial3D
		shine.albedo_color = Color(BUTTER, 0.55)
		shine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		film.material = shine
		_melt.mesh = film
		_melt.position.y = 0.003
		_melt.scale = Vector3(0.2, 1.0, 0.2)
		pot.add_child(_melt)
	super()


func update(delta: float, input: CookInput) -> void:
	super(delta, input)
	if done:
		return
	var melted := clampf(_amount / (band.x * 0.6), 0.0, 1.0)
	if _pat != null:
		_pat.scale = Vector3(1.0 + melted * 0.3, maxf(1.0 - melted, 0.02), 1.0 + melted * 0.3)
		_pat.visible = melted < 0.98
		_melt.scale = Vector3.ONE * lerpf(0.2, 1.0, melted)
	var soft := clampf(_amount / ((band.x + band.y) * 0.5), 0.0, 1.0)
	var burnt := clampf((_amount - band.y) / (1.0 - band.y), 0.0, 1.0)
	_jiggle += delta
	for i in _pieces.size():
		if not is_instance_valid(_pieces[i]):
			continue
		_paints[i].albedo_color = _raw[i].lerp(GOLDEN, soft * 0.55).lerp(BURNT, burnt)
		_pieces[i].position.y += sin(_jiggle * 30.0 + i) * 0.00015 * (0.3 + _amount)  # Sizzling.
	if burnt > 0.3 and fmod(_jiggle, 0.25) < delta:
		var pot := session.surface(surface)
		session.burst(pot.position + Vector3(0.0, 0.04, 0.0), Color(0.35, 0.33, 0.32), 3, 0.12)


func end() -> void:
	super()
	if is_instance_valid(_pat):
		_pat.queue_free()


# Each piece's own copy of its paint, so they brown by themselves.
func _paint_of(piece: MeshInstance3D) -> StandardMaterial3D:
	var paint := piece.material_override as StandardMaterial3D
	if paint == null and piece.mesh != null and piece.mesh.get_surface_count() > 0:
		paint = piece.mesh.surface_get_material(0) as StandardMaterial3D
	if paint == null:
		return null
	paint = paint.duplicate()
	piece.material_override = paint
	return paint
