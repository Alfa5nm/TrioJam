class_name Day3BriefingRoom
extends Node2D

signal briefing_started
signal briefing_finished
signal approach_started
signal approach_finished
signal retreat_started
signal retreat_finished
signal cg_line_started(speaker: String, text: String, placement: StringName)

const STAIRWELL_SCENE := "res://scenes/Day 3/day3_stairwell_return.tscn"

@export_range(0.01, 1.0, 0.01) var timing_scale := 1.0

var _second_conversation_ready := false
var _second_conversation_started := false
var _exit_armed := false
var _near_suit := false
var _near_exit := false
var _transitioning := false
var _cg_dialogue_active := false
var _cg_typing := false
var _cg_skip_requested := false
var _cg_active_label: RichTextLabel
var _cg_uses_dialogue_boxes := false

@onready var player: Player = $Player
@onready var player_anchor: Node2D = $Player/DialogueAnchor
@onready var suit_anchor: Node2D = $Suit/DialogueAnchor
@onready var dialogue: CinematicDialogue = $CinematicDialogue
@onready var cg_overlay: CanvasLayer = $CGOverlay
@onready var cg_image: TextureRect = $CGOverlay/CGImage
@onready var cg_flash: ColorRect = $CGOverlay/Flash
@onready var stress_grade: ColorRect = $CGOverlay/StressGrade
@onready var cg_top_panel: PanelContainer = $CGOverlay/TopDialogue
@onready var cg_top_text: RichTextLabel = $CGOverlay/TopDialogue/Text
@onready var cg_bottom_panel: PanelContainer = $CGOverlay/BottomDialogue
@onready var cg_bottom_text: RichTextLabel = $CGOverlay/BottomDialogue/Text
@onready var approach_target: Marker2D = $BriefingApproachTarget
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
	await _walk_to_table()
	await _play_opening_exchange()


func _exit_tree() -> void:
	for stream_player in [hvac, fluorescent, heartbeat, breathing]:
		stream_player.stop()
	_set_loop(hvac.stream, false)
	_set_loop(fluorescent.stream, false)


func _input(event: InputEvent) -> void:
	var dialogue_skip_pressed: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	)
	if not _cg_dialogue_active or not dialogue_skip_pressed or not _cg_typing:
		return
	_cg_skip_requested = true
	if is_instance_valid(_cg_active_label):
		_cg_active_label.visible_characters = -1
	get_viewport().set_input_as_handled()


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
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.play_cue(&"gun_reveal", 0.65, true)
	briefcase.play()
	await get_tree().create_timer(_duration(0.18)).timeout
	paper.play()
	table_contact.play()
	await _reveal_cg(preload("res://assets/art/Day3/briefcase-gun.png"), false)
	await _show_cg_dialogue("MC", "…What is this?", &"bottom", 0.85)
	await _show_cg_dialogue("Company Representative", "…It’s a call to action", &"top", 1.0)
	await _show_cg_dialogue("MC", ". . .No fucking way. You’re telling me to kill?!", &"bottom", 1.15)
	await _show_cg_dialogue("Company Representative", "Now. Which side are you on?", &"top", 1.0)
	await _show_cg_dialogue("Company Representative", "If you're not with us, you're against us. The higher-ups  don't like the odds of which side you’re taking.", &"top", 1.55)
	await _dismiss_cg()
	await _play_step_back()
	_second_conversation_ready = true
	player.controls_enabled = true
	_update_prompt()


