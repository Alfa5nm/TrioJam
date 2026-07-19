class_name Day3BriefingRoom
extends Node2D

signal briefing_started
signal briefing_finished

const STAIRWELL_SCENE := "res://scenes/Day 3/day3_stairwell_return.tscn"

@export_range(0.01, 1.0, 0.01) var timing_scale := 1.0

var _second_conversation_ready := false
var _second_conversation_started := false
var _exit_armed := false
var _near_suit := false
var _near_exit := false
var _transitioning := false

@onready var player: Player = $Player
@onready var player_anchor: Node2D = $Player/DialogueAnchor
@onready var suit_anchor: Node2D = $Suit/DialogueAnchor
@onready var dialogue: CinematicDialogue = $CinematicDialogue
@onready var cg_overlay: CanvasLayer = $CGOverlay
@onready var cg_image: TextureRect = $CGOverlay/CGImage
@onready var cg_flash: ColorRect = $CGOverlay/Flash
@onready var stress_grade: ColorRect = $CGOverlay/StressGrade
@onready var prompt: Label = $HUD/Prompt
@onready var fade: ColorRect = $HUD/Fade
@onready var hvac: AudioStreamPlayer = $Audio/HVAC
@onready var fluorescent: AudioStreamPlayer2D = $Audio/Fluorescent
@onready var heartbeat: AudioStreamPlayer = $Audio/Heartbeat
@onready var breathing: AudioStreamPlayer = $Audio/Breathing
@onready var briefcase: AudioStreamPlayer = $Audio/Briefcase
@onready var paper: AudioStreamPlayer = $Audio/Paper
@onready var table_contact: AudioStreamPlayer = $Audio/TableContact
@onready var door_latch: AudioStreamPlayer = $Audio/DoorLatch


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_briefing")
	briefing_started.emit()
	player.controls_enabled = false
	_set_loop(hvac.stream, true)
	_set_loop(fluorescent.stream, true)
	hvac.play()
	fluorescent.play()
	cg_overlay.visible = false
	prompt.visible = false
	fade.modulate.a = 1.0
	$SuitConversationArea.body_entered.connect(_on_suit_area_entered)
	$SuitConversationArea.body_exited.connect(_on_suit_area_exited)
	$ExitArea.body_entered.connect(_on_exit_area_entered)
	$ExitArea.body_exited.connect(_on_exit_area_exited)
	var reveal := create_tween()
	reveal.tween_property(fade, "modulate:a", 0.0, _duration(0.6))
	await reveal.finished
	await _play_opening_exchange()


