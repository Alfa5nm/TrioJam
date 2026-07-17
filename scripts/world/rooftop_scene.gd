class_name RooftopScene
extends Node2D

@export var auto_advance_to_scope := true

var execute_available := false
var plan_executed := false
var _spawn_position := Vector2.ZERO

@onready var player: Player = $Player
@onready var execute_zone: Area2D = $ExecuteZone
@onready var plan_prompt: PanelContainer = $HUD/PlanPrompt
@onready var completion: PanelContainer = $HUD/Completion
@onready var fade: ColorRect = $HUD/Fade
@onready var wind: AudioStreamPlayer = $Audio/Wind
@onready var birds: AudioStreamPlayer2D = $Audio/Birds
@onready var dialogue: CinematicDialogue = $CinematicDialogue


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("scene1")
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	execute_zone.body_entered.connect(_on_execute_zone_entered)
	execute_zone.body_exited.connect(_on_execute_zone_exited)
	plan_prompt.visible = false
	completion.visible = false
	_start_loop(wind)
	_start_loop(birds)
	fade.modulate.a = 1.0
	var intro := create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_play_rooftop_intro()


func _play_rooftop_intro() -> void:
	player.controls_enabled = false
	await get_tree().create_timer(0.7).timeout
	await dialogue.show_line("I can do it.", 0.95, player, true)
	if is_inside_tree() and not plan_executed:
		player.controls_enabled = true


func _process(delta: float) -> void:
	# The left doorway shelters the player; wind opens up across the roof.
	var exposure := smoothstep(100.0, 720.0, player.global_position.x)
	wind.volume_db = move_toward(wind.volume_db, lerpf(-12.0, -3.0, exposure), 8.0 * delta)
	# Birds remain a fixed world source and naturally pan/attenuate around the player listener.
	birds.volume_db = move_toward(birds.volume_db, lerpf(-10.0, 3.0, exposure), 6.0 * delta)


func _exit_tree() -> void:
	wind.stop()
	birds.stop()
	_set_stream_loop(wind.stream, false)
	_set_stream_loop(birds.stream, false)
	wind.stream = null
	birds.stream = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"interact") and execute_available and not plan_executed:
		execute_plan()


func execute_plan() -> void:
	if plan_executed:
		return
	plan_executed = true
	execute_available = false
	plan_prompt.visible = false
	player.controls_enabled = false
	var blackout := create_tween()
	blackout.tween_property(fade, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await blackout.finished
	# Frame one is the bag search: keep it under black, then reveal the rifle
	# assembly so the player sees the authored makeshift-sniper animation.
	player.play_execute_plan()
	await player.foley_cue_played
	var reveal := create_tween()
	reveal.tween_property(fade, "modulate:a", 0.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished
	await player.execute_plan_finished
	await dialogue.show_line("...", 0.75, player, true)
	await dialogue.show_line("Should I do it?", 1.05, player, true)
	if auto_advance_to_scope:
		_advance_to_scope()


func _advance_to_scope() -> void:
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	var transition := create_tween()
	transition.tween_property(fade, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await transition.finished
	get_tree().change_scene_to_file("res://scenes/gameplay/scoped_target_scene.tscn")


func _on_execute_zone_entered(body: Node2D) -> void:
	if body == player and not plan_executed:
		execute_available = true
		plan_prompt.visible = true


func _on_execute_zone_exited(body: Node2D) -> void:
	if body == player:
		execute_available = false
		plan_prompt.visible = false


func _on_player_fell() -> void:
	if not plan_executed:
		player.reset_to(_spawn_position)


func _start_loop(audio_player) -> void:
	var audio_stream: AudioStream = audio_player.stream
	_set_stream_loop(audio_stream, true)
	audio_player.play()


func _set_stream_loop(audio_stream: AudioStream, enabled: bool) -> void:
	if audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = enabled
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = enabled
