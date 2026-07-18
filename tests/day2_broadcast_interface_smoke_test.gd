extends SceneTree

var failures := 0
var _last_sequence: BroadcastSequence
var _last_matched := false
var _resolved_count := 0


func _init() -> void:
	print("DAY2_BROADCAST_TEST_START")
	_run.call_deferred()


func _run() -> void:
	_check_report_data()
	await _check_solve_flow()
	if failures == 0:
		print("DAY2_BROADCAST_TEST_PASS")
	quit(failures)


func _check_report_data() -> void:
	var report := BroadcastDemoData.bombing_report()
	_check(report.report_id == &"day2_bombing", "bombing report has its own report_id")
	_check(report.max_characters_per_frame == 2, "bombing report allows up to 2 characters per frame")

	var ids: Array[StringName] = []
	for character in report.characters:
		ids.append(character.id)
	_check(ids.size() == 4, "roster has exactly four characters")
	for expected in [&"suspicious_individual", &"civilians", &"opposition", &"soldiers"]:
		_check(ids.has(expected), "roster includes %s" % expected)

	var action_ids: Array[StringName] = []
	for action in report.available_actions:
		action_ids.append(action.id)
	for expected in [&"planting_bomb", &"peace_rally_victims", &"helping"]:
		_check(action_ids.has(expected), "actions include %s" % expected)
		var action := _find_action(report, expected)
		_check(action != null and action.scene_image != null, "action %s has placeholder art" % expected)

	# Truthful: PlantingBomb(suspicious_individual) -> PeaceRallyVictims(civilians) -> Helping(opposition, civilians).
	var truthful := report.truthful_sequence
	_check(truthful.order_sensitive, "truthful sequence is order-sensitive")
	_check(truthful.cause_action.id == &"planting_bomb", "truthful cause is planting the bomb")
	_check(_ordered_ids(truthful.cause_characters) == [&"suspicious_individual"], "truthful cause is carried by the suspicious individual alone")
	_check(truthful.conflict_action.id == &"peace_rally_victims", "truthful conflict is the peace rally victims")
	_check(_ordered_ids(truthful.conflict_characters) == [&"civilians"], "truthful conflict is carried by civilians alone")
	_check(truthful.outcome_action.id == &"helping", "truthful outcome is the helping scene")
	_check(_ordered_ids(truthful.outcome_characters) == [&"opposition", &"civilians"], "truthful helping orders opposition (helper) then civilians (helped)")
	_check(not truthful.broadcast_lines.is_empty(), "truthful sequence has a reporter recap script")
	_check(truthful.reaction_lines.size() == 3 and truthful.reaction_lines[2] == "I'm not going to let this pass.", "truthful reaction ends on the resolved line")

	# Propaganda: PlantingBomb(opposition) -> PeaceRallyVictims(soldiers) -> Helping(soldiers, civilians).
	var propaganda := report.propaganda_sequence
	_check(propaganda.order_sensitive, "propaganda sequence is order-sensitive")
	_check(propaganda.cause_action.id == &"planting_bomb", "propaganda cause reuses the same shared bomb-planting photo")
	_check(_ordered_ids(propaganda.cause_characters) == [&"opposition"], "propaganda cause is carried by opposition alone")
	_check(propaganda.conflict_action.id == &"peace_rally_victims", "propaganda conflict reuses the same shared victims photo")
	_check(_ordered_ids(propaganda.conflict_characters) == [&"soldiers"], "propaganda conflict is carried by soldiers alone")
	_check(propaganda.outcome_action.id == &"helping", "propaganda outcome is the same helping action")
	_check(_ordered_ids(propaganda.outcome_characters) == [&"soldiers", &"civilians"], "propaganda helping orders soldiers (helper) then civilians (helped)")
	_check(not propaganda.broadcast_lines.is_empty(), "propaganda sequence has a reporter recap script")
	_check(propaganda.reaction_lines.size() == 2 and propaganda.reaction_lines[0] == "…..", "propaganda reaction opens with the silent beat")

	_check(report.mismatch_line == "…None of this adds up.", "mismatch line matches the authored line")

	# The same {opposition, civilians} set in reverse order (or with soldiers
	# substituted) must not accidentally satisfy the wrong route.
	var reversed_truthful_outcome := ShotElement.new([_find(report, &"civilians"), _find(report, &"opposition")], _find_action(report, &"helping"))
	_check(not truthful.matches_slot(2, reversed_truthful_outcome), "reversing the helping order no longer matches the truthful outcome")
	_check(not propaganda.matches_slot(2, reversed_truthful_outcome), "reversing the helping order doesn't match propaganda either")


