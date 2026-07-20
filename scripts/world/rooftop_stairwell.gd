class_name RooftopStairwell
extends Node2D

var upper_route_active := false
var _spawn_position := Vector2.ZERO
var _highlight_tween: Tween
var _door_available := false
var _transitioning := false

@onready var player: Player = $Player
@onready var lower_surface: CollisionPolygon2D = $Line2DFloorToMidflightCollider/StaticBody2D/CollisionPolygon2D
@onready var upper_surface: CollisionPolygon2D = $Line2DFloorToMidflightCollider2/StaticBody2D/CollisionPolygon2D
@onready var landing_trigger: Area2D = $MiddleLandingTrigger
@onready var lower_highlight: Node2D = $StairHighlights/LowerRoute
@onready var upper_highlight: Node2D = $StairHighlights/UpperRoute
@onready var top_door_area: Area2D = $TopDoorArea
@onready var door_prompt: PanelContainer = $HUD/DoorPrompt
@onready var fade: ColorRect = $HUD/Fade
@onready var room_tone: AudioStreamPlayer = $Audio/RoomTone
@onready var electrical: AudioStreamPlayer2D = $Audio/Electrical
@onready var dialogue: CinematicDialogue = $CinematicDialogue


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("scene0")
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	landing_trigger.body_entered.connect(_on_middle_landing_entered)
	top_door_area.body_entered.connect(_on_top_door_body_entered)
	top_door_area.body_exited.connect(_on_top_door_body_exited)
	door_prompt.visible = false
	_start_loop(room_tone)
	_start_loop(electrical)
	fade.modulate.a = 0.0
	_reset_route()
	_play_day_zero_intro()


func _play_day_zero_intro() -> void:
	player.controls_enabled = false
	await dialogue.show_line("…", 0.7, player, true)
	await dialogue.show_line("…I can’t even remember the last time I felt the autonomy of my own actions.", 1.55, player, true)
	await dialogue.show_line("This… feels good.", 1.0, player, true)
	if is_inside_tree() and not _transitioning:
		player.controls_enabled = true


func _process(delta: float) -> void:
	# The enclosed lower flight carries more room tone; the upper landing is
	# dominated by the positional electrical fixture near the exit.
	var upper_mix := clampf((500.0 - player.global_position.y) / 360.0, 0.0, 1.0)
	room_tone.volume_db = move_toward(room_tone.volume_db, lerpf(-12.5, -18.0, upper_mix), 5.0 * delta)


func _exit_tree() -> void:
	room_tone.stop()
	electrical.stop()
	_set_stream_loop(room_tone.stream, false)
	_set_stream_loop(electrical.stream, false)
	room_tone.stream = null
	electrical.stream = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"interact") and _door_available and not _transitioning:
		_enter_rooftop()


func _on_middle_landing_entered(body: Node2D) -> void:
	if body == player and not upper_route_active:
		activate_upper_route()


func activate_upper_route() -> void:
	upper_route_active = true
	# Both routes occupy the same right-hand landing. Swapping the surfaces here
	# prevents the upper polygon's left edge from blocking the first ascent.
	lower_surface.set_deferred("disabled", true)
	upper_surface.set_deferred("disabled", false)
	landing_trigger.set_deferred("monitoring", false)
	_transition_highlight(lower_highlight, upper_highlight)


func _reset_route() -> void:
	upper_route_active = false
	lower_surface.set_deferred("disabled", false)
	upper_surface.set_deferred("disabled", true)
	landing_trigger.set_deferred("monitoring", true)
	lower_highlight.modulate.a = 0.9
	upper_highlight.modulate.a = 0.12
	_start_highlight_pulse(lower_highlight)


func _transition_highlight(from_route: Node2D, to_route: Node2D) -> void:
	if _highlight_tween != null and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_parallel(true)
	_highlight_tween.tween_property(from_route, "modulate:a", 0.12, 0.55)
	_highlight_tween.tween_property(to_route, "modulate:a", 0.92, 0.55)
	_highlight_tween.chain().tween_callback(func(): _start_highlight_pulse(to_route))


func _start_highlight_pulse(route: Node2D) -> void:
	if _highlight_tween != null and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(route, "modulate:a", 0.68, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(route, "modulate:a", 0.95, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_player_fell() -> void:
	_reset_route()
	player.reset_to(_spawn_position)


func _on_top_door_body_entered(body: Node2D) -> void:
	if body == player and upper_route_active:
		_door_available = true
		door_prompt.visible = true


func _on_top_door_body_exited(body: Node2D) -> void:
	if body == player:
		_door_available = false
		door_prompt.visible = false


func _enter_rooftop() -> void:
	_transitioning = true
	player.play_door_interaction()
	door_prompt.visible = false
	var transition_service := get_node_or_null("/root/SceneTransition")
	if transition_service != null:
		transition_service.transition_to("res://scenes/rooftop/rooftop.tscn", true)


func _start_loop(audio_player) -> void:
	var audio_stream: AudioStream = audio_player.stream
	_set_stream_loop(audio_stream, true)
	audio_player.play()


func _set_stream_loop(audio_stream: AudioStream, enabled: bool) -> void:
	if audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = enabled
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = enabled


func get_pause_objective() -> String:
	if _transitioning:
		return "Enter the rooftop."
	if upper_route_active:
		return "Climb the upper flight and reach the rooftop door."
	return "Climb the stairwell to the upper landing."
