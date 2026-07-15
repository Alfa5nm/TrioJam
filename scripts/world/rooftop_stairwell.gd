class_name RooftopStairwell
extends Node2D

var upper_route_active := false
var _spawn_position := Vector2.ZERO
var _highlight_tween: Tween
var _door_available := false
var _transitioning := false

@onready var player: Player = $Player
@onready var lower_surface: CollisionPolygon2D = $Line2DFloorToMidflightCollider/StaticBody2D/CollisionPolygon2D
@onready var upper_surface: CollisionPolygon2D = $Line2DFloorToMidflightCollider2/StaticBody2D/CollisionPolygon2D
@onready var landing_trigger: Area2D = $MiddleLandingTrigger
@onready var lower_highlight: Node2D = $StairHighlights/LowerRoute
@onready var upper_highlight: Node2D = $StairHighlights/UpperRoute
@onready var top_door_area: Area2D = $TopDoorArea
@onready var door_prompt: PanelContainer = $HUD/DoorPrompt
@onready var fade: ColorRect = $HUD/Fade


func _ready() -> void:
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	landing_trigger.body_entered.connect(_on_middle_landing_entered)
	top_door_area.body_entered.connect(_on_top_door_body_entered)
	top_door_area.body_exited.connect(_on_top_door_body_exited)
	door_prompt.visible = false
	fade.modulate.a = 0.0
	_reset_route()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"interact") and _door_available and not _transitioning:
		_enter_rooftop()


func _on_middle_landing_entered(body: Node2D) -> void:
	if body == player and not upper_route_active:
		activate_upper_route()


func activate_upper_route() -> void:
	upper_route_active = true
	# Both routes occupy the same right-hand landing. Swapping the surfaces here
	# prevents the upper polygon's left edge from blocking the first ascent.
	lower_surface.set_deferred("disabled", true)
	upper_surface.set_deferred("disabled", false)
	landing_trigger.set_deferred("monitoring", false)
	_transition_highlight(lower_highlight, upper_highlight)


func _reset_route() -> void:
	upper_route_active = false
	lower_surface.set_deferred("disabled", false)
	upper_surface.set_deferred("disabled", true)
	landing_trigger.set_deferred("monitoring", true)
	lower_highlight.modulate.a = 0.9
	upper_highlight.modulate.a = 0.12
	_start_highlight_pulse(lower_highlight)


func _transition_highlight(from_route: Node2D, to_route: Node2D) -> void:
	if _highlight_tween != null and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_parallel(true)
	_highlight_tween.tween_property(from_route, "modulate:a", 0.12, 0.55)
	_highlight_tween.tween_property(to_route, "modulate:a", 0.92, 0.55)
	_highlight_tween.chain().tween_callback(func(): _start_highlight_pulse(to_route))


func _start_highlight_pulse(route: Node2D) -> void:
	if _highlight_tween != null and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(route, "modulate:a", 0.68, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(route, "modulate:a", 0.95, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_player_fell() -> void:
	_reset_route()
	player.reset_to(_spawn_position)


func _on_top_door_body_entered(body: Node2D) -> void:
	if body == player and upper_route_active:
		_door_available = true
		door_prompt.visible = true


func _on_top_door_body_exited(body: Node2D) -> void:
	if body == player:
		_door_available = false
		door_prompt.visible = false


func _enter_rooftop() -> void:
	_transitioning = true
	player.controls_enabled = false
	door_prompt.visible = false
	var transition := create_tween()
	transition.tween_property(fade, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	transition.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/rooftop/rooftop.tscn"))
