class_name BroadcastInterface
extends Control

signal broadcast_resolved(sequence: BroadcastSequence, matched: bool)
signal continue_pressed
signal day0_resolution(result: ResolutionResult)
signal phase_changed(phase: Phase)

enum Phase { FADE_IN, TV_BOOT, INTERROGATION, NAME_ENTRY, DESK_REVEAL, EDITING, RESPONSE, NEWS_HANDOFF }
enum ResolutionResult { TRUTH_REJECTED, INVALID, PROPAGANDA_ACCEPTED }

const TRUTH_RESPONSE: Array[String] = ["No. No no no. I can't broadcast this."]
const INVALID_RESPONSE: Array[String] = ["...This doesn't make any sense."]
const PROPAGANDA_RESPONSE: Array[String] = [
	"They will believe this, even if it doesn't make sense.",
	"This will cause a huge conflict...",
	"...I have to be okay with this.",
]
const DISABLED_MODULATE := Color(0.55, 0.58, 0.62, 0.48)
const MC_STUNNED := preload("res://assets/art/ui/broadcast_v2/mc-stunned.png")
const MC_GUARDED := preload("res://assets/art/ui/broadcast_v2/mc-guarded.png")
const MC_FEARFUL_TALK := preload("res://assets/art/ui/broadcast_v2/mc-fearful-talk.png")
const MC_RESOLVED_TALK := preload("res://assets/art/ui/broadcast_v2/mc-resolved-talk.png")
const BROADCAST_FONT := preload("res://assets/fonts/Basic-Regular.ttf")

@export var instant_mode := false
@export var use_news_broadcast_scene := true

var phase := Phase.FADE_IN
var report: BroadcastReport
var _slots: Array[FrameSlot] = []
var _playback_lines: Array[String] = []
var _playback_frames: Array[int] = []
var _playback_speakers: Array[StringName] = []
var _playback_beats: Array[BroadcastDialogueBeat] = []
var _playback_index := 0
var _playback_active := false
var _playback_is_recap := false
var _mission_response: Array[String] = []
var _mission_response_index := 0
var _pending_sequence: BroadcastSequence
var _pending_result := ResolutionResult.INVALID
var _typing_response := false
var _skip_response := false
var _editing_enabled := false
var _awaiting_name := false
var _name_line_ready := false
var _elapsed := 0.0
var _current_speaker: StringName = &""
var _current_emotion: StringName = &"neutral"

