extends SceneTree

const OUTPUT := "res://test_artifacts/day0/day0-curtain-cg-dialogue.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_artifacts/day0"))
	var scene := (load("res://scenes/narrative/day0_epilogue.tscn") as PackedScene).instantiate() as Day0Epilogue
	scene.instant_mode = true
	scene.auto_advance_to_day1 = false
	root.add_child(scene)
	await process_frame
	scene._enter_bedroom()
	scene.bedroom_fade.modulate.a = 0.0
	for frame in 12:
		await process_frame
	var screenshot := root.get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.save_png(ProjectSettings.globalize_path(OUTPUT)) != OK:
		push_error("Could not save Day 0 epilogue preview")
		quit(1)
		return
	print("DAY0_EPILOGUE_VISUAL_PREVIEW_PASS")
	quit()
