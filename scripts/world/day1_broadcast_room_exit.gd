class_name Day1BroadcastRoomExit
extends Area2D

signal armed
signal transition_requested(scene_path: String)

@export var destination_scene := "res://scenes/gameplay/broadcast_interface.tscn"
@export var transition_delay := 0.32

var is_armed := false
var has_transitioned := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func arm() -> void:
	if is_armed:
		return
	is_armed = true
	armed.emit()


func _on_body_entered(body: Node) -> void:
	if not is_armed or has_transitioned or not body is Player:
		return
	has_transitioned = true
	set_deferred(&"monitoring", false)
	var player := body as Player
	player.play_door_interaction()
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"begin_day1_broadcast"):
		session.begin_day1_broadcast()
	transition_requested.emit(destination_scene)
	await get_tree().create_timer(transition_delay).timeout
	var transition_service := get_node_or_null("/root/SceneTransition")
	if transition_service != null:
		transition_service.transition_to(destination_scene, true)
	else:
		get_tree().change_scene_to_file(destination_scene)
