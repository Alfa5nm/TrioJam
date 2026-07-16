extends SceneTree

var failures := 0
var _last_sequence: BroadcastSequence
var _last_matched := false
var _resolved_count := 0
var _continue_signal_fired := false
var _capacity_warning_fired := false


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
	_check(report.max_characters_per_frame == 2, "checkpoint report allows 2 characters per frame")
	_check(ui.cause_slot.max_characters == 2, "cause slot picks up the report's 2-character cap")

	# The scene frame only cycles via its small button region, not the whole body.
	_check(ui.scene_frame.current_action == null, "scene frame starts with no scene picked")
	_check(ui.scene_frame.click_region != null, "scene frame click region exists")
	ui.scene_frame.click_region.pressed.emit()
	_check(ui.scene_frame.current_action != null, "clicking the button region picks a scene")

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

	# --- Day 0: Rooftop Killing report + paginated intro + reporter narration playback ---
	var rooftop_report := BroadcastDemoData.rooftop_killing_report()
	ui.load_report(rooftop_report)
	_check(rooftop_report.truthful_sequence != null, "rooftop report now has a truthful route")
	_check(rooftop_report.max_characters_per_frame == 1, "rooftop report allows only 1 character per frame")
	_check(rooftop_report.available_actions[0].scene_image != null, "rooftop scene action has a reveal image")
	_check(rooftop_report.available_actions[1].scene_image != null, "rooftop shoots action has a reveal image")
	_check(rooftop_report.available_actions[2].scene_image != null, "victim shot action has a reveal image")
	_check(ui.cause_slot.max_characters == 1, "cause slot picks up rooftop report's 1-character cap")
	_check(ui._playback_active, "intro pagination starts immediately after loading a report")
	_check(ui.dialogue_label.text == rooftop_report.intro_lines[0], "first intro page shown")

	_check(
		ui._playback_speakers.size() == rooftop_report.intro_speakers.size(),
		"intro speaker list is tracked alongside the lines"
	)
	_check(ui.speaker_portrait.visible, "speaker portrait shows for the first (government) line")
	_check(
		ui.speaker_portrait.texture == rooftop_report.speaker_portraits[&"government"],
		"government's portrait texture is shown first"
	)

	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == rooftop_report.intro_lines[1], "second intro page shown")
	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == rooftop_report.intro_lines[2], "third intro page shown")
	_check(
		ui.speaker_portrait.texture == rooftop_report.speaker_portraits[&"mc"],
		"portrait switches to MC when MC speaks"
	)
	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == rooftop_report.intro_lines[3], "fourth intro page shown")
	_check(
		ui.speaker_portrait.texture == rooftop_report.speaker_portraits[&"government"],
		"portrait switches back to government"
	)

	# Advance through the remaining interrogation pages (indices 4..15) to the end,
	# plus one more press to trigger the end-of-intro transition.
	for _i in range(rooftop_report.intro_lines.size() - 4 + 1):
		ui.continue_button.pressed.emit()
	_check(not ui._playback_active, "intro pagination ends after the last page")
	_check(
		not ui.dialogue_label.text.ends_with("— End of broadcast —"),
		"intro end does not show the broadcast recap marker"
	)

	# Once intro pagination is done, CONTINUE passes through again (no playback active).
	ui.continue_pressed.connect(_on_continue_passthrough)
	ui.continue_button.pressed.emit()
	_check(_continue_signal_fired, "CONTINUE passes through once intro pagination is finished")
	ui.continue_pressed.disconnect(_on_continue_passthrough)

	# A 2nd character is rejected with a warning when the report caps frames at 1.
	ui.cause_slot.capacity_warning.connect(_on_capacity_warning)
	var opposition: CharacterDef = rooftop_report.characters[0]
	var mc: CharacterDef = rooftop_report.characters[1]
	ui.cause_slot._drop_data(Vector2.ZERO, {"type": "broadcast_scene", "action": rooftop_report.available_actions[0]})
	ui.cause_slot._drop_data(Vector2.ZERO, {"type": "broadcast_character", "character": opposition})
	_check(ui.cause_slot.current_characters.size() == 1, "slot holds its single allowed character")
	_check(ui.cause_slot.scene_image.visible, "correct scene+character combo reveals the scene image live")
	_check(
		ui.cause_slot.scene_image.texture == rooftop_report.available_actions[0].scene_image,
		"the revealed image matches the scene's authored art"
	)
	_check(
		not ui.cause_slot._can_drop_data(Vector2.ZERO, {"type": "broadcast_character", "character": mc}),
		"a 2nd character is rejected when the frame caps at 1"
	)
	_check(_capacity_warning_fired, "capacity_warning signal fires when a 2nd character is rejected")
	_check(ui.dialogue_label.text.contains("1 character"), "dialogue shows the capacity warning message")
	ui.cause_slot.capacity_warning.disconnect(_on_capacity_warning)
	ui.cause_slot.clear()

	# --- Truth route: matches, but MC refuses to broadcast it — no reporter recap ---
	var truthful: BroadcastSequence = rooftop_report.truthful_sequence
	ui.cause_slot.place(ShotElement.new(truthful.cause_characters, truthful.cause_action))
	ui.conflict_slot.place(ShotElement.new(truthful.conflict_characters, truthful.conflict_action))
	ui.outcome_slot.place(ShotElement.new(truthful.outcome_characters, truthful.outcome_action))
	_check(
		ui.cause_slot.scene_image.visible and ui.conflict_slot.scene_image.visible and ui.outcome_slot.scene_image.visible,
		"all 3 frames reveal their scene image once the truth route is correctly assembled"
	)
	ui._on_broadcast_pressed()
	_check(_last_matched, "truth route matches")
	_check(ui._playback_active, "MC's refusal reaction plays")
	_check(ui.dialogue_label.text == truthful.reaction_lines[0], "MC's refusal line is shown")
	ui.continue_button.pressed.emit()
	_check(not ui._playback_active, "truth route ends after MC's single reaction line")
	_check(
		not ui.dialogue_label.text.ends_with("— End of broadcast —"),
		"truth route shows no recap marker since MC refused to broadcast"
	)

	# --- Unrecognized combination uses the report's authored mismatch line ---
	var government_official: CharacterDef = rooftop_report.characters[2]
	var rooftop_scene_action: ActionDef = rooftop_report.available_actions[0]
	ui.cause_slot.place(ShotElement.new([government_official], rooftop_scene_action))
	ui.conflict_slot.place(ShotElement.new([government_official], rooftop_scene_action))
	ui.outcome_slot.place(ShotElement.new([government_official], rooftop_scene_action))
	_check(
		not ui.cause_slot.scene_image.visible,
		"an incorrect combo does not reveal a scene image, even with a valid action"
	)
	ui._on_broadcast_pressed()
	_check(not _last_matched, "unrecognized rooftop combination does not match")
	_check(ui.dialogue_label.text == rooftop_report.mismatch_line, "dialogue shows the report's authored mismatch line")

	# --- Propaganda route: MC's reaction lines play first, then the reporter recap ---
	var propaganda: BroadcastSequence = rooftop_report.propaganda_sequence
	ui.cause_slot.place(ShotElement.new(propaganda.cause_characters, propaganda.cause_action))
	ui.conflict_slot.place(ShotElement.new(propaganda.conflict_characters, propaganda.conflict_action))
	ui.outcome_slot.place(ShotElement.new(propaganda.outcome_characters, propaganda.outcome_action))
	_check(
		ui.cause_slot.scene_image.texture == propaganda.cause_action.scene_image
		and ui.conflict_slot.scene_image.texture == propaganda.conflict_action.scene_image
		and ui.outcome_slot.scene_image.texture == propaganda.outcome_action.scene_image,
		"the propaganda route reveals the correct distinct image per frame"
	)
	_check(not ui.broadcast_button.disabled, "rooftop report broadcast enabled once all 3 slots filled")

	ui._on_broadcast_pressed()
	_check(ui._playback_active, "propaganda reaction + recap playback starts after a matched broadcast")
	_check(ui.dialogue_label.text == propaganda.reaction_lines[0], "MC's first reaction line shown before the recap")
	_check(
		not ui.cause_slot._highlighted and not ui.conflict_slot._highlighted and not ui.outcome_slot._highlighted,
		"MC's reaction lines highlight no frame"
	)

	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == propaganda.reaction_lines[1], "MC's second reaction line shown")
	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == propaganda.reaction_lines[2], "MC's third reaction line shown")
	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == propaganda.broadcast_lines[0], "first reporter line shown after MC's reaction")

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

	# Remaining broadcast_lines[5..8] (4 presses), then one more press ends playback.
	for _i in range(propaganda.broadcast_lines.size() - 5 + 1):
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


func _on_capacity_warning(_slot: FrameSlot) -> void:
	_capacity_warning_fired = true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
