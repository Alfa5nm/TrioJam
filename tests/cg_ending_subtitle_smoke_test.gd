extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/Day 2/day2_breakdown.tscn") as PackedScene
	_check(packed != null, "MC breakdown CG scene loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate() as Day2Breakdown
	scene.play_on_ready = false
	scene.auto_transition_to_day3 = false
	root.add_child(scene)
	await process_frame
	var style := scene.caption_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(is_zero_approx(style.bg_color.a), "MC breakdown uses boxless subtitles")
	_check(scene.caption.get_theme_font(&"font").resource_path.ends_with("Newsreader.ttf"), "MC breakdown matches the Day 1 ending serif typeface")
	_check(scene.caption.get_theme_font_size(&"font_size") == 31, "MC breakdown matches the Day 1 ending subtitle scale")
	_check(scene.caption.get_theme_constant(&"outline_size") >= 4, "boxless subtitle remains legible with a dark outline")
	_check(scene.caption.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "MC breakdown subtitle is lower-center aligned")
	_check(scene.caption_panel.position.y >= 490.0 and scene.caption_panel.position.y + scene.caption_panel.size.y <= 700.0, "MC breakdown subtitle remains inside the lower safe area")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene._typing = true
	scene._input(click)
	_check(scene._skip_requested, "mouse click completes active MC breakdown typewriter text")
	scene._typing = false
	scene._input(click)
	_check(scene._advance_requested, "mouse click advances an exposed MC breakdown subtitle")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("CG_ENDING_SUBTITLE_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
