class_name RooftopScene
extends Node2D

var execute_available := false
var plan_executed := false
var _spawn_position := Vector2.ZERO

@onready var player: Player = $Player
@onready var execute_zone: Area2D = $ExecuteZone
@onready var plan_prompt: PanelContainer = $HUD/PlanPrompt
@onready var completion: PanelContainer = $HUD/Completion
@onready var fade: ColorRect = $HUD/Fade


func _ready() -> void:
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	execute_zone.body_entered.connect(_on_execute_zone_entered)
	execute_zone.body_exited.connect(_on_execute_zone_exited)
	plan_prompt.visible = false
	completion.visible = false
	fade.modulate.a = 1.0
	var intro := create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"interact") and execute_available and not plan_executed:
		execute_plan()


func execute_plan() -> void:
	if plan_executed:
		return
	plan_executed = true
	execute_available = false
	plan_prompt.visible = false
	await player.play_execute_plan()
	completion.visible = true
	completion.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(completion, "modulate:a", 1.0, 0.45)


func _on_execute_zone_entered(body: Node2D) -> void:
	if body == player and not plan_executed:
		execute_available = true
		plan_prompt.visible = true


func _on_execute_zone_exited(body: Node2D) -> void:
	if body == player:
		execute_available = false
		plan_prompt.visible = false


func _on_player_fell() -> void:
	if not plan_executed:
		player.reset_to(_spawn_position)