func _check_solve_flow() -> void:
	var packed_scene := load("res://scenes/gameplay/broadcast_interface.tscn") as PackedScene
	var ui := packed_scene.instantiate() as BroadcastInterface
	ui.instant_mode = true
	ui.use_news_broadcast_scene = false
	root.add_child(ui)
	for _frame in 4:
		await process_frame

	ui.broadcast_resolved.connect(_on_broadcast_resolved)
	var report := BroadcastDemoData.bombing_report()
	ui.load_report(report)
	_advance_through_playback(ui)
	_check(ui.phase == BroadcastInterface.Phase.EDITING, "intro finishes into the editing phase")

	# Truthful sequence.
	ui.cause_slot.place(ShotElement.new(report.truthful_sequence.cause_characters, report.truthful_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report.truthful_sequence.conflict_characters, report.truthful_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report.truthful_sequence.outcome_characters, report.truthful_sequence.outcome_action))
	_check(not ui.broadcast_button.disabled, "broadcast enabled at 3/3")
	ui._on_broadcast_pressed()
	_check(_resolved_count == 1, "broadcast_resolved fired for truthful sequence")
	_check(_last_matched, "truthful sequence matched")
	_advance_through_response(ui)
	_check(ui._playback_active and ui._playback_is_recap, "solving the only report starts its recap directly")
	_check(ui.dialogue_label.text.begins_with("And now, for Today's News."), "single-report recap still opens with the generic Today's News line")

	# Propaganda sequence — reload fresh since truthful already aired.
	ui.load_report(report)
	_advance_through_playback(ui)
	ui.cause_slot.place(ShotElement.new(report.propaganda_sequence.cause_characters, report.propaganda_sequence.cause_action))
	ui.conflict_slot.place(ShotElement.new(report.propaganda_sequence.conflict_characters, report.propaganda_sequence.conflict_action))
	ui.outcome_slot.place(ShotElement.new(report.propaganda_sequence.outcome_characters, report.propaganda_sequence.outcome_action))
	ui._on_broadcast_pressed()
	_check(_resolved_count == 2, "broadcast_resolved fired for propaganda sequence")
	_check(_last_matched, "propaganda sequence matched")
	_advance_through_response(ui)
	_check(ui._playback_active and ui._playback_is_recap, "solving propaganda also starts the recap")

	# Mismatch — reload fresh again; a non-match must return to editing, not air.
	ui.load_report(report)
	_advance_through_playback(ui)
	var suspicious := report.characters[0]
	var stray_action: ActionDef = report.available_actions[0]
	ui.cause_slot.place(ShotElement.new([suspicious], stray_action))
	ui.conflict_slot.place(ShotElement.new([suspicious], stray_action))
	ui.outcome_slot.place(ShotElement.new([suspicious], report.available_actions[2]))
	ui._on_broadcast_pressed()
	_check(_resolved_count == 3, "broadcast_resolved fired for unrecognized combination")
	_check(not _last_matched, "unrecognized combination does not match")
	_advance_through_response(ui)
	_check(ui.phase == BroadcastInterface.Phase.EDITING and ui._editing_enabled, "a mismatch returns to editing instead of airing")

	ui.queue_free()
	await process_frame


func _on_broadcast_resolved(sequence: BroadcastSequence, matched: bool) -> void:
	_resolved_count += 1
	_last_sequence = sequence
	_last_matched = matched


func _ordered_ids(characters: Array[CharacterDef]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for character in characters:
		ids.append(character.id)
	return ids


func _find(report: BroadcastReport, id: StringName) -> CharacterDef:
	for character in report.characters:
		if character.id == id:
			return character
	return null


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
