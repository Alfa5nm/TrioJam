class_name BroadcastInterface
extends Control

signal broadcast_resolved(sequence: BroadcastSequence, matched: bool)
signal continue_pressed

var report: BroadcastReport

var _slots: Array[FrameSlot] = []

var _playback_lines: Array[String] = []
var _playback_frames: Array[int] = []
var _playback_index := 0
var _playback_active := false

@onready var scene_frame: SceneFrame = %SceneFrame
@onready var scene_button: Button = %SceneCycleButton
@onready var character_roster: CharacterRoster = %CharacterRoster
@onready var broadcast_button: Button = %BroadcastButton
@onready var continue_button: Button = %ContinueButton
@onready var dialogue_label: Label = %DialogueLabel
@onready var portrait_label: Label = %PortraitLabel
@onready var cause_slot: FrameSlot = %CauseSlot
@onready var conflict_slot: FrameSlot = %ConflictSlot
@onready var outcome_slot: FrameSlot = %OutcomeSlot


func _ready() -> void:
	_slots = [cause_slot, conflict_slot, outcome_slot]
	for slot in _slots:
		slot.composition_changed.connect(_on_slot_composition_changed)
	scene_button.pressed.connect(scene_frame.cycle_scene)
	broadcast_button.pressed.connect(_on_broadcast_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	load_report(BroadcastDemoData.rooftop_killing_report())


func load_report(p_report: BroadcastReport) -> void:
	report = p_report
	scene_frame.setup(report.available_actions)
	character_roster.setup(report.characters)
	for slot in _slots:
		slot.clear()
	_end_playback()
	dialogue_label.text = report.directive_text
	portrait_label.text = report.characters[0].display_name.substr(0, 1) if not report.characters.is_empty() else "?"
	_update_broadcast_button()


func _on_slot_composition_changed(_slot: FrameSlot) -> void:
	_update_broadcast_button()


func _update_broadcast_button() -> void:
	broadcast_button.disabled = not (cause_slot.is_filled() and conflict_slot.is_filled() and outcome_slot.is_filled())


func _on_broadcast_pressed() -> void:
	var placed: Array[ShotElement] = [cause_slot.current_shot(), conflict_slot.current_shot(), outcome_slot.current_shot()]
	var sequence := report.find_matching_sequence(placed)
	var matched := sequence != null
	for slot in _slots:
		slot.show_result(matched)
	if matched and not sequence.broadcast_lines.is_empty():
		_start_playback(sequence)
	else:
		dialogue_label.text = sequence.headline if matched else "The story doesn't hold together. Try a different arrangement."
	broadcast_resolved.emit(sequence, matched)


func _start_playback(sequence: BroadcastSequence) -> void:
	_playback_lines = sequence.broadcast_lines
	_playback_frames = sequence.broadcast_line_frames
	_playback_index = 0
	_playback_active = true
	_show_playback_line()


func _show_playback_line() -> void:
	dialogue_label.text = _playback_lines[_playback_index]
	var highlighted_index := _playback_frames[_playback_index] if _playback_index < _playback_frames.size() else -1
	for i in _slots.size():
		_slots[i].set_highlighted(i == highlighted_index)


func _advance_playback() -> void:
	_playback_index += 1
	if _playback_index >= _playback_lines.size():
		_end_playback()
		dialogue_label.text += "\n\n— End of broadcast —"
		return
	_show_playback_line()


func _end_playback() -> void:
	_playback_active = false
	_playback_lines = []
	_playback_frames = []
	_playback_index = 0
	for slot in _slots:
		slot.set_highlighted(false)


func _on_continue_pressed() -> void:
	if _playback_active:
		_advance_playback()
	else:
		continue_pressed.emit()
