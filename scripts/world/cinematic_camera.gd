class_name CinematicCamera
extends Camera2D

@export var target_path: NodePath
@export var look_ahead := 32.0
@export var vertical_bias := -45.0
@export var follow_speed := 5.0
@export var target_zoom := Vector2(1.22, 1.22)
@export var zoom_duration := 0.7
@export var world_bounds := Rect2(0.0, 0.0, 1280.0, 720.0)

var _target: Player
var _focus_target: Node2D
var _focus_weight := 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Player
	zoom = Vector2.ONE
	if _target != null:
		global_position = _clamp_to_world(_target.global_position + Vector2(0.0, vertical_bias))
	var zoom_in := create_tween()
	zoom_in.tween_property(self, "zoom", target_zoom, zoom_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _target == null:
		return
	var facing := -1.0 if _target.animated_sprite.flip_h else 1.0
	var desired := _target.global_position + Vector2(facing * look_ahead, vertical_bias)
	if is_instance_valid(_focus_target):
		desired = desired.lerp(_focus_target.global_position + Vector2(0.0, -45.0), _focus_weight)
	desired = _clamp_to_world(desired)
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))


func _clamp_to_world(desired: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var safe_zoom := Vector2(maxf(zoom.x, 0.001), maxf(zoom.y, 0.001))
	var half_visible := viewport_size * 0.5 / safe_zoom
	var minimum := world_bounds.position + half_visible
	var maximum := world_bounds.end - half_visible
	if minimum.x > maximum.x:
		minimum.x = world_bounds.get_center().x
		maximum.x = minimum.x
	if minimum.y > maximum.y:
		minimum.y = world_bounds.get_center().y
		maximum.y = minimum.y
	return desired.clamp(minimum, maximum)


func set_focus_target(node: Node2D, weight := 0.22) -> void:
	_focus_target = node
	_focus_weight = weight


func clear_focus_target(node: Node2D) -> void:
	if _focus_target == node:
		_focus_target = null
		_focus_weight = 0.0
