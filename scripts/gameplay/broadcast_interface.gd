class_name BroadcastInterface
extends Control

signal broadcast_resolved(sequence: BroadcastSequence, matched: bool)
signal continue_pressed

var report: BroadcastReport

var _slots: Array[FrameSlot] = []

var _playback_lines: Array[String] = []
var _playback_frames: Array[int] = []
var _playback_speakers: Array[StringName] = []
var _playback_index := 0
var _playback_active := false
var _playback_is_recap := false

const DISABLED_MODULATE := Color(1, 1, 1, 0.45)

@onready var scene_frame: SceneFrame = %SceneFrame
@onready var character_roster: CharacterRoster = %CharacterRoster
@onready var broadcast_button: TextureButton = %BroadcastButton
@onready var continue_button: TextureButton = %ContinueButton
@onready var dialogue_label: Label = %DialogueLabel
@onready var speaker_portrait: TextureRect = %SpeakerPortrait
@onready var cause_slot: FrameSlot = %CauseSlot
@onready var conflict_slot: FrameSlot = %ConflictSlot
@onready var outcome_slot: FrameSlot = %OutcomeSlot


func _ready() -> void:
	_slots = [cause_slot, conflict_slot, outcome_slot]
	for slot in _slots:
		slot.composition_changed.connect(_on_slot_composition_changed)
		slot.capacity_warning.connect(_on_slot_capacity_warning)
	broadcast_button.pressed.connect(_on_broadcast_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	load_report(BroadcastDemoData.rooftop_killing_report())


func load_report(p_report: BroadcastReport) -> void:
	report = p_report
	scene_frame.setup(report.available_actions)
	character_roster.setup(report.characters)
	for slot in _slots:
		slot.clear()
		slot.max_characters = report.max_characters_per_frame
	speaker_portrait.visible = false
	_start_intro()
	_update_broadcast_button()


func _on_slot_capacity_warning(slot: FrameSlot) -> void:
	if _playback_active:
		return
	var noun := "character" if slot.max_characters == 1 else "characters"
	dialogue_label.text = "This frame can only hold %d %s." % [slot.max_characters, noun]


func _on_slot_composition_changed(_slot: FrameSlot) -> void:
	_update_broadcast_button()
	_update_scene_reveals()


func _update_scene_reveals() -> void:
	for i in _slots.size():
		var slot := _slots[i]
		var shot := slot.current_shot()
		if _is_slot_correct(i, shot) and shot.action.scene_image != null:
			slot.show_scene_reveal(shot.action.scene_image)
		else:
			slot.hide_scene_reveal()


func _is_slot_correct(index: int, shot: ShotElement) -> bool:
	if report == null or not shot.is_complete():
		return false
	if report.truthful_sequence != null and report.truthful_sequence.matches_slot(index, shot):
		return true
	if report.propaganda_sequence != null and report.propaganda_sequence.matches_slot(index, shot):
		return true
	return false


func _update_broadcast_button() -> void:
	var ready_to_broadcast := cause_slot.is_filled() and conflict_slot.is_filled() and outcome_slot.is_filled()
	broadcast_button.disabled = not ready_to_broadcast
	broadcast_button.modulate = Color.WHITE if ready_to_broadcast else DISABLED_MODULATE


func _on_broadcast_pressed() -> void:
	var placed: Array[ShotElement] = [cause_slot.current_shot(), conflict_slot.current_shot(), outcome_slot.current_shot()]
	var sequence := report.find_matching_sequence(placed)
	var matched := sequence != null
	for slot in _slots:
		slot.show_result(matched)
	if matched and (not sequence.reaction_lines.is_empty() or not sequence.broadcast_lines.is_empty()):
		_start_recap(sequence)
	elif matched:
		dialogue_label.text = sequence.headline
	else:
		dialogue_label.text = report.mismatch_line
	broadcast_resolved.emit(sequence, matched)


func _start_intro() -> void:
	var lines := report.intro_lines if not report.intro_lines.is_empty() else [report.directive_text]
	var frames: Array[int] = []
	for _line in lines:
		frames.append(-1)
	_playback_is_recap = false
	_begin_playback(lines, frames, report.intro_speakers)


func _start_recap(sequence: BroadcastSequence) -> void:
	var lines: Array[String] = []
	var frames: Array[int] = []
	for line in sequence.reaction_lines:
		lines.append(line)
		frames.append(-1)
	for i in sequence.broadcast_lines.size():
		lines.append(sequence.broadcast_lines[i])
		frames.append(sequence.broadcast_line_frames[i] if i < sequence.broadcast_line_frames.size() else -1)
	_playback_is_recap = not sequence.broadcast_lines.is_empty()
	_begin_playback(lines, frames, [])


func _begin_playback(lines: Array[String], frames: Array[int], speakers: Array[StringName]) -> void:
	_playback_lines = lines
	_playback_frames = frames
	_playback_speakers = speakers
	_playback_index = 0
	_playback_active = true
	_show_playback_line()


func _show_playback_line() -> void:
	dialogue_label.text = _playback_lines[_playback_index]
	var highlighted_index := _playback_frames[_playback_index] if _playback_index < _playback_frames.size() else -1
	for i in _slots.size():
		_slots[i].set_highlighted(i == highlighted_index)
	var speaker: StringName = _playback_speakers[_playback_index] if _playback_index < _playback_speakers.size() else &""
	_update_speaker_portrait(speaker)


func _update_speaker_portrait(speaker: StringName) -> void:
	if speaker == &"" or report == null:
		return
	var texture: Texture2D = report.speaker_portraits.get(speaker)
	if texture == null:
		speaker_portrait.visible = false
		return
	speaker_portrait.texture = texture
	speaker_portrait.visible = true


func _advance_playback() -> void:
	_playback_index += 1
	if _playback_index >= _playback_lines.size():
		var was_recap := _playback_is_recap
		_end_playback()
		if was_recap:
			dialogue_label.text += "\n\n— End of broadcast —"
		return
	_show_playback_line()


func _end_playback() -> void:
	_playback_active = false
	_playback_lines = []
	_playback_frames = []
	_playback_speakers = []
	_playback_index = 0
	for slot in _slots:
		slot.set_highlighted(false)


func _on_continue_pressed() -> void:
	if _playback_active:
		_advance_playback()
	else:
		continue_pressed.emit()
