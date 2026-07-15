class_name RooftopScene
extends Node2D

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


func _ready() -> void:
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


func _process(delta: float) -> void:
	# The left doorway shelters the player; wind opens up across the roof.
	var exposure := smoothstep(100.0, 720.0, player.global_position.x)
	wind.volume_db = move_toward(wind.volume_db, lerpf(-22.0, -10.5, exposure), 8.0 * delta)
	# Birds remain a fixed world source and naturally pan/attenuate around the player listener.
	birds.volume_db = move_toward(birds.volume_db, lerpf(-17.0, -10.0, exposure), 6.0 * delta)


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
	await player.play_execute_plan()
	completion.visible = true
	completion.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(completion, "modulate:a", 1.0, 0.45)


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
