class_name StairwellInteraction
extends Area2D

signal proximity_changed(interaction: StairwellInteraction, active: bool)
signal activated(interaction: StairwellInteraction)

@export var prompt_text := "E  INTERACT"
@export_multiline var message_text := ""
@export var completes_scene := false

var player_nearby := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if player_nearby and event.is_action_pressed("interact"):
		activated.emit(self)
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_nearby = true
		proximity_changed.emit(self, true)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_nearby = false
		proximity_changed.emit(self, false)
