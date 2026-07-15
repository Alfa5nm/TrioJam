class_name NewsroomGate
extends Area2D

signal attempted

var _player_nearby := false
var _unlocked := false

@onready var prompt: Label = $Prompt
@onready var door: Polygon2D = $Door


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func set_unlocked(value: bool) -> void:
	_unlocked = value
	door.color = Color("4bcf7d") if value else Color("b6464f")
	if _player_nearby:
		prompt.text = "E  ENTER NEWSROOM" if value else "COLLECT BOTH REPORTS"


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		attempted.emit()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_nearby = true
		prompt.text = "E  ENTER NEWSROOM" if _unlocked else "COLLECT BOTH REPORTS"
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_nearby = false
		prompt.visible = false
