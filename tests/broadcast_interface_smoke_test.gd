extends SceneTree

var failures := 0
var _last_sequence: BroadcastSequence
var _last_matched := false
var _resolved_count := 0
var _continue_signal_fired := false


func _init() -> void:
	print("SMOKE_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/gameplay/broadcast_interface.tscn") as PackedScene
	_check(packed_scene != null, "broadcast interface scene loads")
	if packed_scene == null:
		quit(1)
		return

	var ui := packed_scene.instantiate() as BroadcastInterface
	root.add_child(ui)
	for _frame in 4:
		await process_frame

	_check(ui.cause_slot != null, "cause slot exists")
	_check(ui.conflict_slot != null, "conflict slot exists")
	_check(ui.outcome_slot != null, "outcome slot exists")
	_check(ui.scene_frame != null, "scene frame exists")
	_check(ui.scene_button != null, "scene cycle button exists")
	_check(ui.character_roster != null, "character roster exists")
	_check(ui.broadcast_button != null, "broadcast button exists")

	if ui.cause_slot == null or ui.conflict_slot == null or ui.outcome_slot == null or ui.broadcast_button == null:
		ui.queue_free()
		await process_frame
		quit(failures)
		return

	ui.broadcast_resolved.connect(_on_broadcast_resolved)

	var report := BroadcastDemoData.checkpoint_killing_report()
	ui.load_report(report)
	_check(ui.broadcast_button.disabled, "broadcast disabled with 0/3 filled")

	# Scene cycle button drives the scene frame.
	_check(ui.scene_frame.current_action == null, "scene frame starts with no scene picked")
	ui.scene_button.pressed.emit()
	_check(ui.scene_frame.current_action != null, "clicking SCENE picks a scene")

	# Scene-first rule now lives on each slot directly: character drops rejected until
	# that specific slot already has a scene dropped into it.
	var soldier: CharacterDef = report.characters[0]
	var civilian: CharacterDef = report.characters[1]
	var witness: CharacterDef = report.characters[2]
	var scene_action: ActionDef = report.available_actions[0]
	var character_payload := {"type": "broadcast_character", "character": soldier}
	var scene_payload := {"type": "broadcast_scene", "action": scene_action}

	_check(
		not ui.cause_slot._can_drop_data(Vector2.ZERO, character_payload),
		"character drop rejected before a scene is dropped into this slot"
	)
	_check(
		ui.cause_slot._can_drop_data(Vector2.ZERO, scene_payload),
		"scene drop always accepted onto an empty slot"
	)
	ui.cause_slot._drop_data(Vector2.ZERO, scene_payload)
	_check(ui.cause_slot.current_action == scene_action, "slot records the dropped scene")
	_check(
		ui.cause_slot._can_drop_data(Vector2.ZERO, character_payload),
		"character drop accepted once this slot has a scene"
	)

	# 2-character cap, per slot.
	ui.cause_slot._drop_data(Vector2.ZERO, character_payload)
	ui.cause_slot._drop_data(Vector2.ZERO, {"type": "broadcast_character", "character": civilian})
	_check(ui.cause_slot.current_characters.size() == 2, "slot holds 2 characters")
	_check(
		not ui.cause_slot._can_drop_data(Vector2.ZERO, {"type": "broadcast_character", "character": witness}),
		"a 3rd character is rejected once the slot is full"
	)

	# Reset all slots for a clean slate.
	for slot in [ui.cause_slot, ui.conflict_slot, ui.outcome_slot]:
		slot.clear()

	# Truthful sequence
	ui.cause_slot.place(ShotElement.new(report.truthful_sequence.cause_characters, report.truthful_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report.truthful_sequence.conflict_characters, report.truthful_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report.truthful_sequence.outcome_characters, report.truthful_sequence.outcome_action))
	_check(not ui.broadcast_button.disabled, "broadcast enabled at 3/3")

	ui._on_broadcast_pressed()
	_check(_resolved_count == 1, "broadcast_resolved fired for truthful sequence")
	_check(_last_matched, "truthful sequence matched")
	_check(
		_last_sequence != null and _last_sequence.headline == "Civilian Killed During Checkpoint Confrontation",
		"truthful headline is correct"
	)

	# Propaganda sequence
	ui.cause_slot.place(ShotElement.new(report.propaganda_sequence.cause_characters, report.propaganda_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report.propaganda_sequence.conflict_characters, report.propaganda_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report.propaganda_sequence.outcome_characters, report.propaganda_sequence.outcome_action))
	ui._on_broadcast_pressed()
	_check(_resolved_count == 2, "broadcast_resolved fired for propaganda sequence")
	_check(_last_matched, "propaganda sequence matched")
	_check(
		_last_sequence != null and _last_sequence.headline == "Extremist Attacks Security Officer at Checkpoint",
		"propaganda headline is correct"
	)

	# Unrecognized combination
	var stray_action: ActionDef = report.available_actions[0]
	ui.cause_slot.place(ShotElement.new([witness], stray_action))
	ui.conflict_slot.place(ShotElement.new([witness], stray_action))
	ui.outcome_slot.place(ShotElement.new([witness], stray_action))
	ui._on_broadcast_pressed()
	_check(_resolved_count == 3, "broadcast_resolved fired for unrecognized combination")
	_check(not _last_matched, "unrecognized combination does not match")
	_check(_last_sequence == null, "unrecognized combination returns no sequence")
	_check(ui.dialogue_label.text != "", "dialogue falls back gracefully instead of erroring")

	# --- Day 0: Rooftop Killing report + reporter narration playback ---
	var rooftop_report := BroadcastDemoData.rooftop_killing_report()
	ui.load_report(rooftop_report)
	_check(ui.dialogue_label.text == rooftop_report.directive_text, "rooftop report directive text loads")
	_check(rooftop_report.truthful_sequence == null, "rooftop report has no truthful route")

	# Pre-broadcast CONTINUE should just pass through (no playback active yet).
	ui.continue_pressed.connect(_on_continue_passthrough)
	ui.continue_button.pressed.emit()
	_check(_continue_signal_fired, "CONTINUE passes through when no playback is active")
	ui.continue_pressed.disconnect(_on_continue_passthrough)

	var propaganda: BroadcastSequence = rooftop_report.propaganda_sequence
	ui.cause_slot.place(ShotElement.new(propaganda.cause_characters, propaganda.cause_action))
	ui.conflict_slot.place(ShotElement.new(propaganda.conflict_characters, propaganda.conflict_action))
	ui.outcome_slot.place(ShotElement.new(propaganda.outcome_characters, propaganda.outcome_action))
	_check(not ui.broadcast_button.disabled, "rooftop report broadcast enabled once all 3 slots filled")

	ui._on_broadcast_pressed()
	_check(ui._playback_active, "reporter playback starts after a matched broadcast")
	_check(ui.dialogue_label.text == propaganda.broadcast_lines[0], "first reporter line shown")
	_check(
		not ui.cause_slot._highlighted and not ui.conflict_slot._highlighted and not ui.outcome_slot._highlighted,
		"intro line highlights no frame"
	)

	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == propaganda.broadcast_lines[1], "second reporter line shown")
	_check(ui.cause_slot._highlighted, "cause frame highlighted during its line")

	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == propaganda.broadcast_lines[2], "third reporter line shown")
	_check(ui.cause_slot._highlighted, "cause frame still highlighted during continuation line")

	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == propaganda.broadcast_lines[3], "fourth reporter line shown")
	_check(ui.conflict_slot._highlighted and not ui.cause_slot._highlighted, "conflict frame highlighted, cause cleared")

	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == propaganda.broadcast_lines[4], "fifth reporter line shown")
	_check(ui.outcome_slot._highlighted, "outcome frame highlighted")

	# 5 more presses: lines[5..8] (4 presses), then a 5th press ends playback.
	for _i in range(5):
		ui.continue_button.pressed.emit()
	_check(not ui._playback_active, "playback ends after the last line")
	_check(ui.dialogue_label.text.ends_with("— End of broadcast —"), "end-of-broadcast marker shown")
	_check(not ui.outcome_slot._highlighted, "highlight cleared once playback ends")

	ui.queue_free()
	await process_frame
	if failures == 0:
		print("SMOKE_TEST_PASS")
	quit(failures)


func _on_broadcast_resolved(sequence: BroadcastSequence, matched: bool) -> void:
	_resolved_count += 1
	_last_sequence = sequence
	_last_matched = matched


func _on_continue_passthrough() -> void:
	_continue_signal_fired = true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
