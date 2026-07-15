class_name RooftopStairwell
extends Node2D

var upper_route_active := false
var _spawn_position := Vector2.ZERO
var _highlight_tween: Tween

@onready var player: Player = $Player
@onready var lower_surface: CollisionPolygon2D = $Line2DFloorToMidflightCollider/StaticBody2D/CollisionPolygon2D
@onready var upper_surface: CollisionPolygon2D = $Line2DFloorToMidflightCollider2/StaticBody2D/CollisionPolygon2D
@onready var landing_trigger: Area2D = $MiddleLandingTrigger
@onready var lower_highlight: Node2D = $StairHighlights/LowerRoute
@onready var upper_highlight: Node2D = $StairHighlights/UpperRoute


func _ready() -> void:
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	landing_trigger.body_entered.connect(_on_middle_landing_entered)
	_reset_route()


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
