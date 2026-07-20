extends SceneTree

const OUTPUT_DIR := "res://test_artifacts/cg-subtitles"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.content_scale_size = Vector2i(1280, 720)
	var epilogue := (load("res://scenes/narrative/day0_epilogue.tscn") as PackedScene).instantiate() as Day0Epilogue
	epilogue.instant_mode = true
	epilogue.auto_advance_to_day1 = false
	root.add_child(epilogue)
	await process_frame
	epilogue._enter_bedroom()
	epilogue.bedroom_fade.modulate.a = 0.0
	for _frame in 8:
		await process_frame
	_save("day0-curtain-boxless.png")
	epilogue.queue_free()
	await process_frame

	var breakdown := (load("res://scenes/Day 2/day2_breakdown.tscn") as PackedScene).instantiate() as Day2Breakdown
	breakdown.play_on_ready = false
	breakdown.auto_transition_to_day3 = false
	root.add_child(breakdown)
	await process_frame
	breakdown.cg.modulate.a = 1.0
	breakdown.darkness.modulate.a = 0.08
	breakdown.caption_panel.visible = true
	breakdown.caption.text = "I couldn't be the one to tell you what was off, I missed a whole week… maybe a few weeks of work."
	breakdown.caption.visible_characters = -1
	for _frame in 8:
		await process_frame
	_save("day3-transition-breakdown-boxless.png")
	print("CG_ENDING_SUBTITLE_VISUAL_PREVIEW_PASS")
	quit()


func _save(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename)) != OK:
		push_error("Could not save " + filename)
