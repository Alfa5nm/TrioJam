class_name Day1SeedlessRally
extends Node2D

signal sequence_started
signal dialogue_beat_started(speaker_name: String, text: String)
signal sequence_finished

@export var dialogue_path: NodePath
@export var player_path: NodePath
@export var camera_path: NodePath
@export var camera_capture_path: NodePath
@export var broadcast_exit_path: NodePath
@export_range(0.01, 1.0, 0.01) var cinematic_timing_scale := 1.0
@export_range(0.0, 4.0, 0.1) var protester_bob_height := 1.25
@export_range(0.1, 3.0, 0.05) var protester_bob_speed := 1.05

@onready var trigger: Area2D = $Trigger
@onready var trigger_shape: CollisionShape2D = $Trigger/CollisionShape2D
@onready var representative: Sprite2D = $Stage/Representative
@onready var crowd_ambience: AudioStreamPlayer2D = $CrowdAmbience
@onready var representative_anchor: Node2D = $DialogueAnchors/Representative
@onready var customer_anchor: Node2D = $DialogueAnchors/Customer
@onready var farmers_anchor: Node2D = $DialogueAnchors/Farmers
@onready var opposition_anchor: Node2D = $DialogueAnchors/Opposition
@onready var mc_anchor: Node2D = $DialogueAnchors/MC
@onready var stage_focus: Node2D = $CameraFocus/Stage
@onready var customer_focus: Node2D = $CameraFocus/Customers
@onready var farmers_focus: Node2D = $CameraFocus/Farmers

var has_triggered := false
var _elapsed := 0.0
var _animated_sprites: Array[Sprite2D] = []
var _base_positions: Array[Vector2] = []
var _player: Player
var _dialogue: CinematicDialogue
var _camera: Day1HorizontalCamera
var _camera_capture: Day1SeedlessCameraCapture
var _broadcast_exit: Day1BroadcastRoomExit
var _previous_camera_target: Node2D
var _previous_camera_offset := Vector2.ZERO
var _ambience_tween: Tween
var _ambience_volume_db := -11.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_dialogue = get_node_or_null(dialogue_path) as CinematicDialogue
	_camera = get_node_or_null(camera_path) as Day1HorizontalCamera
	_camera_capture = get_node_or_null(camera_capture_path) as Day1SeedlessCameraCapture
	_broadcast_exit = get_node_or_null(broadcast_exit_path) as Day1BroadcastRoomExit
	for group in [$LeftProtesters, $RightProtesters, $CustomerQueue]:
		for node in group.get_children():
			var person := node as Sprite2D
			if person == null:
				continue
			_animated_sprites.append(person)
			_base_positions.append(person.position)
	_animated_sprites.append(representative)
	_base_positions.append(representative.position)
	if crowd_ambience.stream is AudioStreamMP3:
		(crowd_ambience.stream as AudioStreamMP3).loop = true
	_ambience_volume_db = crowd_ambience.volume_db
	if crowd_ambience.stream != null:
		crowd_ambience.play()
	if _camera_capture != null:
		_camera_capture.capture_started.connect(_duck_rally_ambience)
		_camera_capture.capture_finished.connect(_restore_rally_ambience)
	trigger.body_entered.connect(_on_trigger_body_entered)


func _process(delta: float) -> void:
	_elapsed += delta
	for index in range(_animated_sprites.size()):
		var phase := _elapsed * protester_bob_speed + float(index) * 0.61
		var amplitude := protester_bob_height * (0.45 if _animated_sprites[index] == representative else 1.0)
		_animated_sprites[index].position.y = _base_positions[index].y + sin(phase) * amplitude


