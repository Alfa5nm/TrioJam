class_name ReportPoint
extends Area2D

signal collected(report_id: StringName, headline: String)

@export var report_id: StringName = &"placeholder"
@export var headline := "Street incident"

var _player_nearby := false
var _collected := false

@onready var prompt: Label = $Prompt
@onready var marker: Polygon2D = $Marker
@onready var title_label: Label = $Title


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	title_label.text = headline
	prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and not _collected and event.is_action_pressed("interact"):
		_collected = true
		prompt.text = "REPORT COLLECTED"
		prompt.visible = true
		marker.color = Color("62d58b")
		collected.emit(report_id, headline)
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_nearby = true
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_nearby = false
		if not _collected:
			prompt.visible = false
