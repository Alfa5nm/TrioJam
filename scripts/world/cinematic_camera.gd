class_name CinematicCamera
extends Camera2D

@export var target_path: NodePath
@export var look_ahead := 46.0
@export var vertical_bias := -190.0
@export var follow_speed := 3.8

var _target: Player
var _focus_target: Node2D
var _focus_weight := 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Player
	if _target != null:
		global_position = _target.global_position + Vector2(0.0, vertical_bias)


func _process(delta: float) -> void:
	if _target == null:
		return
	var facing := -1.0 if _target.animated_sprite.flip_h else 1.0
	var desired := _target.global_position + Vector2(facing * look_ahead, vertical_bias)
	if is_instance_valid(_focus_target):
		desired = desired.lerp(_focus_target.global_position + Vector2(0.0, -45.0), _focus_weight)
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))


func set_focus_target(node: Node2D, weight := 0.22) -> void:
	_focus_target = node
	_focus_weight = weight


func clear_focus_target(node: Node2D) -> void:
	if _focus_target == node:
		_focus_target = null
		_focus_weight = 0.0
