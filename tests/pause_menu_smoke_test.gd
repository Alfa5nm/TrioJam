extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pause_menu := root.get_node_or_null("PauseMenu")
	var session := root.get_node_or_null("GameSession")
	_check(pause_menu != null, "global pause menu autoload exists")
	_check(InputMap.has_action(&"pause"), "Escape pause action is registered")
	_check(session.get_current_objective("res://scenes/Day 2/day2_peace_rally.tscn").contains("rally"), "Day 2 has a scene-aware objective")
	_check(session.get_current_objective("res://scenes/Day 3/day3_rooftop.tscn").contains("firing position"), "Day 3 has a scene-aware objective")

	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var level := packed.instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	pause_menu.open_pause_menu()
	await process_frame
	_check(paused, "opening the pause menu pauses gameplay")
	_check(pause_menu.overlay.visible, "pause overlay becomes visible")
	_check(pause_menu.objective_label.text == "Climb the stairwell to the upper landing.", "pause menu reads the level's live opening objective")
	_check(pause_menu.resume_button.has_focus(), "Resume receives controller and keyboard focus")
	pause_menu.close_pause_menu()
	_check(not paused and not pause_menu.overlay.visible, "closing the pause menu resumes gameplay")

	level.upper_route_active = true
	pause_menu.open_pause_menu()
	await process_frame
	_check(pause_menu.objective_label.text == "Climb the upper flight and reach the rooftop door.", "pause objective changes when the level phase changes")
	pause_menu.close_pause_menu()

	current_scene = null
	level.queue_free()
	await process_frame
	print("PAUSE_MENU_SMOKE_%s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
