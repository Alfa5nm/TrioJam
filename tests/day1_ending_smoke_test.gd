extends SceneTree

var failures := 0
var _session: Node
var _original_profile_path := ""
var _ending_finished_observed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY1_ENDING_TEST_START")
	_session = root.get_node("GameSession")
	_original_profile_path = _session.profile_path
	_session.profile_path = "user://day1_ending_smoke_test.cfg"
	for checkpoint_route in [&"truthful", &"propaganda"]:
		for seedless_route in [&"truthful", &"propaganda"]:
			await _check_route_combination(checkpoint_route, seedless_route)
	await _check_day1_broadcast_context()
	await _check_cutscene_completion()
	_check_session_api()
	_session.profile_path = _original_profile_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day1_ending_smoke_test.cfg"))
	if failures == 0:
		print("DAY1_ENDING_TEST_PASS")
	quit(failures)


func _check_route_combination(checkpoint_route: StringName, seedless_route: StringName) -> void:
	_session.broadcast_context = &"day1"
	_session.day1_checkpoint_route = checkpoint_route
	_session.day1_seedless_route = seedless_route
	var packed := load("res://scenes/Day 1/Side Scroll Section/Day 1 ending.tscn") as PackedScene
	var ending := packed.instantiate() as Day1EndingController
	ending.instant_mode = true
	ending.auto_transition_to_day2 = false
	root.add_child(ending)
	for _frame in 12:
		await process_frame
	_check(ending.checkpoint_route == checkpoint_route, "checkpoint route is read for %s/%s" % [checkpoint_route, seedless_route])
	_check(ending.seedless_route == seedless_route, "seedless route is read for %s/%s" % [checkpoint_route, seedless_route])
	_check(ending.truth_background.visible == (checkpoint_route == &"truthful"), "truth background visibility follows Report 1")
	_check(ending.propaganda_background.visible == (checkpoint_route == &"propaganda"), "propaganda background visibility follows Report 1")
	_check(ending.selected_report2_narration() == (Day1EndingController.TRUTH_REPORT_2 if seedless_route == &"truthful" else Day1EndingController.PROPAGANDA_REPORT_2), "Report 2 selects only the closing narration")
	_check(ending.get_node("Audio/Night").stream != null, "night ambience is assigned")
	_check(ending.get_node("Audio/Route").stream != null, "route ambience is assigned")
	_check(ending.get_tree().get_nodes_in_group(&"__unused_day1_group").is_empty(), "ending initializes without hidden group dependencies")
	var light_count := 0
	for child in ending.get_children():
		if child is PointLight2D:
			light_count += 1
	_check(light_count >= 3, "night scene creates localized shadow-casting lights")
	ending.queue_free()
	await process_frame


func _check_day1_broadcast_context() -> void:
	_session.broadcast_context = &"day1"
	_session.day1_checkpoint_route = &""
	_session.day1_seedless_route = &""
	var packed := load("res://scenes/gameplay/broadcast_interface.tscn") as PackedScene
	var ui := packed.instantiate() as BroadcastInterface
	ui.instant_mode = true
	ui.use_news_broadcast_scene = false
	root.add_child(ui)
	for _frame in 4:
		await process_frame
	_check(ui.report.report_id == &"day1_checkpoint_killing", "Day 1 context loads Akiibot’s chained reports")
	_check(ui._report_chain.size() == 2, "Day 1 broadcast contains both independent reports")
	var report := ui._report_chain[0]
	ui._record_day1_route(report, report.truthful_sequence)
	_check(_session.get_day1_report_route(report.report_id) == &"truthful", "broadcast chain records the selected route")
	ui.queue_free()
	await process_frame


func _check_cutscene_completion() -> void:
	_session.day1_checkpoint_route = &"truthful"
	_session.day1_seedless_route = &"propaganda"
	var packed := load("res://scenes/Day 1/Side Scroll Section/Day 1 ending.tscn") as PackedScene
	var ending := packed.instantiate() as Day1EndingController
	ending.instant_mode = true
	ending.auto_transition_to_day2 = false
	root.add_child(ending)
	for _frame in 12:
		await process_frame
	_ending_finished_observed = false
	ending.ending_finished.connect(func(): _ending_finished_observed = true)
	ending._start_door_sequence()
	var frames := 0
	while not _ending_finished_observed and frames < 120:
		await process_frame
		frames += 1
	_check(_ending_finished_observed, "door sequence reaches the final Day 1 beat")
	_check(ending.final_image.texture == load("res://assets/art/Day1 Scene 1/Day 1 ending/day1end.png"), "supplied final illustration is used")
	_check(Day1EndingController.FINAL_QUESTION == "If I could go back in time, would it have been easier?", "final question is preserved exactly")
	_check(_session.checkpoint == "day2", "final cutscene saves the temporary Day 2 handoff")
	ending.queue_free()
	await process_frame


func _check_session_api() -> void:
	_session.begin_day1_broadcast()
	_check(_session.broadcast_context == &"day1", "begin_day1_broadcast selects the Day 1 chain")
	_session.set_day1_report_route(&"day1_checkpoint_killing", &"truthful")
	_session.set_day1_report_route(&"day1_seedless_fruit", &"propaganda")
	_check(_session.get_day1_report_route(&"day1_checkpoint_killing") == &"truthful", "Report 1 route persists independently")
	_check(_session.get_day1_report_route(&"day1_seedless_fruit") == &"propaganda", "Report 2 route persists independently")
	_session.complete_day1()
	_check(_session.checkpoint == "day2", "completing Day 1 arms the Day 2 checkpoint")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
