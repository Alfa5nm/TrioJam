extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("CINEMATIC_DIALOGUE_DYNAMIC_LAYOUT_TEST_START")
	root.content_scale_size = Vector2i(1280, 720)
	var packed := load("res://scenes/ui/cinematic_dialogue.tscn") as PackedScene
	var dialogue := packed.instantiate() as CinematicDialogue
	root.add_child(dialogue)
	await process_frame

	dialogue._configure_ambient_bark("MC", "Hm...?", null)
	await _settle_layout()
	var short_size := dialogue.bubble.size
	_check(short_size.x <= 260.0 and short_size.y <= 90.0, "short barks use a compact speech bubble")

	dialogue._configure_ambient_bark(
		"MC",
		"There’s apparently a peace leader that’s going to tie both of the teams in order to bring peace. What is there slogan again…?",
		null
	)
	await _settle_layout()
	var rally_size := dialogue.bubble.size
	_check(rally_size.x <= dialogue.bark_width + 0.1, "long barks remain within their authored maximum width")
	_check(rally_size.y >= short_size.y and rally_size.y <= 190.0, "long barks grow only to their measured wrapped-text height")
	_check(dialogue.panel.size.y <= 176.0, "the rally line has no empty fixed-height lower half")

	dialogue._configure_standard_line("Choices… choices…")
	await _settle_layout()
	var standard_size := dialogue.bubble.size
	_check(standard_size.x < dialogue.standard_width and standard_size.y <= 90.0, "short cinematic lines shrink in both dimensions")

	# Exercise the real Day 2 scene after its route-opening bark, since a bubble
	# must also shrink correctly when consecutive lines have different lengths.
	var rally := (load("res://scenes/Day 2/day2_peace_rally.tscn") as PackedScene).instantiate() as Day2PeaceRallyController
	rally.timing_scale = 0.001
	var rally_dialogue := rally.get_node("CinematicDialogue") as CinematicDialogue
	rally_dialogue.instant_mode = true
	root.add_child(rally)
	for _frame in range(60):
		await process_frame
		if rally.state == Day2PeaceRallyController.State.FREE_ROAM:
			break
	var anchor := rally.get_node("DialogueAnchors/MC") as Node2D
	rally_dialogue.show_bark(
		"There’s apparently a peace leader that’s going to tie both of the teams in order to bring peace. What is there slogan again…?",
		"MC",
		anchor,
		1.0
	)
	await _settle_layout()
	_check(rally_dialogue.panel.size.y <= 176.0, "Day 2 rally dialogue shrinks after the route-opening line")

	if failures == 0:
		print("CINEMATIC_DIALOGUE_DYNAMIC_LAYOUT_TEST_PASS")
	dialogue.hide_immediately()
	rally_dialogue.hide_immediately()
	dialogue.queue_free()
	rally.queue_free()
	await process_frame
	quit(failures)


func _settle_layout() -> void:
	for _frame in range(8):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
		return
	failures += 1
	push_error("FAIL: " + message)
