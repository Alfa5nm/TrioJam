extends SceneTree

var failures := 0


func _init() -> void:
	print("DAY1_BROADCAST_TEST_START")
	_run.call_deferred()


func _run() -> void:
	_check_report2_data()
	await _check_chain_flow()
	if failures == 0:
		print("DAY1_BROADCAST_TEST_PASS")
	quit(failures)


func _check_report2_data() -> void:
	var report := BroadcastDemoData.seedless_fruit_report()
	_check(report.report_id == &"day1_seedless_fruit", "seedless fruit report has its own report_id")
	_check(report.max_characters_per_frame == 2, "seedless fruit report allows 2 characters per frame")

	var ids: Array[StringName] = []
	for character in report.characters:
		ids.append(character.id)
	_check(ids.size() == 3, "Report 2 roster has exactly three reusable characters")
	for expected in [&"soldier", &"civilian", &"opposition"]:
		_check(ids.has(expected), "Report 2 roster includes %s" % expected)

	var action_ids: Array[StringName] = []
	for action in report.available_actions:
		action_ids.append(action.id)
	for expected in [&"licensing_seeds", &"protest", &"happy", &"arrest"]:
		_check(action_ids.has(expected), "Report 2 actions include %s" % expected)
		var action := _find_action(report, expected)
		_check(action != null and action.scene_image != null, "Report 2 action %s has placeholder art" % expected)

	# Truthful: Licensing(soldier, opposition) -> Protest(opposition) -> Arrest(soldier, opposition).
	var truthful := report.truthful_sequence
	_check(truthful.order_sensitive, "truthful sequence is order-sensitive")
	_check(truthful.cause_action.id == &"licensing_seeds", "truthful cause is the shared licensing photo")
	_check(_ordered_ids(truthful.cause_characters) == [&"soldier", &"opposition"], "truthful licensing casts soldier then opposition, in order")
	_check(truthful.conflict_action.id == &"protest", "truthful conflict is the protest")
	_check(_ordered_ids(truthful.conflict_characters) == [&"opposition"], "truthful protest is carried by opposition alone")
	_check(truthful.outcome_action.id == &"arrest", "truthful outcome is the arrest")
	_check(_ordered_ids(truthful.outcome_characters) == [&"soldier", &"opposition"], "truthful arrest orders soldier then opposition")
	_check(not truthful.broadcast_lines.is_empty(), "truthful sequence has a reporter recap script")
	_check(truthful.reaction_lines.size() == 2 and truthful.reaction_lines[1] == "But it's for the country's sake. I have to.", "truthful reaction carries the resigned-but-resolved lines")

	# Propaganda: Licensing(soldier, civilian) -> Happy(civilian) -> Arrest(soldier, opposition).
	var propaganda := report.propaganda_sequence
	_check(propaganda.order_sensitive, "propaganda sequence is order-sensitive")
	_check(propaganda.cause_action.id == &"licensing_seeds", "propaganda cause reuses the same shared licensing photo")
	_check(_ordered_ids(propaganda.cause_characters) == [&"soldier", &"civilian"], "propaganda licensing casts soldier then civilian, in order")
	_check(propaganda.conflict_action.id == &"happy", "propaganda conflict is the happy scene")
	_check(_ordered_ids(propaganda.conflict_characters) == [&"civilian"], "propaganda's happy scene is carried by civilian alone")
	_check(propaganda.outcome_action.id == &"arrest", "propaganda outcome is the same arrest action")
	_check(_ordered_ids(propaganda.outcome_characters) == [&"soldier", &"opposition"], "propaganda arrest uses the same soldier-then-opposition order as truthful")
	_check(not propaganda.broadcast_lines.is_empty(), "propaganda sequence has a reporter recap script")
	_check(propaganda.reaction_lines.size() == 3 and propaganda.reaction_lines[0] == "Hahahaa… Hah…..", "propaganda reaction opens with the hollow laugh line")

	_check(report.mismatch_line == "No no no, this doesn't make any sense. Let's try again.", "mismatch line matches the authored line")

	# The arrest frame is now identical for both routes (cause/conflict alone
	# discriminate truthful vs propaganda) — but order_sensitive still means the
	# reversed pair matches NEITHER route, since both expect soldier first.
	var reversed_outcome := ShotElement.new([opposition_char(report), soldier_char(report)], _find_action(report, &"arrest"))
	_check(not truthful.matches_slot(2, reversed_outcome), "reversing the arrest order no longer matches the truthful outcome")
	_check(not propaganda.matches_slot(2, reversed_outcome), "reversing the arrest order no longer matches the propaganda outcome either")