func _exit_tree() -> void:
	for stream_player in [hvac, fluorescent, heartbeat, breathing]:
		stream_player.stop()
	_set_loop(hvac.stream, false)
	_set_loop(fluorescent.stream, false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or _transitioning:
		return
	if _near_suit and _second_conversation_ready and not _second_conversation_started:
		_play_second_exchange()
	elif _near_exit and _exit_armed:
		_leave_room()


func _play_opening_exchange() -> void:
	await dialogue.show_bark("We have become more efficient, yet the leader is still alive.", "Company Representative", suit_anchor, 1.25)
	await dialogue.show_bark("…I know, but what does that have to do with me.", "MC", player_anchor, 1.15)
	briefcase.play()
	await get_tree().create_timer(_duration(0.18)).timeout
	paper.play()
	table_contact.play()
	await _reveal_cg(preload("res://assets/art/Day3/briefcase-gun.png"), false)
	await dialogue.show_bark("…What is this?", "MC", player_anchor, 0.85)
	await dialogue.show_bark("…It’s a call to action", "Company Representative", suit_anchor, 1.0)
	await dialogue.show_bark(". . .No fucking way. You’re telling me to kill?!", "MC", player_anchor, 1.15)
	await dialogue.show_bark("Now. Which side are you on?", "Company Representative", suit_anchor, 1.0)
	await dialogue.show_bark("If you're not with us, you're against us. The higher-ups  don't like the odds of which side you’re taking.", "Company Representative", suit_anchor, 1.55)
	await _dismiss_cg()
	await _play_step_back()
	_second_conversation_ready = true
	player.controls_enabled = true
	_update_prompt()


func _play_step_back() -> void:
	heartbeat.play()
	breathing.play()
	player.animated_sprite.flip_h = true
	player.animated_sprite.play(&"walk")
	var retreat := create_tween()
	retreat.tween_property(player, "position:x", player.position.x - 52.0, _duration(0.58)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await retreat.finished
	player.velocity = Vector2.ZERO
	player.animated_sprite.play(&"idle")
	await get_tree().create_timer(_duration(0.42)).timeout


func _play_second_exchange() -> void:
	_second_conversation_started = true
	prompt.visible = false
	player.controls_enabled = false
	await dialogue.show_bark("Y-You want me to kill the leader?!", "MC", player_anchor, 1.1)
	await dialogue.show_bark("With your expertise, it shouldn’t be so difficult.", "Company Representative", suit_anchor, 1.15)
	await dialogue.show_bark("Don’t fret. You will be safe. Getting out of the country afterwards will be easy money. Your contributions will be remembered, for good or for the worse.", "Company Representative", suit_anchor, 1.85)
	heartbeat.play()
	await _reveal_cg(preload("res://assets/art/Day3/mc-stressing.png"), true)
	await dialogue.show_bark("Why the Peace Leader? He rejected violence.", "MC", player_anchor, 1.1)
	await dialogue.show_bark("That is not for you to be concerned about. Please take the gun, and do fulfil your final duty.", "Company Representative", suit_anchor, 1.55)
	await dialogue.show_bark("(Calling me complicit, and pushing another murder on my hands… I shouldn’t have shot the first guy. Fuck fuck fuck, everything is leading upto this path… )", "MC", player_anchor, 1.9)
	await dialogue.show_bark("…Give me a minute Let me decide, it's my own life.", "MC", player_anchor, 1.2)
	await dialogue.show_bark("You don’t have time. Go now, or we will decide for you.", "Company Representative", suit_anchor, 1.35)
	await _dismiss_cg()
	_exit_armed = true
	player.controls_enabled = true
	briefing_finished.emit()
	_update_prompt()


func _show_cg(texture: Texture2D, hold: float, stressed: bool) -> void:
	await _reveal_cg(texture, stressed)
	await get_tree().create_timer(_duration(hold)).timeout
	await _dismiss_cg()


func _reveal_cg(texture: Texture2D, stressed: bool) -> void:
	cg_image.texture = texture
	cg_image.scale = Vector2(1.025, 1.025)
	cg_image.modulate.a = 0.0
	stress_grade.modulate.a = 0.0
	cg_flash.modulate.a = 0.52
	cg_overlay.visible = true
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(cg_image, "modulate:a", 1.0, _duration(0.18))
	reveal.tween_property(cg_flash, "modulate:a", 0.0, _duration(0.16))
	if stressed:
		reveal.tween_property(stress_grade, "modulate:a", 0.34, _duration(0.3))
	await reveal.finished
	var drift := create_tween()
	drift.tween_property(cg_image, "scale", Vector2.ONE, _duration(3.5)).set_trans(Tween.TRANS_SINE)


func _replace_cg(texture: Texture2D, stressed: bool) -> void:
	var conceal := create_tween()
	conceal.tween_property(cg_image, "modulate:a", 0.0, _duration(0.12))
	await conceal.finished
	await _reveal_cg(texture, stressed)


func _dismiss_cg() -> void:
	var dismiss := create_tween()
	dismiss.tween_property(cg_image, "modulate:a", 0.0, _duration(0.22))
	await dismiss.finished
	cg_overlay.visible = false


func _update_prompt() -> void:
	if _near_suit and _second_conversation_ready and not _second_conversation_started:
		prompt.text = "E  CONTINUE"
		prompt.visible = true
	elif _near_exit and _exit_armed:
		prompt.text = "E  LEAVE ROOM"
		prompt.visible = true
	else:
		prompt.visible = false


func _on_suit_area_entered(body: Node2D) -> void:
	if body == player:
		_near_suit = true
		_update_prompt()


func _on_suit_area_exited(body: Node2D) -> void:
	if body == player:
		_near_suit = false
		_update_prompt()


func _on_exit_area_entered(body: Node2D) -> void:
	if body == player:
		_near_exit = true
		_update_prompt()


func _on_exit_area_exited(body: Node2D) -> void:
	if body == player:
		_near_exit = false
		_update_prompt()


func _leave_room() -> void:
	_transitioning = true
	player.controls_enabled = false
	prompt.visible = false
	door_latch.play()
	player.play_door_interaction()
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.mark_day3_briefing_complete()
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and not transition.busy:
		transition.transition_to(STAIRWELL_SCENE, true)
	else:
		get_tree().change_scene_to_file(STAIRWELL_SCENE)


func _set_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
