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
## Dim but still clearly visible — the button art is mostly dark background,
## so the old near-transparent value (0.48 alpha) made it look like an empty
## void instead of an unlit sign.
const DISABLED_MODULATE := Color(0.55, 0.58, 0.62, 0.85)
const GLOW_MODULATE := Color(1.25, 1.28, 1.4, 1)
const MC_NEUTRAL := preload("res://assets/art/ui/broadcast_v2/interrogation/mc-neutral.png")
const MC_DIRTY := preload("res://assets/art/ui/broadcast_v2/interrogation/mc-dirty.png")
const MC_STUNNED := MC_NEUTRAL
const MC_GUARDED := MC_NEUTRAL
const MC_FEARFUL_TALK := MC_DIRTY
const MC_RESOLVED_TALK := MC_DIRTY
const GOVERNMENT_SILHOUETTE := preload("res://assets/art/ui/broadcast_v2/interrogation/government.png")
const BROADCAST_FONT := preload("res://assets/fonts/Basic-Regular.ttf")
const NEWSLETTER_FONT := preload("res://assets/fonts/Newsreader.ttf")

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
## Generic, data-driven pipeline for any report other than day0_rooftop_killing.
## Kept fully separate from the _mission_response/_pending_* state above so the
## untouched Day 0 branch can never interact with it.
var _report_chain: Array[BroadcastReport] = []
var _chain_index := -1
var _chain_results: Array = []
var _chain_mission_lines: Array[String] = []
var _chain_mission_index := 0
var _chain_pending_sequence: BroadcastSequence
var _chain_pending_report: BroadcastReport
## Parallel to _playback_lines during a combined recap: index into _chain_results
## (or -1 for bridge/opening lines) so each line can restore its own frame art.
var _playback_owners: Array[int] = []
var _typing_response := false
var _skip_response := false
var _editing_enabled := false
## Loops while the button is ready to press, gently brightening it above full
## white so the neon sign art actually reads as lit rather than just undimmed.
var _broadcast_glow_tween: Tween
var _awaiting_name := false
var _name_line_ready := false
var _elapsed := 0.0
var _current_speaker: StringName = &""
var _current_emotion: StringName = &"neutral"
var _active_transcript_label: Label
var _transcript_scroll_internal := false
var _transcript_follow_latest := true
var _is_day1_context := false

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
@onready var desk_continue_button: Button = %DeskContinueButton
@onready var conversation_scroll: ScrollContainer = %ConversationScroll
@onready var conversation_history: VBoxContainer = %ConversationHistory
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
@onready var call_disconnect: AudioStreamPlayer = $Audio/CallDisconnect
@onready var name_entry: VBoxContainer = %NameEntry
@onready var name_prompt: Label = %NamePrompt
@onready var name_input: LineEdit = %NameInput
@onready var name_confirm: Button = %NameConfirm
@onready var name_error: Label = %NameError


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("broadcast")
		_is_day1_context = session.broadcast_context == &"day1"
	_slots = [cause_slot, conflict_slot, outcome_slot]
	_normalize_frame_geometry()
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
	conversation_scroll.gui_input.connect(_on_transcript_scroll_input)
	conversation_scroll.get_v_scroll_bar().gui_input.connect(_on_transcript_scroll_input)
	conversation_history.minimum_size_changed.connect(_on_transcript_content_resized)
	_apply_broadcast_typography(desk_root)
	if tv_hum.stream is AudioStreamWAV:
		(tv_hum.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	name_entry.visible = false
	_reparent_name_entry_to_left_panel()
	if _is_day1_context:
		load_report_chain(BroadcastDemoData.day1_reports())
	else:
		load_report(BroadcastDemoData.rooftop_killing_report())


## Interior of each frame's painted border in broadcast-console-base-v4.png,
## measured in viewport space. The borders are intentionally non-uniform widths,
## so each slot is snapped to its own box; the footage then fills the frame with
## no gap while the bright painted border stays visible around it.
const FRAME_RECTS := [
	Rect2(394, 113, 272, 189),
	Rect2(684, 113, 258, 189),
	Rect2(959, 113, 255, 189),
]


func _normalize_frame_geometry() -> void:
	for index in _slots.size():
		var rect: Rect2 = FRAME_RECTS[index]
		_slots[index].position = rect.position
		_slots[index].size = rect.size
		_slots[index].scale = Vector2.ONE


func _process(delta: float) -> void:
	_elapsed += delta
	if desk_portrait.visible:
		var breath := 1.0 + sin(_elapsed * 2.1) * 0.007
		desk_portrait.scale = Vector2(breath, breath)
		if _current_speaker == &"mc":
			var mouth_open := _typing_response and int(_elapsed * 9.0) % 2 == 0
			desk_portrait.texture = _mc_texture(_current_emotion, mouth_open)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and conversation_scroll.visible and conversation_scroll.get_global_rect().has_point(event.position):
		return
	if event.is_action_pressed(&"interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if phase in [Phase.INTERROGATION, Phase.NAME_ENTRY, Phase.RESPONSE]:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()


func _set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(phase)


func load_report(p_report: BroadcastReport) -> void:
	_report_chain = [p_report]
	_chain_index = 0
	_chain_results = []
	_load_report_body(p_report)


## Loads the first report in a sequence; solving the last one plays one combined
## recap covering every report's broadcast_lines back to back. See _finish_chain_mission_response.
func load_report_chain(reports: Array[BroadcastReport]) -> void:
	_report_chain = reports
	_chain_index = 0
	_chain_results = []
	_load_report_body(reports[0])


func _load_report_body(p_report: BroadcastReport) -> void:
	report = p_report
	_clear_transcript()
	_mission_response.clear()
	_pending_sequence = null
	_typing_response = false
	_awaiting_name = false
	_name_line_ready = false
	name_entry.visible = false
	conversation_scroll.visible = true
	# Clear old slots before replacing the camera inventory. Slot cleanup emits
	# footage-return signals which must not override the new report selection.
	for slot in _slots:
		slot.clear()
		slot.set_default_max_characters(report.max_characters_per_frame)
	scene_frame.setup(report.available_actions)
	character_roster.setup(report.characters)
	_set_editing_enabled(false)
	speaker_portrait.visible = false
	if report.report_id == &"day0_rooftop_killing":
		_start_day0_cinematic()
	else:
		_show_desk_immediately()
		_start_intro()
	_update_broadcast_button()


## Advances to the next report in _report_chain without replaying the desk's
## reveal animation — the hardware is already visible; only its contents change.
func _load_next_chain_report() -> void:
	_chain_index += 1
	var next_report: BroadcastReport = _report_chain[_chain_index]
	report = next_report
	for slot in _slots:
		slot.clear()
		slot.set_default_max_characters(next_report.max_characters_per_frame)
	scene_frame.setup(next_report.available_actions)
	character_roster.setup(next_report.characters)
	_set_editing_enabled(false)
	speaker_portrait.visible = false
	_start_intro()
	_update_broadcast_button()


func _start_day0_cinematic() -> void:
	_set_phase(Phase.FADE_IN)
	desk_root.visible = true
	desk_root.position = Vector2.ZERO
	desk_root.modulate.a = 1.0
	cinema_rig.visible = false
	conversation_scroll.visible = true
	desk_continue_button.visible = true
	%TranscriptTitle.visible = true
	%Directive.visible = false
	for locked_piece in [cause_slot, conflict_slot, outcome_slot, scene_frame, character_roster, broadcast_button]:
		locked_piece.modulate.a = 0.22
	fade.visible = true
	fade.color.a = 1.0
	room_dimmer.color.a = 0.12
	crt_material.set_shader_parameter("boot_progress", 1.0)
	if instant_mode:
		fade.color.a = 0.0
		room_dimmer.color.a = 0.12
		_start_intro()
		return
	var intro := create_tween()
	intro.tween_property(fade, "color:a", 0.0, 0.6)
	intro.parallel().tween_property(room_dimmer, "color:a", 0.12, 0.35)
	await intro.finished
	tv_power.play()
	tv_hum.play()
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
	# The interrogation already lives in the desk's left panel. Completing it
	# only unlocks the evidence tools; there is no second room or UI handoff.
	desk_root.visible = true
	desk_root.modulate.a = 1.0
	desk_root.position = Vector2.ZERO
	desk_continue_button.visible = true
	desk_continue_button.disabled = true
	continue_button.visible = false
	for hidden_piece in [cause_slot, conflict_slot, outcome_slot, scene_frame, character_roster, broadcast_button]:
		hidden_piece.modulate.a = 0.0
	if not instant_mode:
		await _drop_desk_components()
	else:
		for visible_piece in [cause_slot, conflict_slot, outcome_slot, scene_frame, character_roster, broadcast_button]:
			visible_piece.modulate.a = 1.0
	_show_directive()


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
	desk_continue_button.visible = true
	desk_continue_button.disabled = false
	_begin_playback(lines, frames, report.intro_speakers)


func _begin_playback(lines: Array[String], frames: Array[int], speakers: Array[StringName], owners: Array[int] = []) -> void:
	# Duplicate rather than alias: _end_playback() clears _playback_lines in place,
	# and callers like _start_intro() pass report.intro_lines directly — without a
	# copy that clear() would permanently wipe the report's own data on first use.
	_playback_lines = lines.duplicate()
	_playback_frames = frames.duplicate()
	_playback_speakers = speakers.duplicate()
	_playback_owners = owners.duplicate()
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
	if not _playback_owners.is_empty() and _playback_index < _playback_owners.size():
		_apply_chain_recap_visuals(_playback_owners[_playback_index])
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
		desk_portrait.visible = false
		return
	var texture: Texture2D
	if speaker == &"mc":
		texture = _mc_texture(_current_emotion, false)
	elif speaker == &"government":
		texture = report.speaker_portraits.get(speaker, GOVERNMENT_SILHOUETTE)
	else:
		texture = report.speaker_portraits.get(speaker)
	if texture == null:
		speaker_portrait.visible = false
		desk_portrait.visible = false
		return
	speaker_portrait.texture = texture
	speaker_portrait.visible = false
	speaker_portrait.modulate = Color.WHITE
	desk_portrait.texture = texture
	desk_portrait.visible = true
	desk_portrait.modulate = speaker_portrait.modulate
	desk_portrait.pivot_offset = desk_portrait.size * 0.5
	screen_status.text = "SECURE CHANNEL // GOV" if speaker == &"government" else "SUBJECT // G-03S-93"


func _mc_texture(emotion: StringName, mouth_open: bool) -> Texture2D:
	if mouth_open and emotion == &"dirty":
		return MC_DIRTY
	match emotion:
		&"dirty", &"fearful", &"angry", &"guilty", &"resigned": return MC_DIRTY
		_: return MC_NEUTRAL


func _emotion_tint(emotion: StringName) -> Color:
	match emotion:
		&"stunned": return Color(0.72, 0.79, 0.86, 1)
		&"fearful": return Color(0.76, 0.83, 0.92, 1)
		&"angry": return Color(0.96, 0.72, 0.68, 1)
		&"guilty": return Color(0.66, 0.72, 0.82, 1)
		&"resigned": return Color(0.78, 0.78, 0.78, 1)
		_: return Color.WHITE


func _advance_playback() -> void:
	if not _playback_is_recap and report != null and _playback_index == report.disconnect_after_intro_line:
		call_disconnect.play()
	_playback_index += 1
	if _playback_index >= _playback_lines.size():
		var was_recap := _playback_is_recap
		_end_playback()
		if was_recap:
			dialogue_label.text += "\n\n— End of broadcast —"
			if _is_day1_context:
				_finish_day1_broadcast.call_deferred()
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
	_playback_owners.clear()
	_playback_index = 0
	for slot in _slots:
		slot.set_highlighted(false)


func _show_directive() -> void:
	_end_playback()
	name_entry.visible = false
	speaker_portrait.visible = false
	speech_bubble.visible = false
	continue_button.visible = false
	desk_continue_button.visible = true
	desk_continue_button.disabled = true
	%Directive.visible = false
	var mc: CharacterDef = _find_character(&"mc")
	desk_portrait.texture = mc.portrait_texture if mc != null else null
	desk_portrait.modulate = Color.WHITE
	dialogue_label.text = report.directive_text
	dialogue_label.visible_characters = -1
	_append_transcript_entry("OBJECTIVE", report.directive_text, &"system", true)
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
	desk_continue_button.visible = true
	desk_continue_button.disabled = true
	conversation_scroll.visible = false
	name_entry.visible = true
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
	conversation_scroll.visible = true
	dialogue_label.visible = true
	dialogue_label.text = str(session.player_name) + "."
	dialogue_label.visible_characters = -1
	_update_speaker_portrait(&"mc", BroadcastDialogueBeat.make(&"mc", "", &"wary"))
	_append_transcript_entry(_speaker_caption(&"mc"), dialogue_label.text, &"mc", true)
	desk_continue_button.visible = true
	desk_continue_button.disabled = false
	_set_phase(Phase.INTERROGATION)


func _type_dialogue(text: String) -> void:
	dialogue_label.visible = true
	dialogue_label.text = text
	dialogue_label.visible_characters = 0
	_active_transcript_label = null
	if not _playback_is_recap:
		_active_transcript_label = _append_transcript_entry(_speaker_caption(_current_speaker), text, _current_speaker)
	_typing_response = true
	_skip_response = false
	if instant_mode:
		dialogue_label.visible_characters = -1
		if _active_transcript_label != null:
			_active_transcript_label.visible_characters = -1
		_scroll_transcript_to_latest.call_deferred()
	else:
		for index in text.length():
			if _skip_response:
				dialogue_label.visible_characters = -1
				if _active_transcript_label != null:
					_active_transcript_label.visible_characters = -1
				_scroll_transcript_to_latest.call_deferred()
				break
			dialogue_label.visible_characters = index + 1
			if _active_transcript_label != null:
				_active_transcript_label.visible_characters = index + 1
			if _transcript_follow_latest and index % 4 == 0:
				_scroll_transcript_to_latest.call_deferred()
			var character := text.substr(index, 1)
			if not character.strip_edges().is_empty() and index % 2 == 0:
				var speaker := _playback_speakers[_playback_index] if _playback_index < _playback_speakers.size() else &"mc"
				var player := government_blip if speaker == &"government" else blip
				player.pitch_scale = randf_range(0.95, 1.045)
				player.play()
			await get_tree().create_timer(0.032).timeout
	# Always leave both representations fully revealed. This makes the first
	# E/click a deterministic "complete line" action instead of truncating it.
	dialogue_label.visible_characters = -1
	if _active_transcript_label != null:
		_active_transcript_label.visible_characters = -1
	_typing_response = false
	_scroll_transcript_to_latest.call_deferred()


func _reparent_name_entry_to_left_panel() -> void:
	name_entry.reparent(desk_root)
	name_entry.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	name_entry.position = Vector2(52, 386)
	name_entry.size = Vector2(278, 194)
	name_entry.custom_minimum_size = Vector2(278, 194)
	name_entry.z_index = 5
	name_prompt.add_theme_color_override("font_color", Color.WHITE)
	name_prompt.add_theme_font_override("font", NEWSLETTER_FONT)
	name_input.add_theme_font_override("font", NEWSLETTER_FONT)
	name_confirm.add_theme_font_override("font", NEWSLETTER_FONT)
	name_error.add_theme_color_override("font_color", Color(0.58, 0.08, 0.055, 1))
	name_error.add_theme_font_override("font", NEWSLETTER_FONT)


func _clear_transcript() -> void:
	if not is_instance_valid(conversation_history):
		return
	for child in conversation_history.get_children():
		child.free()
	_active_transcript_label = null
	_transcript_follow_latest = true
	conversation_scroll.scroll_vertical = 0


func _speaker_caption(speaker: StringName) -> String:
	if speaker == &"government":
		return "GOVERNMENT"
	if speaker == &"mc":
		var session := get_node_or_null("/root/GameSession")
		return str(session.player_name).to_upper() if session != null and not str(session.player_name).is_empty() else "SUBJECT"
	return "SYSTEM"


func _append_transcript_entry(caption: String, text: String, speaker: StringName, complete := false) -> Label:
	var was_following := _transcript_follow_latest or _transcript_is_at_bottom()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0431373, 0.113725, 0.301961, 0.97)
	style.border_color = Color(0.133333, 0.839216, 1.0, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 9.0
	panel.add_theme_stylebox_override("panel", style)
	conversation_history.add_child(panel)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_theme_constant_override("separation", 2)
	panel.add_child(stack)
	var header := Label.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_override("font", NEWSLETTER_FONT)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color.WHITE)
	header.text = caption
	stack.add_child(header)
	var body := Label.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("font", NEWSLETTER_FONT)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color.WHITE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = text
	body.visible_characters = -1 if complete else 0
	stack.add_child(body)
	if was_following:
		_transcript_follow_latest = true
		_scroll_transcript_to_latest.call_deferred()
	return body


func _transcript_is_at_bottom() -> bool:
	var bar := conversation_scroll.get_v_scroll_bar()
	return bar.value >= maxf(0.0, bar.max_value - bar.page - 6.0)


func _scroll_transcript_to_latest() -> void:
	if not _transcript_follow_latest:
		return
	var bar := conversation_scroll.get_v_scroll_bar()
	_transcript_scroll_internal = true
	bar.value = maxf(0.0, bar.max_value - bar.page)
	_transcript_scroll_internal = false


func _on_transcript_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_refresh_transcript_follow.call_deferred()


func _refresh_transcript_follow() -> void:
	_transcript_follow_latest = _transcript_is_at_bottom()


func _on_transcript_content_resized() -> void:
	if _transcript_follow_latest:
		_scroll_transcript_to_latest.call_deferred()


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
	elif not _chain_mission_lines.is_empty():
		_chain_mission_index += 1
		if _chain_mission_index >= _chain_mission_lines.size():
			_finish_chain_mission_response()
		else:
			_show_mission_response_line(_chain_mission_lines[_chain_mission_index])
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
	# Rendering the placed scene's image (and its caption) is already fully
	# handled by FrameSlot._refresh_visual() on every drop/place/remove — no
	# separate reveal pass needed here (an older duplicate of that logic used
	# to live here and would silently re-hide the scene caption).


func _update_broadcast_button() -> void:
	var ready := cause_slot.is_filled() and conflict_slot.is_filled() and outcome_slot.is_filled()
	var active := ready and _editing_enabled
	broadcast_button.disabled = not active
	if active:
		_start_broadcast_glow()
	else:
		_stop_broadcast_glow()
	# The authored button plate already contains the label. Leaving the Godot
	# button text empty prevents a second word from covering the painted one.
	broadcast_button.text = ""


## Slow brightness pulse so the neon sign art visibly reads as "lit" once the
## report is ready to broadcast, instead of just sitting at flat full white.
func _start_broadcast_glow() -> void:
	if _broadcast_glow_tween != null and _broadcast_glow_tween.is_valid():
		return
	broadcast_button.modulate = Color.WHITE
	_broadcast_glow_tween = create_tween().set_loops()
	_broadcast_glow_tween.tween_property(broadcast_button, "modulate", GLOW_MODULATE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_broadcast_glow_tween.tween_property(broadcast_button, "modulate", Color.WHITE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_broadcast_glow() -> void:
	if _broadcast_glow_tween != null and _broadcast_glow_tween.is_valid():
		_broadcast_glow_tween.kill()
	_broadcast_glow_tween = null
	broadcast_button.modulate = DISABLED_MODULATE


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
	_on_chain_broadcast_pressed(sequence)


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
	desk_continue_button.disabled = false
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
	desk_continue_button.visible = true
	desk_continue_button.disabled = true
	if _pending_result == ResolutionResult.PROPAGANDA_ACCEPTED and _pending_sequence != null:
		var accepted := _pending_sequence
		var session := get_node_or_null("/root/GameSession")
		if session != null:
			session.set_pending_broadcast(report.report_id, accepted)
			if report.report_id == &"day0_rooftop_killing" and session.has_method(&"set_day0_report_route"):
				session.set_day0_report_route(&"propaganda")
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


## Generic (non-day0) broadcast resolution: driven entirely by sequence.reaction_lines,
## sequence.broadcast_lines and report.mismatch_line instead of hardcoded report_id checks.
func _on_chain_broadcast_pressed(sequence: BroadcastSequence) -> void:
	var airs := sequence != null and not sequence.broadcast_lines.is_empty()
	for slot in _slots:
		if airs:
			slot.show_result(true)
		elif sequence != null:
			slot.show_truth_rejected()
		else:
			slot.show_result(false)
	if sequence == null:
		_start_chain_mismatch()
	else:
		_start_chain_mission_response(sequence)


func _start_chain_mismatch() -> void:
	_chain_pending_sequence = null
	_chain_pending_report = report
	broadcast_resolved.emit(null, false)
	_begin_chain_response([report.mismatch_line])


func _start_chain_mission_response(sequence: BroadcastSequence) -> void:
	_chain_pending_sequence = sequence
	_chain_pending_report = report
	broadcast_resolved.emit(sequence, true)
	if sequence.reaction_lines.is_empty():
		_finish_chain_mission_response()
		return
	_begin_chain_response(sequence.reaction_lines)


func _begin_chain_response(lines: Array[String]) -> void:
	_set_phase(Phase.RESPONSE)
	_chain_mission_lines = lines.duplicate()
	_chain_mission_index = 0
	_set_editing_enabled(false)
	%Directive.visible = false
	continue_button.visible = true
	desk_continue_button.visible = true
	desk_continue_button.disabled = false
	var mc := _find_character(&"mc")
	desk_portrait.texture = mc.portrait_texture if mc != null else null
	_update_speaker_portrait(&"mc", BroadcastDialogueBeat.make(&"mc", "", &"neutral"))
	_show_mission_response_line(_chain_mission_lines[0])


func _finish_chain_mission_response() -> void:
	_chain_mission_lines.clear()
	_chain_mission_index = 0
	desk_continue_button.visible = true
	desk_continue_button.disabled = true
	var sequence := _chain_pending_sequence
	var finishing_report := _chain_pending_report
	_chain_pending_sequence = null
	_chain_pending_report = null
	if sequence == null or sequence.broadcast_lines.is_empty():
		# No-match, or a matched-but-non-airing route (e.g. a refusal) — try again.
		speech_bubble.visible = false
		%Directive.visible = true
		continue_button.visible = false
		_set_phase(Phase.EDITING)
		_set_editing_enabled(true)
		return
	_record_day1_route(finishing_report, sequence)
	_chain_results.append({"report": finishing_report, "sequence": sequence})
	if _chain_index + 1 < _report_chain.size():
		_load_next_chain_report()
	elif _is_day1_context and use_news_broadcast_scene:
		_start_day1_news_handoff()
	else:
		_start_combined_recap()


func _start_day1_news_handoff() -> void:
	_set_phase(Phase.NEWS_HANDOFF)
	_set_editing_enabled(false)
	continue_button.visible = false
	desk_continue_button.visible = false
	var transition_service := get_node_or_null("/root/SceneTransition")
	if transition_service != null and not transition_service.busy:
		transition_service.transition_to("res://scenes/gameplay/news_broadcast.tscn", false)


## Plays every solved report's broadcast_lines back to back as one "Today's News"
## segment, restoring each report's own frame art as playback crosses into its lines.
func _start_combined_recap() -> void:
	_playback_is_recap = true
	var lines: Array[String] = ["And now, for Today's News."]
	var frames: Array[int] = [-1]
	var owners: Array[int] = [-1]
	for index in _chain_results.size():
		var entry: Dictionary = _chain_results[index]
		var sequence: BroadcastSequence = entry["sequence"]
		if index > 0:
			lines.append("Now, for our other news of the day.")
			frames.append(-1)
			owners.append(-1)
		for line_index in sequence.broadcast_lines.size():
			lines.append(sequence.broadcast_lines[line_index])
			frames.append(sequence.broadcast_line_frames[line_index] if line_index < sequence.broadcast_line_frames.size() else -1)
			owners.append(index)
	speaker_portrait.visible = false
	desk_portrait.visible = false
	_begin_playback(lines, frames, [], owners)


func _apply_chain_recap_visuals(owner_index: int) -> void:
	if owner_index < 0 or owner_index >= _chain_results.size():
		return
	var entry: Dictionary = _chain_results[owner_index]
	var sequence: BroadcastSequence = entry["sequence"]
	var shots := sequence.shots()
	for index in _slots.size():
		var action := shots[index].action
		if action != null and action.scene_image != null:
			_slots[index].show_scene_reveal(action.scene_image)


func _record_day1_route(solved_report: BroadcastReport, solved_sequence: BroadcastSequence) -> void:
	if not _is_day1_context or solved_report == null:
		return
	var route := &""
	if solved_sequence == solved_report.truthful_sequence:
		route = &"truthful"
	elif solved_sequence == solved_report.propaganda_sequence:
		route = &"propaganda"
	if route == &"":
		return
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"set_day1_report_route"):
		session.set_day1_report_route(solved_report.report_id, route)


func _finish_day1_broadcast() -> void:
	_set_phase(Phase.NEWS_HANDOFF)
	_set_editing_enabled(false)
	await get_tree().create_timer(1.15).timeout
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day1_ending")
	var transition_service := get_node_or_null("/root/SceneTransition")
	if transition_service != null and not transition_service.busy:
		transition_service.transition_to("res://scenes/Day 1/Side Scroll Section/Day 1 ending.tscn", false)


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