func _ordered_ids(characters: Array[CharacterDef]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for character in characters:
		ids.append(character.id)
	return ids


func soldier_char(report: BroadcastReport) -> CharacterDef:
	for character in report.characters:
		if character.id == &"soldier":
			return character
	return null


func opposition_char(report: BroadcastReport) -> CharacterDef:
	for character in report.characters:
		if character.id == &"opposition":
			return character
	return null


func _check_chain_flow() -> void:
	var packed_scene := load("res://scenes/gameplay/broadcast_interface.tscn") as PackedScene
	var ui := packed_scene.instantiate() as BroadcastInterface
	ui.instant_mode = true
	ui.use_news_broadcast_scene = false
	root.add_child(ui)
	for _frame in 4:
		await process_frame

	var report1 := BroadcastDemoData.checkpoint_killing_report()
	var report2 := BroadcastDemoData.seedless_fruit_report()
	ui.load_report_chain([report1, report2])
	_advance_through_playback(ui)
	_check(ui.report == report1, "chain starts on the first report")
	_check(ui.phase == BroadcastInterface.Phase.EDITING, "first report's intro finishes into editing")

	# Solve report 1 (truthful) — reaction lines play, then the chain should hand
	# off directly to report 2's own intro rather than airing a recap yet.
	ui.cause_slot.place(ShotElement.new(report1.truthful_sequence.cause_characters, report1.truthful_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report1.truthful_sequence.conflict_characters, report1.truthful_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report1.truthful_sequence.outcome_characters, report1.truthful_sequence.outcome_action))
	ui._on_broadcast_pressed()
	_advance_through_response(ui)
	_check(ui.report == report2, "solving report 1 auto-advances to report 2 instead of airing early")
	_check(not (ui._playback_active and ui._playback_is_recap), "no recap has started yet with a report still unsolved")

	_advance_through_playback(ui)
	_check(ui.phase == BroadcastInterface.Phase.EDITING, "report 2's intro finishes into editing")

	# Solve report 2 (truthful) — its own reaction lines play first, then the
	# chain should fall into the combined recap covering both reports.
	ui.cause_slot.place(ShotElement.new(report2.truthful_sequence.cause_characters, report2.truthful_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report2.truthful_sequence.conflict_characters, report2.truthful_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report2.truthful_sequence.outcome_characters, report2.truthful_sequence.outcome_action))
	ui._on_broadcast_pressed()
	_check(ui._chain_mission_lines[0] == report2.truthful_sequence.reaction_lines[0], "report 2's truthful reaction lines play before the combined recap")
	_advance_through_response(ui)
	_check(ui._playback_active and ui._playback_is_recap, "solving the final report starts the combined recap")
	_check(ui.dialogue_label.text.begins_with("And now, for Today's News."), "combined recap opens with the Today's News line")

	var report1_lines := report1.truthful_sequence.broadcast_lines.size()
	var bridge_index := 1 + report1_lines
	_check(ui._playback_lines[0] == "And now, for Today's News.", "line 0 is the opening line")
	_check(ui._playback_owners[0] == -1, "the opening line has no owning report")
	_check(ui._playback_owners[1] == 0, "report 1's first recap line is owned by chain entry 0")
	_check(ui._playback_lines[bridge_index] == "Now, for our other news of the day.", "the bridge line sits right after report 1's recap")
	_check(ui._playback_owners[bridge_index] == -1, "the bridge line has no owning report")
	_check(ui._playback_owners[bridge_index + 1] == 1, "report 2's first recap line is owned by chain entry 1")
	_check(ui._playback_lines.size() == 1 + report1_lines + 1 + report2.truthful_sequence.broadcast_lines.size(), "combined recap concatenates both reports' full scripts")

	# Advance one line into report 1's recap and confirm its own frame art is shown.
	ui._on_continue_pressed()
	_check(_slot_shows(ui.cause_slot, report1.truthful_sequence.cause_action), "report 1's recap restores its own cause frame art")
	_check(_slot_shows(ui.conflict_slot, report1.truthful_sequence.conflict_action), "report 1's recap restores its own conflict frame art")
	_check(_slot_shows(ui.outcome_slot, report1.truthful_sequence.outcome_action), "report 1's recap restores its own outcome frame art")

	# Advance to the bridge line, then one more into report 2's recap and confirm
	# the frames swapped to report 2's own art.
	while ui._playback_index < bridge_index + 1:
		ui._on_continue_pressed()
	_check(_slot_shows(ui.cause_slot, report2.truthful_sequence.cause_action), "crossing into report 2's recap swaps in its own cause frame art")
	_check(_slot_shows(ui.conflict_slot, report2.truthful_sequence.conflict_action), "crossing into report 2's recap swaps in its own conflict frame art")
	_check(_slot_shows(ui.outcome_slot, report2.truthful_sequence.outcome_action), "crossing into report 2's recap swaps in its own outcome frame art")

	# Run the rest of the recap out to completion without erroring.
	while ui._playback_active:
		ui._on_continue_pressed()
	_check(ui.dialogue_label.text.ends_with("— End of broadcast —"), "combined recap ends cleanly")

	ui.queue_free()
	await process_frame


func _slot_shows(slot: FrameSlot, action: ActionDef) -> bool:
	var atlas := slot.scene_image.texture as AtlasTexture
	return atlas != null and atlas.atlas == action.scene_image


func _find_action(report: BroadcastReport, id: StringName) -> ActionDef:
	for action in report.available_actions:
		if action.id == id:
			return action
	return null


func _advance_through_playback(ui: BroadcastInterface, max_steps := 40) -> void:
	var steps := 0
	while ui._playback_active and steps < max_steps:
		ui._on_continue_pressed()
		steps += 1


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
