# RegularFigure: a regular standing about outside the restaurant (Cheddar by his
# car, or at the beach): their own model at their own height, idling, or
# talking while `talking` is set, with its animations named as in
# regular_settings.model_animations (like CustomerDisplay). Just for looks.
class_name RegularFigure
extends Node3D

var talking := false
var _animations: AnimationPlayer = null
var _model: Node3D = null


static func make(regular_id: String) -> RegularFigure:
	var figure := RegularFigure.new()
	figure.name = "Figure_" + regular_id
	var settings: Dictionary = GameData.characters.get(regular_id, {}).get("model", {})
	var path: String = settings.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return figure
	figure._model = load(path).instantiate()
	figure.add_child(figure._model)
	var height := _height_of(figure._model)
	if height > 0.0:
		figure._model.scale = Vector3.ONE * (float(settings.get("height", 1.0)) / height)
	var players := figure._model.find_children("*", "AnimationPlayer", true, false)
	figure._animations = players[0] if not players.is_empty() else null
	HeadTurn.attach(figure._model)  # Looks at a chef nearby.
	return figure


func _process(_delta: float) -> void:
	if _animations == null:
		return
	var names: Dictionary = GameData.regular_settings.get("model_animations", {})
	var animation_name: String = names.get("talk" if talking else "idle", "talk" if talking else "idle")
	if not _animations.has_animation(animation_name) or _animations.current_animation == animation_name:
		return
	_animations.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	_animations.play(animation_name, 0.25)


static func _height_of(node: Node) -> float:
	var top := -INF
	var bottom := INF
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.transform * mesh.get_aabb()  # Into the model's own space (it isn't in the tree yet).
		var parent: Node = mesh.get_parent()
		while parent != node and parent is Node3D:
			box = (parent as Node3D).transform * box
			parent = parent.get_parent()
		top = maxf(top, box.end.y)
		bottom = minf(bottom, box.position.y)
	return top - bottom if top > bottom else 0.0
