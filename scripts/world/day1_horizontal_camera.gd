class_name Day1HorizontalCamera
extends Camera2D

@export var target_path: NodePath
@export var framing_offset := Vector2(240, -262)

@onready var target := get_node_or_null(target_path) as Node2D


func _process(_delta: float) -> void:
	if target != null:
		global_position = target.global_position + framing_offset
