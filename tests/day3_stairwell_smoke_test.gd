extends SceneTree

var failures := 0
var session: Node
var old_profile := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY3_STAIRWELL_TEST_START")
	session = root.get_node("GameSession")
	old_profile = session.profile_path
	session.profile_path = "user://day3_stairwell_smoke_test.cfg"
	session.day3_briefing_complete = true
	await _check_initial_entry()
	await _check_briefing_return()
	_check(session.CHECKPOINT_SCENES["day3_stairwell"] == "res://scenes/Day 3/day3_stairwell.tscn", "initial checkpoint maps to the bottom stairwell entry")
	_check(session.CHECKPOINT_SCENES["day3_stairwell_return"] == "res://scenes/Day 3/day3_stairwell_return.tscn", "post-briefing checkpoint maps to the upper landing return")
	session.profile_path = old_profile
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day3_stairwell_smoke_test.cfg"))
	if failures == 0:
		print("DAY3_STAIRWELL_TEST_PASS")
	quit(failures)


func _check_initial_entry() -> void:
	var stairwell := (load("res://scenes/Day 3/day3_stairwell.tscn") as PackedScene).instantiate() as Day3Stairwell
	stairwell.get_node("CinematicDialogue").instant_mode = true
	root.add_child(stairwell)
	await process_frame
	_check(not stairwell.returning_from_briefing, "normal Day 3 entry never inherits a stale briefing-complete save")
	_check(stairwell.player.global_position.distance_to(Vector2(259, 460)) < 14.0, "player begins at the bottom stairwell entrance")
	_check(stairwell.guard.visible, "guard is present before the briefing")
	_check(stairwell.guard.global_position.x >= 1070.0, "guard stands directly in front of the middle door")
	_check(stairwell.guard.scale.x < 0.0, "guard faces the approaching player")
	_check(not stairwell.dialogue.chapter.visible, "opening DAY 3 chapter header is absent")
	stairwell.queue_free()
	await process_frame


func _check_briefing_return() -> void:
	var stairwell := (load("res://scenes/Day 3/day3_stairwell_return.tscn") as PackedScene).instantiate() as Day3Stairwell
	stairwell.get_node("CinematicDialogue").instant_mode = true
	root.add_child(stairwell)
	for frame in 55:
		await process_frame
	_check(stairwell.returning_from_briefing, "dedicated return scene restores the post-briefing state")
	_check(stairwell.player.global_position.distance_to(Vector2(1015, 356)) < 18.0, "post-briefing return resumes at the middle landing")
	_check(not stairwell.guard.visible, "guard clears the door after admitting the player")
	_check(stairwell.upper_route_active, "upper stairs unlock after the briefing")
	stairwell.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