@onready var scene_frame: SceneFrame = %SceneFrame
@onready var character_roster: CharacterRoster = %CharacterRoster
@onready var broadcast_button: Button = %BroadcastButton
@onready var continue_button: Button = %ContinueButton
@onready var dialogue_label: Label = %DialogueLabel
@onready var speaker_portrait: TextureRect = %SpeakerPortrait
@onready var screen_status: Label = %ScreenStatus
@onready var speech_bubble: PanelContainer = %SpeechBubble
@onready var bubble_tail_left: Polygon2D = %BubbleTailLeft
@onready var bubble_tail_right: Polygon2D = %BubbleTailRight
@onready var cinema_rig: Control = %CinemaRig
@onready var desk_root: Control = %DeskRoot
@onready var desk_portrait: TextureRect = %DeskPortrait
@onready var desk_dialogue: Label = %DeskDialogue
@onready var desk_continue_button: Button = %DeskContinueButton
@onready var fade: ColorRect = %Fade
@onready var room_dimmer: ColorRect = %RoomDimmer
@onready var crt_material: ShaderMaterial = %CRTContainer.material as ShaderMaterial
@onready var cause_slot: FrameSlot = %CauseSlot
@onready var conflict_slot: FrameSlot = %ConflictSlot
@onready var outcome_slot: FrameSlot = %OutcomeSlot
@onready var blip: AudioStreamPlayer = $Audio/Blip
@onready var government_blip: AudioStreamPlayer = $Audio/GovernmentBlip
@onready var tv_hum: AudioStreamPlayer = $Audio/TVHum
@onready var tv_power: AudioStreamPlayer = $Audio/TVPower
@onready var eject_sound: AudioStreamPlayer = $Audio/Eject
@onready var impact_sound: AudioStreamPlayer = $Audio/Impact
@onready var button_sound: AudioStreamPlayer = $Audio/ButtonThunk
@onready var name_entry: VBoxContainer = %NameEntry
@onready var name_prompt: Label = %NamePrompt
@onready var name_input: LineEdit = %NameInput
@onready var name_confirm: Button = %NameConfirm
@onready var name_error: Label = %NameError


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("broadcast")
	_slots = [cause_slot, conflict_slot, outcome_slot]
	for slot in _slots:
		slot.composition_changed.connect(_on_slot_composition_changed)
		slot.capacity_warning.connect(_on_slot_capacity_warning)
		slot.footage_removed.connect(scene_frame.return_card)
		slot.footage_placed.connect(scene_frame.mark_placed)
	broadcast_button.pressed.connect(_on_broadcast_pressed)
	broadcast_button.mouse_entered.connect(_animate_broadcast_hover.bind(true))
	broadcast_button.mouse_exited.connect(_animate_broadcast_hover.bind(false))
	continue_button.pressed.connect(_on_continue_pressed)
	desk_continue_button.pressed.connect(_on_continue_pressed)
	name_input.text_changed.connect(_validate_name)
	name_input.text_submitted.connect(func(_value: String): _confirm_name())
	name_confirm.pressed.connect(_confirm_name)
	scene_frame.footage_ejected.connect(_on_footage_ejected)
	_apply_broadcast_typography(desk_root)
	if tv_hum.stream is AudioStreamWAV:
		(tv_hum.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	name_entry.visible = false
	load_report(BroadcastDemoData.rooftop_killing_report())


func _process(delta: float) -> void:
	_elapsed += delta
	if speaker_portrait.visible:
		var breath := 1.0 + sin(_elapsed * 2.1) * 0.007
		speaker_portrait.scale = Vector2(breath, breath)
		if _typing_response:
			speaker_portrait.position.y = sin(_elapsed * 12.0) * 1.4
		if _current_speaker == &"mc":
			var mouth_open := _typing_response and int(_elapsed * 9.0) % 2 == 0
			speaker_portrait.texture = _mc_texture(_current_emotion, mouth_open)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if phase in [Phase.INTERROGATION, Phase.NAME_ENTRY, Phase.RESPONSE]:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()


func _set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(phase)


func load_report(p_report: BroadcastReport) -> void:
	report = p_report
	_mission_response.clear()
	_pending_sequence = null
	_typing_response = false
	_awaiting_name = false
	_name_line_ready = false
	name_entry.visible = false
	scene_frame.setup(report.available_actions)
	character_roster.setup(report.characters)
	for slot in _slots:
		slot.clear()
		slot.max_characters = report.max_characters_per_frame
	_set_editing_enabled(false)
	speaker_portrait.visible = false
	if report.report_id == &"day0_rooftop_killing":
		_start_day0_cinematic()
	else:
		_show_desk_immediately()
		_start_intro()
	_update_broadcast_button()


func _start_day0_cinematic() -> void:
	_set_phase(Phase.FADE_IN)
	desk_root.visible = false
	cinema_rig.visible = true
	cinema_rig.position = Vector2(310, 30)
	cinema_rig.scale = Vector2(1.08, 1.08)
	cinema_rig.modulate.a = 1.0
	speech_bubble.position = Vector2(30, 404)
	fade.visible = true
	fade.color.a = 1.0
	room_dimmer.color.a = 0.18
	crt_material.set_shader_parameter("boot_progress", 0.0)
	if instant_mode:
		fade.color.a = 0.0
		room_dimmer.color.a = 0.5
		crt_material.set_shader_parameter("boot_progress", 1.0)
		_start_intro()
		return
	var intro := create_tween()
	intro.tween_property(fade, "color:a", 0.0, 0.6)
	intro.tween_property(room_dimmer, "color:a", 0.62, 0.35)
	await intro.finished
	_set_phase(Phase.TV_BOOT)
	tv_power.play()
	tv_hum.play()
	var boot := create_tween()
	boot.tween_method(func(value: float): crt_material.set_shader_parameter("boot_progress", value), 0.0, 1.0, 0.82).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var sync_glitch := create_tween()
	var crt_x: float = (%CRTContainer as Control).position.x
	for offset in [3.0, -5.0, 2.0, 0.0]:
		sync_glitch.tween_property(%CRTContainer, "position:x", crt_x + offset, 0.045)
		sync_glitch.tween_interval(0.075)
	await boot.finished
	_start_intro()


func _show_desk_immediately() -> void:
	fade.color.a = 0.0
	room_dimmer.color.a = 0.22
	crt_material.set_shader_parameter("boot_progress", 1.0)
	cinema_rig.visible = false
	desk_root.visible = true
	desk_root.modulate.a = 1.0
	desk_root.position = Vector2.ZERO
	for piece in [cause_slot, conflict_slot, outcome_slot, scene_frame, character_roster, broadcast_button]:
		piece.modulate.a = 1.0
	_set_phase(Phase.EDITING)


func _reveal_desk() -> void:
	_set_phase(Phase.DESK_REVEAL)
	_set_editing_enabled(false)
	# Preserve the final interrogation frame while the whole TV/dialogue rig
	# physically docks into the left console. The fixed desk portrait/dialogue
	# fade in only at the end, preventing a doubled UI during the move.
	desk_root.visible = true
	desk_root.modulate.a = 0.0
	desk_root.position = Vector2(0, 92)
	desk_portrait.visible = false
	desk_dialogue.visible = false
	desk_continue_button.visible = false
	continue_button.visible = false
	for hidden_piece in [cause_slot, conflict_slot, outcome_slot, scene_frame, character_roster, broadcast_button]:
		hidden_piece.modulate.a = 0.0
	var rig_tween := create_tween().set_parallel()
	rig_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	rig_tween.tween_property(desk_root, "position", Vector2.ZERO, 0.82)
	rig_tween.tween_property(desk_root, "modulate:a", 1.0, 0.52).set_delay(0.12)
	rig_tween.tween_property(cinema_rig, "position", Vector2(34, 35), 0.82)
	rig_tween.tween_property(cinema_rig, "scale", Vector2(0.47, 0.47), 0.82)
	rig_tween.tween_property(speech_bubble, "position", Vector2(38, 660), 0.82)
	if not instant_mode:
		await rig_tween.finished
		_sync_docked_dialogue()
		var handoff := create_tween().set_parallel()
		handoff.tween_property(cinema_rig, "modulate:a", 0.0, 0.16)
		handoff.tween_property(desk_portrait, "modulate:a", 1.0, 0.16).from(0.0)
		handoff.tween_property(desk_dialogue, "modulate:a", 1.0, 0.16).from(0.0)
		await handoff.finished
		cinema_rig.visible = false
		await _drop_desk_components()
	else:
		cinema_rig.visible = false
		desk_root.modulate.a = 1.0
		desk_root.position = Vector2.ZERO
		for visible_piece in [cause_slot, conflict_slot, outcome_slot, scene_frame, character_roster, broadcast_button]:
			visible_piece.modulate.a = 1.0
		_sync_docked_dialogue()
	_show_directive()


func _sync_docked_dialogue() -> void:
	desk_portrait.texture = speaker_portrait.texture
	desk_portrait.modulate = speaker_portrait.modulate
	desk_portrait.visible = true
	desk_dialogue.text = dialogue_label.text
	desk_dialogue.visible_characters = -1
	desk_dialogue.visible = true


func _drop_desk_components() -> void:
	character_roster.visible = true
	character_roster.modulate.a = 1.0
	var chips: Array[Control] = []
	for child in character_roster.get_children():
		if child is Control:
			chips.append(child as Control)
			(child as Control).modulate.a = 0.0
	var pieces: Array[Control] = [cause_slot, conflict_slot, outcome_slot, scene_frame]
	var angle_index := 0
	for piece in pieces:
		var final_y := piece.position.y
		piece.position.y -= 150.0
		piece.rotation = deg_to_rad([-4.0, 3.0, -2.0, 1.5][angle_index])
		angle_index += 1
		piece.modulate.a = 0.0
		var fall := create_tween().set_parallel()
		fall.tween_property(piece, "position:y", final_y, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fall.tween_property(piece, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fall.tween_property(piece, "modulate:a", 1.0, 0.08)
		impact_sound.pitch_scale = randf_range(0.88, 1.12)
		impact_sound.play()
		await get_tree().create_timer(0.09).timeout
	for index in chips.size():
		var chip := chips[index]
		var final_position := chip.position
		chip.position = final_position + Vector2((index % 2) * 14 - 7, -190 - index * 12)
		chip.rotation = deg_to_rad(-10.0 + index * 7.0)
		var chip_fall := create_tween().set_parallel()
		chip_fall.tween_property(chip, "position", final_position, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		chip_fall.tween_property(chip, "rotation", 0.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		chip_fall.tween_property(chip, "modulate:a", 1.0, 0.07)
		impact_sound.pitch_scale = 1.04 + index * 0.04
		impact_sound.play()
		await get_tree().create_timer(0.075).timeout
	var button_y := broadcast_button.position.y
	broadcast_button.position.y -= 170.0
	broadcast_button.modulate.a = 0.0
	var button_fall := create_tween().set_parallel()
	button_fall.tween_property(broadcast_button, "position:y", button_y, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	button_fall.tween_property(broadcast_button, "modulate:a", 1.0, 0.08)
	await button_fall.finished


func _start_intro() -> void:
	_set_phase(Phase.INTERROGATION)
	var lines := report.intro_lines if not report.intro_lines.is_empty() else [report.directive_text]
	if lines.size() == 1 and report.intro_speakers.is_empty() and report.intro_beats.is_empty():
		_show_directive()
		return
	_set_editing_enabled(false)
	continue_button.visible = true
	var frames: Array[int] = []
	for _line in lines:
		frames.append(-1)
	_playback_is_recap = false
	_playback_beats = report.intro_beats
	_begin_playback(lines, frames, report.intro_speakers)


func _begin_playback(lines: Array[String], frames: Array[int], speakers: Array[StringName]) -> void:
	_playback_lines = lines
	_playback_frames = frames
	_playback_speakers = speakers
	_playback_index = 0
	_playback_active = true
	_show_playback_line()


func _show_playback_line() -> void:
	var text := _playback_lines[_playback_index]
	var speaker: StringName = _playback_speakers[_playback_index] if _playback_index < _playback_speakers.size() else &""
	var beat: BroadcastDialogueBeat = _playback_beats[_playback_index] if _playback_index < _playback_beats.size() else null
	if beat != null:
		text = beat.text
		speaker = beat.speaker_id
	_update_speaker_portrait(speaker, beat)
	var highlighted_index := _playback_frames[_playback_index] if _playback_index < _playback_frames.size() else -1
	for i in _slots.size():
		_slots[i].set_highlighted(i == highlighted_index)
	if text == "{name_input}" or (beat != null and beat.kind == BroadcastDialogueBeat.Kind.NAME_INPUT):
		_show_name_entry()
		return
	dialogue_label.add_theme_font_size_override("font_size", 20 if cinema_rig.scale.x > 0.8 else 16)
	_type_dialogue(text)


func _update_speaker_portrait(speaker: StringName, beat: BroadcastDialogueBeat = null) -> void:
	_current_speaker = speaker
	_current_emotion = beat.emotion_id if beat != null else &"neutral"
	if speaker == &"" or report == null:
		speaker_portrait.visible = false
		return
	var texture: Texture2D = _mc_texture(_current_emotion, false) if speaker == &"mc" else report.speaker_portraits.get(speaker)
	if texture == null:
		speaker_portrait.visible = false
		return
	speaker_portrait.texture = texture
	speaker_portrait.visible = true
	speaker_portrait.modulate = Color(0.055, 0.08, 0.11, 1) if speaker == &"government" else Color.WHITE
	screen_status.text = "SECURE CHANNEL // GOV" if speaker == &"government" else "SUBJECT // G-03S-93"
	var is_thought := beat != null and beat.kind == BroadcastDialogueBeat.Kind.THOUGHT
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.025, 0.035, 0.045, 0.97) if not is_thought else Color(0.035, 0.05, 0.065, 0.94)
	bubble_style.border_color = Color(0.37, 0.55, 0.65, 0.9) if not is_thought else Color(0.31, 0.43, 0.52, 0.72)
	bubble_style.set_border_width_all(3)
	bubble_style.corner_radius_top_left = 15
	bubble_style.corner_radius_top_right = 15
	bubble_style.corner_radius_bottom_left = 9
	bubble_style.corner_radius_bottom_right = 15
	bubble_style.content_margin_left = 24.0
	bubble_style.content_margin_right = 24.0
	bubble_style.content_margin_top = 16.0
	bubble_style.content_margin_bottom = 16.0
	bubble_style.shadow_color = Color(0, 0, 0, 0.72)
	bubble_style.shadow_size = 8
	speech_bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble_tail_left.visible = speaker == &"government" and not is_thought
	bubble_tail_right.visible = speaker == &"mc" and not is_thought
	bubble_tail_left.color = bubble_style.bg_color
	bubble_tail_right.color = bubble_style.bg_color
	speech_bubble.visible = true


func _mc_texture(emotion: StringName, mouth_open: bool) -> Texture2D:
	if mouth_open:
		return MC_FEARFUL_TALK if emotion == &"fearful" else MC_RESOLVED_TALK
	match emotion:
		&"stunned": return MC_STUNNED
		&"fearful": return MC_GUARDED
		&"angry", &"guilty", &"resigned": return MC_GUARDED
		_: return MC_GUARDED


func _emotion_tint(emotion: StringName) -> Color:
	match emotion:
		&"stunned": return Color(0.72, 0.79, 0.86, 1)
		&"fearful": return Color(0.76, 0.83, 0.92, 1)
		&"angry": return Color(0.96, 0.72, 0.68, 1)
		&"guilty": return Color(0.66, 0.72, 0.82, 1)
		&"resigned": return Color(0.78, 0.78, 0.78, 1)
		_: return Color.WHITE


func _advance_playback() -> void:
	_playback_index += 1
	if _playback_index >= _playback_lines.size():
		var was_recap := _playback_is_recap
		_end_playback()
		if was_recap:
			dialogue_label.text += "\n\n— End of broadcast —"
		else:
			_reveal_desk()
		return
	_show_playback_line()


func _end_playback() -> void:
	_playback_active = false
	_playback_lines.clear()
	_playback_frames.clear()
	_playback_speakers.clear()
	_playback_beats.clear()
	_playback_index = 0
	for slot in _slots:
		slot.set_highlighted(false)


func _show_directive() -> void:
	_end_playback()
	name_entry.visible = false
	speaker_portrait.visible = false
	speech_bubble.visible = false
	continue_button.visible = false
	%Directive.visible = false
	desk_dialogue.text = "Drag footage and a character token into each frame. Either can be placed first.\n\nRight-click a frame to return its footage."
	desk_dialogue.visible_characters = -1
	var mc: CharacterDef = _find_character(&"mc")
	desk_portrait.texture = mc.portrait_texture if mc != null else null
	desk_portrait.modulate = Color.WHITE
	dialogue_label.text = report.directive_text
	dialogue_label.visible_characters = -1
	%Directive.visible = true
	_set_phase(Phase.EDITING)
	_set_editing_enabled(true)


func _show_name_entry() -> void:
	_set_phase(Phase.NAME_ENTRY)
	_awaiting_name = true
	_name_line_ready = false
	_typing_response = false
	dialogue_label.visible = false
	name_prompt.text = "State the name they will use for you."
	continue_button.visible = false
	name_entry.visible = true
	_fit_dialogue_box("State the name they will use for you.", 184.0)
	name_input.text = ""
	_validate_name("")
	name_input.grab_focus()


func _validate_name(value: String) -> void:
	var session := get_node_or_null("/root/GameSession")
	var valid: bool = session != null and session.validate_player_name(value)
	name_confirm.disabled = not valid
	name_error.text = "" if valid or value.is_empty() else "1–10 letters; spaces, apostrophes and hyphens are allowed."


func _confirm_name() -> void:
	if not _awaiting_name:
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.set_player_name(name_input.text):
		_validate_name(name_input.text)
		return
	for character in report.characters:
		if character.id == &"mc":
			character.display_name = str(session.player_name)
	character_roster.setup(report.characters)
	_awaiting_name = false
	_name_line_ready = true
	name_entry.visible = false
	dialogue_label.visible = true
	dialogue_label.text = str(session.player_name) + "."
	dialogue_label.visible_characters = -1
	_update_speaker_portrait(&"mc", BroadcastDialogueBeat.make(&"mc", "", &"wary"))
	continue_button.visible = true
	_set_phase(Phase.INTERROGATION)


func _type_dialogue(text: String) -> void:
	_fit_dialogue_box(text)
	dialogue_label.visible = true
	dialogue_label.text = text
	dialogue_label.visible_characters = 0
	if phase == Phase.RESPONSE and desk_root.visible:
		desk_dialogue.text = text
		desk_dialogue.visible_characters = 0
	_typing_response = true
	_skip_response = false
	if instant_mode:
		dialogue_label.visible_characters = -1
		if phase == Phase.RESPONSE and desk_root.visible:
			desk_dialogue.visible_characters = -1
	else:
		for index in text.length():
			if _skip_response:
				dialogue_label.visible_characters = -1
				break
			dialogue_label.visible_characters = index + 1
			if phase == Phase.RESPONSE and desk_root.visible:
				desk_dialogue.visible_characters = index + 1
			var character := text.substr(index, 1)
			if not character.strip_edges().is_empty() and index % 2 == 0:
				var speaker := _playback_speakers[_playback_index] if _playback_index < _playback_speakers.size() else &"mc"
				var player := government_blip if speaker == &"government" else blip
				player.pitch_scale = randf_range(0.95, 1.045)
				player.play()
			await get_tree().create_timer(0.032).timeout
	_typing_response = false


func _fit_dialogue_box(text: String, forced_height := 0.0) -> void:
	var estimated_lines := 0
	for paragraph in text.split("\n"):
		estimated_lines += maxi(1, ceili(float(paragraph.length()) / 43.0))
	var target_height := forced_height if forced_height > 0.0 else clampf(48.0 + estimated_lines * 25.0, 88.0, 184.0)
	speech_bubble.position = Vector2(30, 548.0 - target_height)
	speech_bubble.size = Vector2(520, target_height)
	dialogue_label.custom_minimum_size = Vector2(0, target_height - 32.0)


func _apply_broadcast_typography(root_control: Control) -> void:
	var bold_font := FontVariation.new()
	bold_font.base_font = BROADCAST_FONT
	bold_font.variation_embolden = 0.85
	var pending: Array[Node] = [root_control]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Control:
			(node as Control).add_theme_font_override("font", bold_font)
		for child in node.get_children():
			pending.append(child)


func _on_continue_pressed() -> void:
	if _awaiting_name:
		return
	if _name_line_ready:
		_name_line_ready = false
		_advance_playback()
	elif _typing_response:
		_skip_response = true
	elif not _mission_response.is_empty():
		_mission_response_index += 1
		if _mission_response_index >= _mission_response.size():
			_finish_mission_response()
		else:
			_show_mission_response_line(_mission_response[_mission_response_index])
	elif _playback_active:
		_advance_playback()
	else:
		continue_pressed.emit()


func _on_slot_capacity_warning(slot: FrameSlot) -> void:
	if _playback_active:
		return
	_show_toast("%s accepts only %d character chip%s." % [slot.slot_label, slot.max_characters, "" if slot.max_characters == 1 else "s"])


func _on_slot_composition_changed(_slot: FrameSlot) -> void:
	_update_broadcast_button()
	_update_scene_reveals()


func _update_scene_reveals() -> void:
	for slot in _slots:
		if slot.current_action != null and slot.current_action.scene_image != null:
			slot.show_scene_reveal(slot.current_action.scene_image)
		else:
			slot.hide_scene_reveal()


func _update_broadcast_button() -> void:
	var ready := cause_slot.is_filled() and conflict_slot.is_filled() and outcome_slot.is_filled()
	broadcast_button.disabled = not ready or not _editing_enabled
	broadcast_button.modulate = Color.WHITE if ready and _editing_enabled else DISABLED_MODULATE
	broadcast_button.text = "BROADCAST" if not ready else "BROADCAST  ●"


func _set_editing_enabled(enabled: bool) -> void:
	_editing_enabled = enabled
	scene_frame.set_interaction_enabled(enabled)
	character_roster.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for slot in _slots:
		slot.set_interaction_enabled(enabled)
	_update_broadcast_button()


func _on_broadcast_pressed() -> void:
	if not _editing_enabled:
		return
	button_sound.play()
	_animate_broadcast_press()
	var placed: Array[ShotElement] = [cause_slot.current_shot(), conflict_slot.current_shot(), outcome_slot.current_shot()]
	var sequence := report.find_matching_sequence(placed)
	if report.report_id == &"day0_rooftop_killing":
		if sequence == report.truthful_sequence:
			for slot in _slots: slot.show_truth_rejected()
			_start_mission_response(TRUTH_RESPONSE, ResolutionResult.TRUTH_REJECTED, sequence)
		elif sequence == report.propaganda_sequence:
			for slot in _slots: slot.show_result(true)
			_start_mission_response(PROPAGANDA_RESPONSE, ResolutionResult.PROPAGANDA_ACCEPTED, sequence)
		else:
			for slot in _slots: slot.show_result(false)
			_start_mission_response(INVALID_RESPONSE, ResolutionResult.INVALID, null)
		return
	var matched := sequence != null
	for slot in _slots: slot.show_result(matched)
	_show_toast(sequence.headline if matched else report.mismatch_line)
	broadcast_resolved.emit(sequence, matched)


func _start_mission_response(lines: Array[String], result: ResolutionResult, sequence: BroadcastSequence) -> void:
	_set_phase(Phase.RESPONSE)
	_mission_response = lines.duplicate()
	_mission_response_index = 0
	_pending_result = result
	_pending_sequence = sequence
	_set_editing_enabled(false)
	%Directive.visible = false
	continue_button.visible = true
	desk_continue_button.visible = true
	var mc := _find_character(&"mc")
	desk_portrait.texture = mc.portrait_texture if mc != null else null
	_update_speaker_portrait(&"mc", BroadcastDialogueBeat.make(&"mc", "", &"guilty"))
	_show_mission_response_line(lines[0])
	day0_resolution.emit(result)
	broadcast_resolved.emit(sequence, sequence != null)


func _show_mission_response_line(text: String) -> void:
	dialogue_label.add_theme_font_size_override("font_size", 18)
	_type_dialogue(text)


func _finish_mission_response() -> void:
	_mission_response.clear()
	_mission_response_index = 0
	desk_continue_button.visible = false
	if _pending_result == ResolutionResult.PROPAGANDA_ACCEPTED and _pending_sequence != null:
		var accepted := _pending_sequence
		var session := get_node_or_null("/root/GameSession")
		if session != null:
			session.set_pending_broadcast(report.report_id, accepted)
		_pending_sequence = null
		_set_phase(Phase.NEWS_HANDOFF)
		if use_news_broadcast_scene:
			var transition_service := get_node_or_null("/root/SceneTransition")
			if transition_service != null:
				transition_service.transition_to("res://scenes/gameplay/news_broadcast.tscn", false)
			return
		_start_playback(accepted)
		return
	_pending_sequence = null
	speech_bubble.visible = false
	%Directive.visible = true
	continue_button.visible = false
	_set_phase(Phase.EDITING)
	_set_editing_enabled(true)


func _start_playback(sequence: BroadcastSequence) -> void:
	_playback_is_recap = true
	var speakers: Array[StringName] = []
	_begin_playback(sequence.broadcast_lines, sequence.broadcast_line_frames, speakers)


func _show_toast(text: String) -> void:
	%Toast.text = text
	%Toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(%Toast, "modulate:a", 0.0, 0.35)


func _on_footage_ejected(_action: ActionDef) -> void:
	eject_sound.play()


func _animate_broadcast_hover(active: bool) -> void:
	if broadcast_button.disabled:
		return
	broadcast_button.pivot_offset = broadcast_button.size * 0.5
	create_tween().tween_property(broadcast_button, "scale", Vector2(1.035, 1.035) if active else Vector2.ONE, 0.1)


func _animate_broadcast_press() -> void:
	broadcast_button.pivot_offset = broadcast_button.size * 0.5
	var tween := create_tween()
	tween.tween_property(broadcast_button, "scale", Vector2(0.95, 0.9), 0.06)
	tween.tween_property(broadcast_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _find_character(id: StringName) -> CharacterDef:
	if report == null:
		return null
	for character in report.characters:
		if character.id == id:
			return character
	return null