func start_sequence() -> void:
	if has_triggered or _player == null or _dialogue == null or _camera == null or _camera_capture == null:
		return
	has_triggered = true
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		# Reaching the depot ends the checkpoint panic cue and restores the
		# daytime street bed until the farmers' protest escalates.
		music_director.play_cue(&"day1_bg", 0.65)
	trigger.set_deferred(&"monitoring", false)
	trigger_shape.set_deferred(&"disabled", true)
	_player.controls_enabled = false
	_player.velocity = Vector2.ZERO
	_player.animated_sprite.flip_h = false
	_player.animated_sprite.play(&"idle")
	_previous_camera_target = _camera.target
	_previous_camera_offset = _camera.framing_offset
	sequence_started.emit()
	# The post-checkpoint gossip is intentionally non-blocking and may still be
	# finishing when the player reaches this trigger. Hold the player here until
	# the shared bubble is free so the two encounters never overwrite each other.
	while is_instance_valid(_dialogue) and _dialogue.is_presenting:
		await get_tree().process_frame
	await _wait(0.12)

	mc_anchor.global_position = _player.global_position + Vector2(0.0, -190.0)
	await _focus(_player)
	await _say("MC", "[ …I should have stayed oblivious of this incident. Ignorance is bliss, some would say ]", mc_anchor, 0.85)
	await _say("MC", "[ Hm…?]", mc_anchor, 0.65)

	await _focus(stage_focus)
	await _say("REP", "Today, we are proud to introduce a new era of agricultural development.", representative_anchor, 0.8)
	await _say("REP", "No seeds, No inconvenience!", representative_anchor, 0.7)

	await _focus(customer_focus)
	await _say("Civilian Customer", "It does taste good, My kids always complain about the seeds.", customer_anchor, 0.8)

	await _focus(stage_focus)
	await _say("Company Representative", "This program will modernize our farms and strengthen the national food supply.", representative_anchor, 0.85)

	await _focus(farmers_focus)
	if music_director != null:
		music_director.play_cue(&"chaotic_music", 0.45, true)
	await _say("Farmers", "LIES!", farmers_anchor, 0.65)
	await _say("Farmers", "They want us to use only their seeds. We can’t even use our seeds, and we cannot plant again without paying them", farmers_anchor, 0.95)
	await _say("Opposition Volunteer", "And when the farmers resist against this foolishness, they call it opposition violence.", opposition_anchor, 0.9)

	await _focus(stage_focus)
	await _say("Company Representative", "Please do not allow a small group of political agitators to distract from today’s celebration.", representative_anchor, 0.9)

	mc_anchor.global_position = _player.global_position + Vector2(0.0, -190.0)
	await _focus(_player)
	await _say("MC", "[...I should probably record this…]", mc_anchor, 0.75)
	_player.play_interaction()
	await _wait(0.42)
	await _camera_capture.begin_capture()

	mc_anchor.global_position = _player.global_position + Vector2(0.0, -190.0)
	if music_director != null:
		music_director.stop_cue(0.65)
	await _focus(_player)
	await _say("MC", "( I think my job here is done. I need to run to the Broastcast Room…)", mc_anchor, 0.9)
	_restore_gameplay()
	if is_instance_valid(_broadcast_exit):
		_broadcast_exit.arm()
	sequence_finished.emit()


func _say(speaker_name: String, text: String, anchor: Node2D, hold: float) -> void:
	dialogue_beat_started.emit(speaker_name, text)
	await _dialogue.show_bark(text, speaker_name, anchor, hold)


func _focus(target: Node2D) -> void:
	_camera.target = target
	_camera.framing_offset = Vector2(0.0, -213.0)
	await _wait(0.42)


func _restore_gameplay() -> void:
	if is_instance_valid(_camera):
		_camera.target = _previous_camera_target if is_instance_valid(_previous_camera_target) else _player
		_camera.framing_offset = _previous_camera_offset
	if is_instance_valid(_player):
		_player.controls_enabled = true
		_player.velocity = Vector2.ZERO
		_player.animated_sprite.flip_h = false
		_player.animated_sprite.play(&"idle")


func _duck_rally_ambience() -> void:
	_fade_ambience(_ambience_volume_db - 10.0, 0.35)


func _restore_rally_ambience() -> void:
	_fade_ambience(_ambience_volume_db, 0.65)


func _fade_ambience(target_db: float, duration: float) -> void:
	if _ambience_tween != null and _ambience_tween.is_running():
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(crowd_ambience, "volume_db", target_db, duration)


func _on_trigger_body_entered(body: Node) -> void:
	if body is Player:
		start_sequence()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(_duration(seconds)).timeout


func _duration(seconds: float) -> float:
	return maxf(seconds * cinematic_timing_scale, 0.001)
