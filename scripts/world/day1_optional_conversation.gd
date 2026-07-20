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
var hold_seconds := 1.0
var locks_player_movement := false
var facing_actor: Sprite2D
var has_triggered := false
var _player_inside := false
var _active_player: Player
var _controls_were_enabled := true
var _player_flip_before := false
var _actor_flip_before := false


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


func configure_facing(actor: Sprite2D) -> void:
	facing_actor = actor


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func play_conversation() -> void:
	if has_triggered or dialogue == null:
		return
	has_triggered = true
	_set_player_locked(locks_player_movement)
	conversation_started.emit()
	for index in mini(dialogue_lines.size(), speaker_anchors.size()):
		var speaker_name := speaker_names[index] if index < speaker_names.size() else "Civilian"
		line_started.emit(speaker_name, dialogue_lines[index])
		while dialogue.is_presenting:
			await get_tree().process_frame
		await dialogue.show_bark(dialogue_lines[index], speaker_name, speaker_anchors[index], hold_seconds)
	_set_player_locked(false)
	conversation_finished.emit()


func _on_body_entered(body: Node) -> void:
	if body is Player and not has_triggered:
		_player_inside = true
		_active_player = body as Player
		play_conversation()


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_inside = false


func _set_player_locked(locked: bool) -> void:
	if not locks_player_movement or not is_instance_valid(_active_player):
		return
	if locked:
		_controls_were_enabled = _active_player.controls_enabled
		_player_flip_before = _active_player.animated_sprite.flip_h
		_active_player.controls_enabled = false
		_active_player.velocity = Vector2.ZERO
		_active_player.animated_sprite.play(&"idle")
		if is_instance_valid(facing_actor):
			_actor_flip_before = facing_actor.flip_h
			_active_player.animated_sprite.flip_h = facing_actor.global_position.x < _active_player.global_position.x
			facing_actor.flip_h = _active_player.global_position.x < facing_actor.global_position.x
	else:
		_active_player.animated_sprite.flip_h = _player_flip_before
		if is_instance_valid(facing_actor):
			facing_actor.flip_h = _actor_flip_before
		_active_player.controls_enabled = _controls_were_enabled
