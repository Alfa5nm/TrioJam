extends Control

const DAY3_STAIRWELL := "res://scenes/Day 3/day3_stairwell.tscn"

@onready var continue_button: Button = $ContinueToDay3


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"complete_day1"):
		session.complete_day1()
	continue_button.pressed.connect(_continue_to_day3)
	continue_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		_continue_to_day3()


func _continue_to_day3() -> void:
	continue_button.disabled = true
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"begin_day3"):
		session.begin_day3()
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and not transition.busy:
		transition.transition_to(DAY3_STAIRWELL, false)
	else:
		get_tree().change_scene_to_file(DAY3_STAIRWELL)