func _play_step_back() -> void:
	retreat_started.emit()
	heartbeat.volume_db = -3.0
	breathing.volume_db = -7.0
	heartbeat.play()
	breathing.play()
	# Moving left while still facing right makes this read as a backward retreat.
	player.animated_sprite.flip_h = false
	player.animated_sprite.speed_scale = 0.72
	player.animated_sprite.play(&"walk")
	var retreat := create_tween()
	retreat.tween_property(player, "position:x", player.position.x - 52.0, _duration(0.58)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await retreat.finished
	player.velocity = Vector2.ZERO
	player.animated_sprite.speed_scale = 1.0
	player.animated_sprite.play(&"idle")
	await get_tree().create_timer(_duration(0.42)).timeout
	_fade_audio(heartbeat, -32.0, 0.75)
	_fade_audio(breathing, -30.0, 0.9)
	retreat_finished.emit()


func _play_second_exchange() -> void:
	_second_conversation_started = true
	prompt.visible = false
	player.controls_enabled = false
	await dialogue.show_bark("Y-You want me to kill the leader?!", "MC", player_anchor, 1.1)
	await dialogue.show_bark("With your expertise, it shouldn’t be so difficult.", "Company Representative", suit_anchor, 1.15)
	await dialogue.show_bark("Don’t fret. You will be safe. Getting out of the country afterwards will be easy money. Your contributions will be remembered, for good or for the worse.", "Company Representative", suit_anchor, 1.85)
	heartbeat.volume_db = -3.0
	heartbeat.play()
	await _reveal_cg(preload("res://assets/art/Day3/mc-stressing.png"), true)
	await _show_cg_dialogue("MC", "Why the Peace Leader? He rejected violence.", &"bottom", 1.1)
	await _show_cg_dialogue("Company Representative", "That is not for you to be concerned about. Please take the gun, and do fulfil your final duty.", &"top", 1.55)
	await _show_cg_dialogue("MC", "(Calling me complicit, and pushing another murder on my hands… I shouldn’t have shot the first guy. Fuck fuck fuck, everything is leading upto this path… )", &"bottom", 1.9)
	await _show_cg_dialogue("MC", "…Give me a minute Let me decide, it's my own life.", &"bottom", 1.2)
	await _show_cg_dialogue("Company Representative", "You don’t have time. Go now, or we will decide for you.", &"top", 1.35)
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.stop_cue(0.65)
	await _dismiss_cg()
	_fade_audio(heartbeat, -32.0, 0.8)
	_exit_armed = true
	player.controls_enabled = true
	briefing_finished.emit()
	_update_prompt()


func _show_cg(texture: Texture2D, hold: float, stressed: bool) -> void:
	await _reveal_cg(texture, stressed)
	await get_tree().create_timer(_duration(hold)).timeout
	await _dismiss_cg()


func _reveal_cg(texture: Texture2D, stressed: bool) -> void:
	_cg_uses_dialogue_boxes = stressed
	_apply_cg_panel_styles()
	cg_image.texture = texture
	cg_image.scale = Vector2(1.025, 1.025)
	cg_image.modulate.a = 0.0
	stress_grade.modulate.a = 0.0
	cg_flash.modulate.a = 0.52
	cg_overlay.visible = true
	cg_top_panel.visible = false
	cg_bottom_panel.visible = false
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
	cg_top_panel.visible = false
	cg_bottom_panel.visible = false
	var dismiss := create_tween()
	dismiss.tween_property(cg_image, "modulate:a", 0.0, _duration(0.22))
	await dismiss.finished
	cg_overlay.visible = false


func _update_prompt() -> void:
	if _near_suit and _second_conversation_ready and not _second_conversation_started:
		prompt.text = "E / SPACE  CONTINUE"
		prompt.visible = true
	elif _near_exit and _exit_armed:
		prompt.text = "E / SPACE  LEAVE ROOM"
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
	_fade_audio(hvac, -40.0, 0.45)
	_fade_audio(fluorescent, -40.0, 0.45)
	await get_tree().create_timer(_duration(0.55)).timeout
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


func _walk_to_table() -> void:
	approach_started.emit()
	player.controls_enabled = false
	player.animated_sprite.flip_h = false
	player.animated_sprite.play(&"walk")
	var distance := absf(approach_target.global_position.x - player.global_position.x)
	var approach := create_tween()
	approach.tween_property(player, "global_position:x", approach_target.global_position.x, _duration(maxf(distance / 185.0, 0.65))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await approach.finished
	player.velocity = Vector2.ZERO
	player.animated_sprite.play(&"idle")
	approach_finished.emit()


func _show_cg_dialogue(speaker: String, text: String, placement: StringName, hold: float) -> void:
	var government := speaker == "Company Representative" or speaker == "Suited"
	var panel := cg_top_panel if placement == &"top" else cg_bottom_panel
	var label := cg_top_text if placement == &"top" else cg_bottom_text
	cg_top_panel.visible = false
	cg_bottom_panel.visible = false
	label.text = text
	label.add_theme_color_override("default_color", Color(1.0, 0.32, 0.36) if government else Color(0.86, 0.94, 1.0))
	_layout_cg_panel(panel, label, text, placement)
	panel.visible = true
	label.visible_characters = -1 if dialogue.instant_mode else 0
	_cg_dialogue_active = true
	_cg_typing = not dialogue.instant_mode
	_cg_skip_requested = false
	_cg_active_label = label
	cg_line_started.emit(speaker, text, placement)
	if not dialogue.instant_mode:
		for index in range(label.get_total_character_count()):
			if _cg_skip_requested:
				break
			label.visible_characters = index + 1
			var character := text.substr(index, 1)
			if index % 4 == 0 and not character.strip_edges().is_empty() and character not in ".,!?-":
				dialogue.blip.pitch_scale = randf_range(0.98, 1.02)
				dialogue.blip.play()
			await get_tree().create_timer(_duration(0.026)).timeout
		label.visible_characters = -1
	_cg_typing = false
	await get_tree().create_timer(_duration(hold)).timeout
	panel.visible = false
	_cg_dialogue_active = false
	_cg_skip_requested = false
	_cg_active_label = null


func _layout_cg_panel(panel: PanelContainer, label: RichTextLabel, text: String, placement: StringName) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var font_size := 27.0 if placement == &"top" else 26.0
	var width := minf(700.0 if placement == &"bottom" else 650.0, viewport_size.x - 96.0) if _cg_uses_dialogue_boxes else minf(1040.0, viewport_size.x - 120.0)
	var horizontal_padding := 52.0 if _cg_uses_dialogue_boxes else 24.0
	var characters_per_line := maxf(28.0, (width - horizontal_padding) / (font_size * 0.52))
	var lines := maxi(1, ceili(float(text.length()) / characters_per_line))
	var height := clampf(40.0 + float(lines) * 36.0, 92.0, 202.0) if _cg_uses_dialogue_boxes else clampf(24.0 + float(lines) * 36.0, 72.0, 180.0)
	label.custom_minimum_size = Vector2(width - horizontal_padding, height - (30.0 if _cg_uses_dialogue_boxes else 16.0))
	panel.custom_minimum_size = Vector2(width, height)
	panel.size = Vector2(width, height)
	if _cg_uses_dialogue_boxes:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if placement == &"top":
			panel.position = Vector2(viewport_size.x - width - 42.0, 34.0)
		else:
			panel.position = Vector2(42.0, viewport_size.y - height - 34.0)
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var centered_x := (viewport_size.x - width) * 0.5
		if placement == &"top":
			panel.position = Vector2(centered_x, 38.0)
		else:
			panel.position = Vector2(centered_x, viewport_size.y - height - 38.0)


func _apply_cg_panel_styles() -> void:
	if not _cg_uses_dialogue_boxes:
		var empty_style := StyleBoxEmpty.new()
		empty_style.content_margin_left = 12.0
		empty_style.content_margin_top = 8.0
		empty_style.content_margin_right = 12.0
		empty_style.content_margin_bottom = 8.0
		cg_top_panel.add_theme_stylebox_override(&"panel", empty_style)
		cg_bottom_panel.add_theme_stylebox_override(&"panel", empty_style.duplicate())
		return
	cg_top_panel.add_theme_stylebox_override(&"panel", _make_cg_dialogue_box(Color(1.0, 0.22, 0.3, 0.95), Color(0.055, 0.012, 0.035, 0.9)))
	cg_bottom_panel.add_theme_stylebox_override(&"panel", _make_cg_dialogue_box(Color(0.22, 0.72, 1.0, 0.95), Color(0.015, 0.035, 0.105, 0.9)))


func _make_cg_dialogue_box(border_color: Color, background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 24.0
	style.content_margin_top = 14.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 7
	return style


func _fade_audio(stream_player: Node, target_db: float, seconds: float) -> void:
	if stream_player == null:
		return
	create_tween().tween_property(stream_player, "volume_db", target_db, _duration(seconds))


func get_pause_objective() -> String:
	if _transitioning:
		return "Leave the briefing room and return to the stairwell."
	if _exit_armed:
		return "Exit the briefing room."
	if _second_conversation_started:
		return "Hear the suited representative's final warning."
	if _second_conversation_ready:
		return "Approach the representative again."
	return "Walk to the table and hear the assignment."
