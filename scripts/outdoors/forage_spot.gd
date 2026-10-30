# ForageSpot: one place in data/forage.json's spots where something might be
# growing today (see Forage). Shows a little model of it, bobbing gently, and
# after hours offers "Pick up <name>" to any chef (it goes in their basket,
# so their hands needn't be free): it hops up toward them and is gone until
# 5 AM. Checks every so often whether what's here has changed (picked by
# someone, a new day, its hour come or gone, the debug panel).
class_name ForageSpot
extends Node3D

const MODEL_SIZE := 0.4
const GLOW_RADIUS := 0.38  # A soft pale patch under it, so it can be spotted at night.
const CHECK_EVERY := 1.0

var spot_index := 0
var _interactable := Interactable.new()
var _shown_id := ""
var _model: Node3D = null
var _glow: MeshInstance3D
var _check_left := 0.0
var _time := 0.0


func _ready() -> void:
	_time = randf() * TAU
	_interactable.radius = float(GameData.forage_settings.get("pick_radius", 0.9))
	_interactable.prompt_for_player = _prompt_for
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)
	_glow = _make_glow()
	add_child(_glow)
	DayCycle.daily_reset.connect(func(_date): _refresh())
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	if _model != null:
		_model.position.y = 0.03 + absf(sin(_time * 1.6)) * 0.03
		_model.rotation.y += delta * 0.4
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_EVERY
		_refresh()


# Shows what's here now (nothing if it's been picked or isn't out).
func _refresh() -> void:
	var item := Forage.item_at(spot_index)
	var id: String = item.get("id", "")
	if id == _shown_id:
		return
	_shown_id = id
	if _model != null:
		_model.queue_free()
		_model = null
	if not item.is_empty():
		_model = Forage.make_model(item, MODEL_SIZE)
		add_child(_model)
	_glow.visible = _model != null


func _prompt_for(_player_index: int) -> String:
	if _shown_id.is_empty() or not DayCycle.doors_open():
		return ""
	return "Pick up %s" % GameData.get_forage(_shown_id).get("name", "it")


func _on_interacted(player_index: int) -> void:
	if _prompt_for(player_index).is_empty():
		return
	var item := Forage.pick(spot_index, player_index)
	if item.is_empty():
		_refresh()
		return
	# It hops up toward the chef and shrinks away.
	var picked := _model
	_model = null
	_shown_id = ""
	_glow.visible = false
	var player := Player.find(get_tree(), player_index)
	var to := picked.global_position + Vector3(0.0, 0.9, 0.0)
	if player != null:
		to = player.global_position + Vector3(0.0, 1.1, 0.0)
	var tween := picked.create_tween()
	tween.set_parallel()
	tween.tween_property(picked, "global_position", to, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(picked, "scale", Vector3.ONE * 0.05, 0.35).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(picked.queue_free)


func _make_glow() -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = GLOW_RADIUS
	mesh.bottom_radius = GLOW_RADIUS
	mesh.height = 0.01
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.95, 0.7, 0.18)
	mesh.material = material
	glow.mesh = mesh
	glow.position.y = 0.006
	glow.visible = false
	return glow
