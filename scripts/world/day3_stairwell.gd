class_name Day3Stairwell
extends RooftopStairwell

signal briefing_started

const BRIEFING_SCENE := "res://scenes/Day 3/day3_briefing_room.tscn"
const ROOFTOP_SCENE := "res://scenes/Day 3/day3_rooftop.tscn"

var _guard_sequence_started := false
var _returning_from_briefing := false

@export var returning_from_briefing := false

@onready var guard: Sprite2D = $Guard
@onready var guard_dialogue_anchor: Node2D = $Guard/DialogueAnchor
@onready var player_dialogue_anchor: Node2D = $Player/Day3DialogueAnchor


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_stairwell_return" if returning_from_briefing else "day3_stairwell")
	_returning_from_briefing = returning_from_briefing
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	landing_trigger.body_entered.connect(_on_day3_middle_landing_entered)
	top_door_area.body_entered.connect(_on_top_door_body_entered)
	top_door_area.body_exited.connect(_on_top_door_body_exited)
	door_prompt.visible = false
	_start_loop(room_tone)
	_start_loop(electrical)
	fade.modulate.a = 1.0
	_reset_route()
	player.controls_enabled = false
	var reveal := create_tween()
	reveal.tween_property(fade, "modulate:a", 0.0, 0.55)
	await reveal.finished
	if _returning_from_briefing:
		guard.visible = false
		player.global_position = Vector2(1015, 356)
		activate_upper_route()
		await dialogue.show_bark("…I can’t even remember the last time I felt autonomy of my own self.", "MC", player_dialogue_anchor, 1.45)
	else:
		guard.visible = true
	player.controls_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"interact") and _door_available and not _transitioning:
		_enter_rooftop()


func _on_day3_middle_landing_entered(body: Node2D) -> void:
	if body != player or _returning_from_briefing or _guard_sequence_started:
		return
	_guard_sequence_started = true
	player.controls_enabled = false
	briefing_started.emit()
	await dialogue.show_bark("Identification.", "Soldier", guard_dialogue_anchor, 0.9)
	await dialogue.show_bark("G-03S-93.", "MC", player_dialogue_anchor, 0.9)
	await dialogue.show_bark("…", "Soldier", guard_dialogue_anchor, 0.62)
	await dialogue.show_bark("You may enter.", "Soldier", guard_dialogue_anchor, 0.95)
	if not is_inside_tree():
		return
	_transitioning = true
	player.play_door_interaction()
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_briefing")
	_transition_to(BRIEFING_SCENE, true)


func _on_player_fell() -> void:
	if _returning_from_briefing:
		player.reset_to(Vector2(1015, 356))
		activate_upper_route()
	else:
		_reset_route()
		player.reset_to(_spawn_position)


func _enter_rooftop() -> void:
	_transitioning = true
	player.play_door_interaction()
	door_prompt.visible = false
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_rooftop")
	_transition_to(ROOFTOP_SCENE, true)


func _transition_to(path: String, use_door_audio: bool) -> void:
	var transition_service := get_node_or_null("/root/SceneTransition")
	if transition_service != null and not transition_service.busy:
		transition_service.transition_to(path, use_door_audio)
	else:
		get_tree().change_scene_to_file(path)
