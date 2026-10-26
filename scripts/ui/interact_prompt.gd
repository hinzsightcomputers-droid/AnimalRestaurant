# InteractPrompt: floating text like "[E] Cook" above whatever the player can use.
# Display only: it listens to an Interactor and never changes game state.
extends Label3D

@export var interactor: Interactor
@export var button_hint := "E"  # Display text only; real bindings live in InputSetup.

var _target: Interactable = null


func _ready() -> void:
	top_level = true  # Don't move or rotate with the player.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false
	interactor.focus_changed.connect(_on_focus_changed)


func _process(_delta: float) -> void:
	if _target != null:
		global_position = _target.global_position + Vector3.UP * _target.prompt_height
		text = "[%s] %s" % [button_hint, _target.prompt]  # Prompts can change, e.g. "Cook" -> "Stir!"


func _on_focus_changed(interactable: Interactable) -> void:
	_target = interactable
	visible = interactable != null
	_process(0.0)
