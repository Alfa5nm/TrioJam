extends Node2D

@export var camera_path: NodePath
@export var motion_scale := Vector2(1.06, 1.025)

var _camera: Camera2D
var _origin := Vector2.ZERO


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	_origin = position


func _process(_delta: float) -> void:
	if _camera == null:
		return
	position = _origin + _camera.global_position * (Vector2.ONE - motion_scale)
