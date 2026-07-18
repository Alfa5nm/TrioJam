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
	_check(ui.cause_slot.size == BroadcastInterface.FRAME_RECTS[0].size and ui.conflict_slot.size == BroadcastInterface.FRAME_RECTS[1].size and ui.outcome_slot.size == BroadcastInterface.FRAME_RECTS[2].size, "each story frame fills the interior of its own painted border")
	_check(is_equal_approx(ui.cause_slot.position.y, ui.conflict_slot.position.y) and is_equal_approx(ui.conflict_slot.position.y, ui.outcome_slot.position.y), "all three story frames share one baseline")
	_check(ui.cause_slot.position == BroadcastInterface.FRAME_RECTS[0].position and ui.conflict_slot.position == BroadcastInterface.FRAME_RECTS[1].position and ui.outcome_slot.position == BroadcastInterface.FRAME_RECTS[2].position, "all three story frames snap to their painted-border grid")
	_check(ui.scene_frame != null, "scene frame exists")
	_check(ui.scene_frame.click_region != null, "redesigned scene selector has its interactive region")
	_check(ui.character_roster != null, "character roster exists")
	_check(ui.broadcast_button != null, "broadcast button exists")
	_check(ui.broadcast_button.text.is_empty(), "painted Broadcast button does not receive an overlapping code-rendered label")
	_check(ui.get_node("Background").texture != null, "Akiibot's redesigned Broadcast background is loaded")
	_check(ui.crt_material != null, "interrogation is localized through the CRT material")
	_check(ui.phase == BroadcastInterface.Phase.INTERROGATION, "Day 0 starts in the cinematic interrogation phase")
	_check(not ui.cinema_rig.visible and ui.desk_root.visible, "Day 0 interrogation uses the Broadcast Interface left panel instead of a separate room")
	_check(ui.conversation_scroll.visible and ui.conversation_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "left-panel conversation history is scrollable")
	_check(ui.tv_power.stream != null and ui.tv_hum.stream != null, "CRT power and ambience cues are assigned")
	_check(ui.eject_sound.stream != null and ui.button_sound.stream != null, "desk hardware cues are assigned")
	_check((ui.get_node("DeskRoot/GeneratedConsole") as TextureRect).texture.resource_path.ends_with("broadcast-console-base-v4.png"), "desk uses the decomposed hardware-free base plate")
	_check(ui.scene_frame.camera_body.texture.resource_path.ends_with("evidence-camera-v5.png"), "capture camera uses the flat interaction-aligned painted object")
	_check(ui.scene_frame.previous_button.text.is_empty() and ui.scene_frame.next_button.text.is_empty(), "camera arrows use embedded painted controls rather than GUI glyph buttons")
	_check(ui.scene_frame.front_ejection_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "empty polaroid layer does not block the camera controls")

	# The first Continue/E press during typewriter playback completes the visible
	# transcript card rather than leaving it truncated.
	ui.instant_mode = false
	var skip_text := "This deliberately long interrogation sentence must remain complete when the player skips its typewriter animation."
	ui._current_speaker = &"government"
	ui._type_dialogue(skip_text)
	await process_frame
	_check(ui._typing_response, "long transcript line begins typewriter playback")
	ui._on_continue_pressed()
	while ui._typing_response:
		await process_frame
	_check(ui.dialogue_label.visible_characters == -1 and ui._active_transcript_label.visible_characters == -1, "E/Continue completes both dialogue representations without truncation")
	_check(ui._active_transcript_label.text == skip_text, "skipped transcript card retains the complete authored text")
	for index in 4:
		ui._append_transcript_entry("SYSTEM", "Auto-scroll verification entry %d with enough text to occupy another wrapped row." % index, &"system", true)
	await process_frame
	await process_frame
	_check(ui._transcript_is_at_bottom(), "conversation log follows the latest entry after its layout grows")
	ui.instant_mode = true

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
	_advance_through_playback(ui)
	_check(ui.phase == BroadcastInterface.Phase.EDITING, "Report 1 intro finishes into the editing phase")

	# The redesigned scene card owns its cycle interaction.
	_check(ui.scene_frame.current_action == report.available_actions[0], "camera preloads the first captured frame")
	_check(ui.scene_frame.screen_image.texture == report.available_actions[0].scene_image, "preloaded footage is visible in the camera")
	ui.scene_frame.next_button.pressed.emit()
	_check(ui.scene_frame.current_action == report.available_actions[1], "painted right camera button selects the next capture")
	ui.scene_frame.previous_button.pressed.emit()
	_check(ui.scene_frame.current_action == report.available_actions[0], "painted left camera button selects the previous capture")
	ui.scene_frame.click_region.pressed.emit()
	_check(ui.scene_frame.is_ejected(ui.scene_frame.current_action), "red monitor control ejects a unique physical footage card")
	_check(ui.scene_frame._polaroids.has(ui.scene_frame.current_action.id), "archiving physically creates a polaroid above the camera")
	var emitted_polaroid := (ui.scene_frame._polaroids[ui.scene_frame.current_action.id] as Array)[0] as Control
	_check(emitted_polaroid.get_parent() == ui.scene_frame.front_ejection_layer, "printed polaroid crosses into the foreground after clearing the slot")
	_check(emitted_polaroid.mouse_filter == Control.MOUSE_FILTER_STOP, "ejected polaroid owns pointer input outside the camera bounds")
	var polaroid_payload: Variant = ui.scene_frame._get_polaroid_drag_data(Vector2.ZERO, ui.scene_frame.current_action, emitted_polaroid, false)
	_check(typeof(polaroid_payload) == TYPE_DICTIONARY and polaroid_payload.get("type") == "broadcast_scene" and polaroid_payload.get("card") == emitted_polaroid, "ejected polaroid begins a footage drag directly, carrying its own card reference")
	ui.scene_frame.mark_placed(ui.scene_frame.current_action, emitted_polaroid)
	_check(not emitted_polaroid.visible, "polaroid leaves the camera tray after being placed")
	ui.scene_frame.return_card(ui.scene_frame.current_action, emitted_polaroid)
	_check(emitted_polaroid.visible, "returned footage restores the same draggable polaroid")

	# Printing the same scene again should not be blocked, and the two copies
	# must be independently placeable — this is what lets "Attack" be dragged
	# into both CAUSE and CONFLICT.
	ui.scene_frame.mark_placed(ui.scene_frame.current_action, emitted_polaroid)
	ui.scene_frame.click_region.pressed.emit()
	var reprinted_stack := ui.scene_frame._polaroids[ui.scene_frame.current_action.id] as Array
	_check(reprinted_stack.size() == 2, "re-pressing eject prints a second, independent copy of the same scene")
	var second_polaroid := reprinted_stack[1] as Control
	var second_payload: Variant = ui.scene_frame._get_polaroid_drag_data(Vector2.ZERO, ui.scene_frame.current_action, second_polaroid, false)
	_check(typeof(second_payload) == TYPE_DICTIONARY, "the second printed copy is draggable even though the first copy is already placed")
	ui.scene_frame.set_interaction_enabled(false)
	_check(ui.scene_frame.caption_label.text == "ARCHIVED", "the camera archives once interaction locks, not the instant a scene is first printed")
	ui.scene_frame.set_interaction_enabled(true)

	# Scene-first rule now lives on each slot directly: character drops rejected until
	# that specific slot already has a scene dropped into it.
	var soldier: CharacterDef = report.characters[0]
	var civilian: CharacterDef = report.characters[1]
	var scene_action: ActionDef = report.available_actions[0]
	var character_payload := {"type": "broadcast_character", "character": soldier}
	var scene_payload := {"type": "broadcast_scene", "action": scene_action, "card": emitted_polaroid}

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
	_check(ui.cause_slot.scale == Vector2.ONE, "drop feedback does not resize a story frame")
	_check(ui.cause_slot.return_button.visible, "filled frame exposes a visible RETURN control")
	ui.cause_slot.return_button.pressed.emit()
	_check(ui.cause_slot.current_action == null, "RETURN removes incorrect footage from its frame")
	_check(emitted_polaroid.visible, "RETURN restores the same physical polaroid above the camera")
	ui.cause_slot._drop_data(Vector2.ZERO, scene_payload)
	_check(ui.cause_slot.scene_image.mouse_filter == Control.MOUSE_FILTER_IGNORE, "visible footage cannot intercept character drops")
	_check(ui.scene_frame._get_drag_data(Vector2.ZERO) == null, "placed footage cannot be duplicated into another frame")
	_check(
		ui.cause_slot._can_drop_data(Vector2.ZERO, character_payload),
		"character drop accepted once this slot has a scene"
	)

	# 2-character cap, per slot. Only two characters exist in this report, so the
	# 3rd-drop attempt reuses "soldier" — the cap check runs before the
	# already-placed check, so this still exercises the same rejection path.
	ui.cause_slot._drop_data(Vector2.ZERO, character_payload)
	ui.cause_slot._drop_data(Vector2.ZERO, {"type": "broadcast_character", "character": civilian})
	_check(ui.cause_slot.current_characters.size() == 2, "slot holds 2 characters")
	_check(
		not ui.cause_slot._can_drop_data(Vector2.ZERO, {"type": "broadcast_character", "character": soldier}),
		"a 3rd character is rejected once the slot is full"
	)

	# Reset all slots for a clean slate.
	for slot in [ui.cause_slot, ui.conflict_slot, ui.outcome_slot]:
		slot.clear()

	# Truthful sequence — a matched, airing sequence locks editing and plays the
	# reaction lines, then moves straight into the (single-report) combined recap.
	ui.cause_slot.place(ShotElement.new(report.truthful_sequence.cause_characters, report.truthful_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report.truthful_sequence.conflict_characters, report.truthful_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report.truthful_sequence.outcome_characters, report.truthful_sequence.outcome_action))
	_check(not ui.broadcast_button.disabled, "broadcast enabled at 3/3")

	ui._on_broadcast_pressed()
	_check(_resolved_count == 1, "broadcast_resolved fired for truthful sequence")
	_check(_last_matched, "truthful sequence matched")
	_check(
		_last_sequence != null and _last_sequence.reaction_lines[0].begins_with("The photographs are simple"),
		"truthful route carries the resigned reaction line (reaction lines were swapped per script review)"
	)
	_advance_through_response(ui)
	_check(ui._playback_active and ui._playback_is_recap, "solving the only report in the chain starts the combined recap")
	_check(ui.dialogue_label.text.begins_with("And now, for Today's News"), "combined recap opens with the Today's News line")

	# Propaganda sequence — reload fresh since the truthful pass above already aired.
	ui.load_report(report)
	_advance_through_playback(ui)
	ui.cause_slot.place(ShotElement.new(report.propaganda_sequence.cause_characters, report.propaganda_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report.propaganda_sequence.conflict_characters, report.propaganda_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report.propaganda_sequence.outcome_characters, report.propaganda_sequence.outcome_action))
	ui._on_broadcast_pressed()
	_check(_resolved_count == 2, "broadcast_resolved fired for propaganda sequence")
	_check(_last_matched, "propaganda sequence matched")
	_check(
		_last_sequence != null and _last_sequence.reaction_lines[1] == "This… is the right thing to do.",
		"propaganda route carries the self-justifying reaction line (reaction lines were swapped per script review)"
	)
	_advance_through_response(ui)
	_check(ui._playback_active and ui._playback_is_recap, "solving propaganda also starts the combined recap")

	# Unrecognized combination — reload fresh again; a non-match must return to editing.
	# The soldier "attacking" in both cause and conflict (same order both times,
	# never resisted) doesn't match either authored order-sensitive sequence.
	ui.load_report(report)
	_advance_through_playback(ui)
	ui.cause_slot.place(ShotElement.new([soldier, civilian], scene_action))
	ui.conflict_slot.place(ShotElement.new([soldier, civilian], scene_action))
	ui.outcome_slot.place(ShotElement.new([soldier, civilian], report.available_actions[1]))
	ui._on_broadcast_pressed()
	_check(_resolved_count == 3, "broadcast_resolved fired for unrecognized combination")
	_check(not _last_matched, "unrecognized combination does not match")
	_check(_last_sequence == null, "unrecognized combination returns no sequence")
	_check(ui.dialogue_label.text != "", "dialogue falls back gracefully instead of erroring")
	_advance_through_response(ui)
	_check(ui.phase == BroadcastInterface.Phase.EDITING and ui._editing_enabled, "a mismatch returns to editing instead of airing")

	# --- Day 0: embedded interrogation, desk mission, and reporter handoff ---
	var rooftop_report := BroadcastDemoData.rooftop_killing_report()
	ui.load_report(rooftop_report)
	_check(ui._playback_active, "Day 0 Government interrogation begins inside the Broadcast UI")
	_check(rooftop_report.intro_beats.size() == rooftop_report.intro_lines.size(), "interrogation uses emotion-aware dialogue beats")
	_check(rooftop_report.intro_lines.size() == 17 and rooftop_report.intro_lines[7] == "…It’s G-03S-93", "interrogation uses the exact revised seventeen-beat script")
	_check(rooftop_report.intro_lines[16] == "(…But they’ll be hearing a lie. Not that it matters to them.)", "interrogation preserves the authored closing thought")
	_check(rooftop_report.speaker_portraits[&"government"].resource_path.ends_with("interrogation/government.png"), "left panel uses the supplied Government portrait")
	_check(BroadcastInterface.MC_NEUTRAL.resource_path.ends_with("interrogation/mc-neutral.png") and BroadcastInterface.MC_DIRTY.resource_path.ends_with("interrogation/mc-dirty.png"), "left panel uses the supplied neutral and dirty MC portraits")
	_check(BroadcastInterface.NEWSLETTER_FONT.resource_path.ends_with("Newsreader.ttf"), "conversation log uses the bundled news-reading typeface")
	_check(ui.dialogue_label.text == "…", "Government Man opens the embedded interrogation")
	_check(ui.desk_portrait.visible and ui.desk_portrait.texture == rooftop_report.speaker_portraits[&"government"], "Government portrait is shown in the left panel for his dialogue")
	_check(ui.conversation_history.get_child_count() == 1, "the first interrogation line is retained in the conversation log")
	var first_entry := ui.conversation_history.get_child(0) as PanelContainer
	var first_body := first_entry.get_child(0).get_child(1) as Label
	var first_style := first_entry.get_theme_stylebox("panel") as StyleBoxFlat
	_check(first_body.get_theme_font("font") == BroadcastInterface.NEWSLETTER_FONT and first_body.get_theme_color("font_color") == Color.WHITE, "conversation text uses the news font in white")
	_check(first_style.bg_color.is_equal_approx(Color(0.0431373, 0.113725, 0.301961, 0.97)), "conversation cards use the navy backdrop")
	_check(first_style.border_color.is_equal_approx(Color(0.133333, 0.839216, 1.0, 0.96)), "conversation cards use the neon-blue outline")
	_check(ui._mc_texture(&"dirty", false) == BroadcastInterface.MC_DIRTY, "dirty interrogation beats select the supplied dirty MC face")
	for _index in range(3):
		ui.continue_button.pressed.emit()
	_check(ui._awaiting_name and ui.name_entry.visible, "embedded interrogation pauses at the naming prompt")
	_check(ui.name_input.max_length == 10, "Broadcast naming keeps the ten-character limit")
	ui.name_input.text = "Test MC"
	ui._confirm_name()
	_check(ui.dialogue_label.text == "Test MC.", "entered name is spoken as the MC response")
	_check(ui.speaker_portrait.texture == BroadcastInterface.MC_NEUTRAL, "authored neutral MC portrait accompanies the entered name")
	ui.continue_button.pressed.emit()
	for _index in range(rooftop_report.intro_lines.size() - 4):
		ui.continue_button.pressed.emit()
	_check(not ui._playback_active, "interrogation completes before desk editing begins")
	_check(ui.dialogue_label.text == rooftop_report.directive_text, "desk directive follows the embedded interrogation")
	_check(ui.scene_frame.click_region.disabled == false, "desk editing unlocks only after interrogation")
	_check(not ui.continue_button.visible, "Continue is hidden while the player constructs the report")
	_check(ui.desk_continue_button.visible and ui.desk_continue_button.disabled and ui.desk_continue_button.text == "CONTINUE  >", "left hardware keeps one stable Continue overlay while editing")
	_check(ui.conversation_history.get_child_count() >= rooftop_report.intro_lines.size(), "completed interrogation remains available as scrollback")
	await process_frame
	await process_frame
	var transcript_bar := ui.conversation_scroll.get_v_scroll_bar()
	_check(transcript_bar.max_value > transcript_bar.page, "conversation history overflows into a real vertical scroll range")
	transcript_bar.value = 0.0
	await process_frame
	_check(is_zero_approx(transcript_bar.value), "player can scroll back to the beginning without being forced to the latest line")
	_check(rooftop_report.truthful_sequence != null, "rooftop report recognizes its truthful reconstruction")
	_check(rooftop_report.intro_lines.all(func(line: String): return line not in rooftop_report.propaganda_sequence.broadcast_lines), "interrogation lines remain separate from the Broadcast Lady script")
	_check(rooftop_report.available_actions.all(func(action: ActionDef): return action.scene_image != null), "Akiibot's three authored frame images are available")
	_check(rooftop_report.characters.all(func(character: CharacterDef): return character.portrait_texture != null), "Akiibot's three authored roster portraits are available")
	_check(ui.cause_slot.max_characters == 1, "redesigned Day 0 frames retain their one-character limit")
	ui.scene_frame.eject_current()
	var day0_card := (ui.scene_frame._polaroids[ui.scene_frame.current_action.id] as Array)[0] as Control
	var day0_footage_payload: Variant = ui.scene_frame._get_polaroid_drag_data(Vector2.ZERO, ui.scene_frame.current_action, day0_card, false)
	_check(day0_footage_payload.get("action") == rooftop_report.available_actions[0], "Day 0 polaroid carries the selected captured frame")
	_check((day0_footage_payload.get("action") as ActionDef).scene_image != null, "Day 0 polaroid carries a visible footage texture")
	ui.cause_slot._drop_data(Vector2.ZERO, day0_footage_payload)
	_check(ui.cause_slot.current_action == rooftop_report.available_actions[0], "Day 0 frame receives the selected captured action")
	_check(ui.cause_slot.scene_image.visible, "dropped Day 0 polaroid is visibly rendered inside its frame")
	_check((ui.cause_slot.scene_image.texture as AtlasTexture).atlas == rooftop_report.available_actions[0].scene_image, "frame renders the selected Day 0 footage texture")
	_check(ui.cause_slot.return_button.visible, "Day 0 footage provides a visible RETURN control")
	ui.cause_slot._drop_data(Vector2.ZERO, {"type": "broadcast_character", "character": rooftop_report.characters[0]})
	ui.cause_slot.return_button.pressed.emit()
	_check(ui.cause_slot.current_action == null and day0_card.visible, "RETURN removes Day 0 footage and restores its physical polaroid")
	_check(ui.cause_slot.current_characters.size() == 1, "returning footage preserves the independently assigned character chip")
	ui.cause_slot.clear()
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


## Drives continue-presses through an intro/recap dialogue sequence until it ends.
## Safe under instant_mode (no typing await gaps), bounded to avoid an infinite loop
## if playback never terminates.
func _advance_through_playback(ui: BroadcastInterface, max_steps := 40) -> void:
	var steps := 0
	while ui._playback_active and steps < max_steps:
		ui._on_continue_pressed()
		steps += 1


## Drives continue-presses through a chain mission-response (reaction lines or the
## mismatch line) until it resolves into either editing or the combined recap.
## Stops as soon as _chain_mission_lines empties rather than watching `phase`,
## since starting the combined recap does not change `phase` away from RESPONSE.
func _advance_through_response(ui: BroadcastInterface, max_steps := 20) -> void:
	var steps := 0
	while not ui._chain_mission_lines.is_empty() and steps < max_steps:
		ui._on_continue_pressed()
		steps += 1


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
