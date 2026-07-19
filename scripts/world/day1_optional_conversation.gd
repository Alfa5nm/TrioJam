class_name Day1OptionalConversation
extends Area2D

signal conversation_started
signal line_started(speaker_name: String, text: String)
signal conversation_finished
signal prompt_changed(visible: bool, text: String)

var dialogue: CinematicDialogue
var speaker_names: Array[String] = []
var dialogue_lines: Array[String] = []
var speaker_anchors: Array[Node2D] = []
var hold_seconds := 1.45
var prompt_text := "E  TALK"
var has_triggered := false
var _player_inside := false


func configure(
		dialogue_service: CinematicDialogue,
		names: Array[String],
		lines: Array[String],
		anchors: Array[Node2D]
	) -> void:
	dialogue = dialogue_service
	speaker_names = names
	dialogue_lines = lines
	speaker_anchors = anchors


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if has_triggered or not _player_inside or dialogue == null or dialogue.is_presenting:
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		play_conversation()


func play_conversation() -> void:
	if has_triggered or dialogue == null:
		return
	has_triggered = true
	prompt_changed.emit(false, prompt_text)
	conversation_started.emit()
	for index in mini(dialogue_lines.size(), speaker_anchors.size()):
		var speaker_name := speaker_names[index] if index < speaker_names.size() else "Civilian"
		line_started.emit(speaker_name, dialogue_lines[index])
		while dialogue.is_presenting:
			await get_tree().process_frame
		await dialogue.show_bark(dialogue_lines[index], speaker_name, speaker_anchors[index], hold_seconds)
	conversation_finished.emit()


func _on_body_entered(body: Node) -> void:
	if body is Player and not has_triggered:
		_player_inside = true
		prompt_changed.emit(true, prompt_text)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_inside = false
		prompt_changed.emit(false, prompt_text)
