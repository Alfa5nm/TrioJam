class_name ScopeReticle
extends Control

var confirmed := false:
	set(value):
		confirmed = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var color := Color(0.96, 0.78, 0.48, 0.96) if confirmed else Color(0.86, 0.94, 0.9, 0.92)
	draw_arc(center, 42.0, 0.0, TAU, 80, color, 2.0, true)
	draw_arc(center, 6.0, 0.0, TAU, 28, color, 1.5, true)
	draw_line(center + Vector2(-74, 0), center + Vector2(-13, 0), color, 1.5, true)
	draw_line(center + Vector2(13, 0), center + Vector2(74, 0), color, 1.5, true)
	draw_line(center + Vector2(0, -74), center + Vector2(0, -13), color, 1.5, true)
	draw_line(center + Vector2(0, 13), center + Vector2(0, 74), color, 1.5, true)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(center + direction * 42.0, center + direction * 51.0, color, 2.0, true)
	draw_circle(center, 1.8, color)
