extends SceneTree

var failures := 0
var _last_sequence: BroadcastSequence
var _last_matched := false
var _resolved_count := 0


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
	_check(ui.use_news_broadcast_scene, "accepted Day 0 propaganda defaults to the animated NEWS studio")
	ui.instant_mode = true
	ui.use_news_broadcast_scene = false
	root.add_child(ui)
	for _frame in 4:
		await process_frame

	_check(ui.cause_slot != null, "cause slot exists")
	_check(ui.conflict_slot != null, "conflict slot exists")
	_check(ui.outcome_slot != null, "outcome slot exists")
	_check(ui.scene_frame != null, "scene frame exists")
	_check(ui.scene_frame.click_region != null, "redesigned scene selector has its interactive region")
	_check(ui.character_roster != null, "character roster exists")
	_check(ui.broadcast_button != null, "broadcast button exists")
	_check(ui.get_node("Background").texture != null, "Akiibot's redesigned Broadcast background is loaded")
	_check(ui.crt_material != null, "interrogation is localized through the CRT material")
	_check(ui.phase == BroadcastInterface.Phase.INTERROGATION, "Day 0 starts in the cinematic interrogation phase")
	_check(ui.tv_power.stream != null and ui.tv_hum.stream != null, "CRT power and ambience cues are assigned")
	_check(ui.eject_sound.stream != null and ui.button_sound.stream != null, "desk hardware cues are assigned")
	_check((ui.get_node("DeskRoot/GeneratedConsole") as TextureRect).texture.resource_path.ends_with("broadcast-console-base-v4.png"), "desk uses the decomposed hardware-free base plate")
	_check(ui.scene_frame.camera_body.texture.resource_path.ends_with("evidence-camera-v5.png"), "capture camera uses the flat interaction-aligned painted object")
	_check(ui.scene_frame.previous_button.text.is_empty() and ui.scene_frame.next_button.text.is_empty(), "camera arrows use embedded painted controls rather than GUI glyph buttons")

	if ui.cause_slot == null or ui.conflict_slot == null or ui.outcome_slot == null or ui.broadcast_button == null:
		ui.queue_free()
		await process_frame
		quit(failures)
		return

	ui.broadcast_resolved.connect(_on_broadcast_resolved)

	var report := BroadcastDemoData.checkpoint_killing_report()
	ui.load_report(report)
	ui.scene_frame.ejection_time_scale = 0.0
	_check(ui.broadcast_button.disabled, "broadcast disabled with 0/3 filled")

	# The redesigned scene card owns its cycle interaction.
	_check(ui.scene_frame.current_action == null, "scene frame starts with no scene picked")
	ui.scene_frame.click_region.pressed.emit()
	_check(ui.scene_frame.current_action != null, "clicking SCENE picks a scene")
	_check(ui.scene_frame.is_ejected(ui.scene_frame.current_action), "red monitor control ejects a unique physical footage card")
	_check(ui.scene_frame._polaroids.has(ui.scene_frame.current_action.id), "archiving physically creates a polaroid above the camera")
	var emitted_polaroid := ui.scene_frame._polaroids[ui.scene_frame.current_action.id] as Control
	_check(emitted_polaroid.get_parent() == ui.scene_frame.front_ejection_layer, "printed polaroid crosses into the foreground after clearing the slot")
	_check(emitted_polaroid.mouse_filter == Control.MOUSE_FILTER_STOP, "ejected polaroid owns pointer input outside the camera bounds")
	var polaroid_payload: Variant = ui.scene_frame._get_polaroid_drag_data(Vector2.ZERO, ui.scene_frame.current_action, emitted_polaroid, false)
	_check(typeof(polaroid_payload) == TYPE_DICTIONARY and polaroid_payload.get("type") == "broadcast_scene", "ejected polaroid begins a footage drag directly")
	ui.scene_frame.mark_placed(ui.scene_frame.current_action)
	_check(not emitted_polaroid.visible, "polaroid leaves the camera tray after being placed")
	ui.scene_frame.return_card(ui.scene_frame.current_action)
	_check(emitted_polaroid.visible, "returned footage restores the same draggable polaroid")

	# Scene-first rule now lives on each slot directly: character drops rejected until
	# that specific slot already has a scene dropped into it.
	var soldier: CharacterDef = report.characters[0]
	var civilian: CharacterDef = report.characters[1]
	var witness: CharacterDef = report.characters[2]
	var scene_action: ActionDef = report.available_actions[0]
	var character_payload := {"type": "broadcast_character", "character": soldier}
	var scene_payload := {"type": "broadcast_scene", "action": scene_action}

	_check(
		ui.cause_slot._can_drop_data(Vector2.ZERO, character_payload),
		"character drop is accepted before footage so either placement order works"
	)
	_check(
		ui.cause_slot._can_drop_data(Vector2.ZERO, scene_payload),
		"scene drop always accepted onto an empty slot"
	)
	ui.cause_slot._drop_data(Vector2.ZERO, scene_payload)
	_check(ui.cause_slot.current_action == scene_action, "slot records the dropped scene")
	ui.cause_slot.show_scene_reveal(scene_action.scene_image)
	_check(ui.cause_slot.scene_image.mouse_filter == Control.MOUSE_FILTER_IGNORE, "visible footage cannot intercept character drops")
	_check(ui.scene_frame._get_drag_data(Vector2.ZERO) == null, "placed footage cannot be duplicated into another frame")
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

	# --- Day 0: embedded interrogation, desk mission, and reporter handoff ---
	var rooftop_report := BroadcastDemoData.rooftop_killing_report()
	ui.load_report(rooftop_report)
	_check(ui._playback_active, "Day 0 Government interrogation begins inside the Broadcast UI")
	_check(rooftop_report.intro_beats.size() == rooftop_report.intro_lines.size(), "interrogation uses emotion-aware dialogue beats")
	_check(ui.dialogue_label.text == "...", "Government Man opens the embedded interrogation")
	_check(ui.speaker_portrait.visible and ui.speaker_portrait.texture == rooftop_report.speaker_portraits[&"government"], "Government portrait is shown for his dialogue")
	for _index in range(3):
		ui.continue_button.pressed.emit()
	_check(ui._awaiting_name and ui.name_entry.visible, "embedded interrogation pauses at the naming prompt")
	_check(ui.name_input.max_length == 10, "Broadcast naming keeps the ten-character limit")
	ui.name_input.text = "Test MC"
	ui._confirm_name()
	_check(ui.dialogue_label.text == "Test MC.", "entered name is spoken as the MC response")
	_check(ui.speaker_portrait.texture == BroadcastInterface.MC_GUARDED, "generated emotion-aware MC portrait accompanies the entered name")
	ui.continue_button.pressed.emit()
	for _index in range(rooftop_report.intro_lines.size() - 4):
		ui.continue_button.pressed.emit()
	_check(not ui._playback_active, "interrogation completes before desk editing begins")
	_check(ui.dialogue_label.text == rooftop_report.directive_text, "desk directive follows the embedded interrogation")
	_check(ui.scene_frame.click_region.disabled == false, "desk editing unlocks only after interrogation")
	_check(not ui.continue_button.visible, "Continue is hidden while the player constructs the report")
	_check(rooftop_report.truthful_sequence != null, "rooftop report recognizes its truthful reconstruction")
	_check(rooftop_report.intro_lines.all(func(line: String): return line not in rooftop_report.propaganda_sequence.broadcast_lines), "interrogation lines remain separate from the Broadcast Lady script")
	_check(rooftop_report.available_actions.all(func(action: ActionDef): return action.scene_image != null), "Akiibot's three authored frame images are available")
	_check(rooftop_report.characters.all(func(character: CharacterDef): return character.portrait_texture != null), "Akiibot's three authored roster portraits are available")
	_check(ui.cause_slot.max_characters == 1, "redesigned Day 0 frames retain their one-character limit")
	var session := root.get_node_or_null("GameSession")
	_check(session != null and rooftop_report.characters[1].display_name == session.player_name, "Broadcast roster uses the embedded interrogation name")
	var live_chip := ui.character_roster.get_child(0) as CharacterChip
	var live_character_payload: Variant = live_chip.drag_payload()
	_check(typeof(live_character_payload) == TYPE_DICTIONARY, "visible Day 0 portrait produces a character drag payload")
	ui.cause_slot.clear()
	ui.cause_slot._drop_data(Vector2.ZERO, live_character_payload)
	_check(ui.cause_slot.current_action == null and ui.cause_slot.current_characters.size() == 1, "character token can be dropped before footage")
	ui.cause_slot.clear()

	var truth: BroadcastSequence = rooftop_report.truthful_sequence
	ui.cause_slot.place(ShotElement.new(truth.cause_characters, truth.cause_action))
	ui.conflict_slot.place(ShotElement.new(truth.conflict_characters, truth.conflict_action))
	ui.outcome_slot.place(ShotElement.new(truth.outcome_characters, truth.outcome_action))
	ui._on_broadcast_pressed()
	_check(ui.dialogue_label.text == "No. No no no. I can't broadcast this.", "truth reconstruction is recognized and rejected with the authored line")
	_check(not ui._playback_active, "truth route never starts reporter playback")
	_check(ui.broadcast_button.disabled, "editing is locked while the truth response is on screen")
	var truth_character_count := ui.cause_slot.current_characters.size()
	ui.cause_slot.remove_character(ui.cause_slot.current_characters[0])
	_check(ui.cause_slot.current_characters.size() == truth_character_count, "placed character removal is locked during narrative responses")
	ui.continue_button.pressed.emit()
	_check(not ui.scene_frame.click_region.disabled, "editing returns after the truth response")

	ui.cause_slot.place(ShotElement.new([rooftop_report.characters[2]], rooftop_report.available_actions[0]))
	ui.conflict_slot.place(ShotElement.new([rooftop_report.characters[2]], rooftop_report.available_actions[1]))
	ui.outcome_slot.place(ShotElement.new([rooftop_report.characters[0]], rooftop_report.available_actions[2]))
	ui._on_broadcast_pressed()
	_check(ui.dialogue_label.text == "...This doesn't make any sense.", "invalid reconstruction receives the authored response")
	_check(not ui._playback_active, "invalid reconstruction does not start reporter playback")
	ui.continue_button.pressed.emit()

	var propaganda: BroadcastSequence = rooftop_report.propaganda_sequence
	ui.cause_slot.place(ShotElement.new(propaganda.cause_characters, propaganda.cause_action))
	ui.conflict_slot.place(ShotElement.new(propaganda.conflict_characters, propaganda.conflict_action))
	ui.outcome_slot.place(ShotElement.new(propaganda.outcome_characters, propaganda.outcome_action))
	_check(not ui.broadcast_button.disabled, "rooftop report broadcast enabled once all 3 slots filled")

	ui._on_broadcast_pressed()
	_check(not ui._playback_active, "propaganda route pauses for the MC response before playback")
	_check(ui.dialogue_label.text == "They will believe this, even if it doesn't make sense.", "first propaganda commitment line shown")
	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == "This will cause a huge conflict...", "second propaganda commitment line shown")
	ui.continue_button.pressed.emit()
	_check(ui.dialogue_label.text == "...I have to be okay with this.", "third propaganda commitment line shown")
	ui.continue_button.pressed.emit()
	_check(ui._playback_active, "reporter playback starts after all three commitment lines")
	_check(session.pending_broadcast_package != null and session.pending_broadcast_package.action_ids.size() == 3, "accepted reconstruction is packaged for the NEWS studio")
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


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
