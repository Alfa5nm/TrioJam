class_name Day1CheckpointEncounter
extends Node2D

signal sequence_started
signal dialogue_beat_started(speaker_name: String, text: String)
signal sequence_finished

@export var dialogue_path: NodePath
@export var player_path: NodePath
@export var camera_path: NodePath
@export var camera_capture_path: NodePath
@export var post_event_spawn_path: NodePath
@export var escape_barrier_path: NodePath
@export var post_event_conversation_path: NodePath
@export_range(0.01, 1.0, 0.01) var cinematic_timing_scale := 1.0

@onready var trigger: Area2D = $Trigger
@onready var trigger_shape: CollisionShape2D = $Trigger/CollisionShape2D
@onready var soldier: Sprite2D = $Soldier
@onready var civilian: Sprite2D = $Civilian
@onready var soldier_dialogue_anchor: Node2D = $SoldierDialogueAnchor
@onready var civilian_dialogue_anchor: Node2D = $CivilianDialogueAnchor
@onready var mc_dialogue_anchor: Node2D = $MCDialogueAnchor

var has_triggered := false
var _player: Player
var _dialogue: CinematicDialogue
var _camera: Day1HorizontalCamera
var _camera_capture: Day1CameraCapture
var _previous_camera_target: Node2D
var _previous_camera_offset := Vector2.ZERO
var aftermath_staged := false
var escape_staged := false
var _post_event_spawn: Node2D
var _escape_barrier: Node2D
var _post_event_conversation: Day1GossipConversation


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_dialogue = get_node_or_null(dialogue_path) as CinematicDialogue
	_camera = get_node_or_null(camera_path) as Day1HorizontalCamera
	_camera_capture = get_node_or_null(camera_capture_path) as Day1CameraCapture
	_post_event_spawn = get_node_or_null(post_event_spawn_path) as Node2D
	_escape_barrier = get_node_or_null(escape_barrier_path) as Node2D
	_post_event_conversation = get_node_or_null(post_event_conversation_path) as Day1GossipConversation
	if _camera_capture != null:
		_camera_capture.aftermath_requested.connect(_stage_aftermath)
		_camera_capture.escape_requested.connect(_stage_escape)
	trigger.body_entered.connect(_on_trigger_body_entered)


func start_sequence() -> void:
	if has_triggered or _player == null or _dialogue == null or _camera_capture == null:
		return
	has_triggered = true
	trigger.set_deferred(&"monitoring", false)
	trigger_shape.set_deferred(&"disabled", true)
	_player.controls_enabled = false
	_player.velocity = Vector2.ZERO
	_player.animated_sprite.flip_h = false
	_player.animated_sprite.play(&"idle")
	_focus_camera()
	sequence_started.emit()

	await _wait(0.35)
	await _say("Soldier", "You there. Lower the sign. You are participating in an unauthorized public demonstration", soldier_dialogue_anchor, 0.8)
	await _say("Civilian", "Huh? I-I’m standing on the side of the road. I’m not blocking anyone.", civilian_dialogue_anchor, 0.75)
	await _say("Soldier", "Do you have a permit?", soldier_dialogue_anchor, 0.65)
	await _say("Civilian", "I don’t need a permit to protest peacefully.", civilian_dialogue_anchor, 0.75)

	var approach := create_tween().set_parallel(true)
	approach.tween_property(soldier, "position:x", 22.0, _duration(0.72)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	approach.tween_property(civilian, "position:x", 122.0, _duration(0.72)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	approach.tween_property(soldier_dialogue_anchor, "position:x", 22.0, _duration(0.72)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	approach.tween_property(civilian_dialogue_anchor, "position:x", 122.0, _duration(0.72)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await approach.finished
	await _say("Soldier", "That is not what I asked. Lower. The. Sign.", soldier_dialogue_anchor, 0.85)
	await _say("Civilian", "…", civilian_dialogue_anchor, 0.55)
	await _say("Civilian", "…No.", civilian_dialogue_anchor, 0.8)
	mc_dialogue_anchor.global_position = _player.global_position + Vector2(0.0, -205.0)
	await _say("MC", "(...Something tells me this is going to escalate. I’ll get my camera out.)", mc_dialogue_anchor, 0.8)

	# The chaotic score starts on the exact frame the MC pulls out the camera,
	# rather than arriving later during the aftermath.
	_camera_capture.start_chaotic_score(true)
	_player.play_interaction()
	await _wait(0.42)
	await _camera_capture.begin_capture()
	_restore_gameplay()
	sequence_finished.emit()


func _say(speaker_name: String, text: String, anchor: Node2D, hold: float) -> void:
	dialogue_beat_started.emit(speaker_name, text)
	await _dialogue.show_bark(text, speaker_name, anchor, hold)


func _focus_camera() -> void:
	if _camera == null:
		return
	_previous_camera_target = _camera.target
	_previous_camera_offset = _camera.framing_offset
	_camera.target = self
	_camera.framing_offset = Vector2(0.0, -213.0)


func _restore_gameplay() -> void:
	if _camera != null:
		_camera.target = _previous_camera_target if is_instance_valid(_previous_camera_target) else _player
		_camera.framing_offset = _previous_camera_offset
	if is_instance_valid(_player):
		_player.controls_enabled = true
		_player.animated_sprite.play(&"idle")


func _stage_aftermath() -> void:
	aftermath_staged = true
	$Aftermath.visible = true
	$Aftermath/Blood.visible = true
	civilian.rotation = -PI * 0.5
	civilian.position = Vector2(116.0, -42.0)
	civilian_dialogue_anchor.position = Vector2(116.0, -92.0)


func _stage_escape() -> void:
	escape_staged = true
	if is_instance_valid(_post_event_spawn) and is_instance_valid(_player):
		_player.global_position = _post_event_spawn.global_position
		_player.velocity = Vector2.ZERO
		_player.animated_sprite.flip_h = false
		_player.animated_sprite.play(&"idle")
	if is_instance_valid(_escape_barrier):
		_escape_barrier.visible = true
		var barrier_shape := _escape_barrier.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
		if barrier_shape != null:
			barrier_shape.set_deferred(&"disabled", false)
	if is_instance_valid(_post_event_conversation):
		_post_event_conversation.arm()
	if _camera != null and is_instance_valid(_player):
		_camera.target = _player
		_camera.framing_offset = _previous_camera_offset


func _on_trigger_body_entered(body: Node) -> void:
	if body is Player:
		start_sequence()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(_duration(seconds)).timeout


func _duration(seconds: float) -> float:
	return maxf(seconds * cinematic_timing_scale, 0.001)
