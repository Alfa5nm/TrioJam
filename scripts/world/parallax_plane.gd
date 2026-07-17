extends Node2D

@export var camera_path: NodePath
@export var motion_scale := Vector2(1.06, 1.025)
@export var max_offset := Vector2(10.0, 6.0)

var _camera: Camera2D
var _origin := Vector2.ZERO
var _camera_origin := Vector2.ZERO


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	_origin = position
	if _camera != null:
		_camera_origin = _camera.global_position


func _process(_delta: float) -> void:
	if _camera == null:
		return
	var camera_delta := _camera.global_position - _camera_origin
	var offset := camera_delta * (Vector2.ONE - motion_scale)
	offset.x = clampf(offset.x, -max_offset.x, max_offset.x)
	offset.y = clampf(offset.y, -max_offset.y, max_offset.y)
	position = _origin + offset
