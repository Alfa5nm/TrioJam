extends SceneTree

const OUTPUT_DIR := "res://test_artifacts/day3"


func _init() -> void:
	_render_previews.call_deferred()


func _render_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_stairwell()
	await _capture_rooftop_dialogue()
	await _capture_briefing()
	await _capture_scope()
	await _capture_tv()
	print("DAY3_VISUAL_PREVIEW_PASS")
	quit()


func _capture_stairwell() -> void:
	var stairwell := (load("res://scenes/Day 3/day3_stairwell.tscn") as PackedScene).instantiate() as Day3Stairwell
	stairwell.get_node("CinematicDialogue").instant_mode = true
	root.add_child(stairwell)
	stairwell.get_node("HUD/Fade").modulate.a = 0.0
	for frame in 3:
		await process_frame
	_save("stairwell-start-and-guard.png")
	stairwell.queue_free()
	await process_frame


func _capture_rooftop_dialogue() -> void:
	var rooftop := (load("res://scenes/Day 3/day3_rooftop.tscn") as PackedScene).instantiate() as Day3Rooftop
	var dialogue := rooftop.get_node("CinematicDialogue") as CinematicDialogue
	dialogue.characters_per_second = 600.0
	root.add_child(rooftop)
	rooftop.get_node("HUD/Fade").modulate.a = 0.0
	dialogue.show_line("I feel like I chased an impossible dream in the beginning. Now now it’s biting me, and the people of this country on its back.", 10.0, rooftop.player, false)
	for frame in 16:
		await process_frame
	_save("rooftop-dialogue-layout.png")
	rooftop.queue_free()
	await process_frame


func _capture_briefing() -> void:
	var room := (load("res://scenes/Day 3/day3_briefing_room.tscn") as PackedScene).instantiate() as Day3BriefingRoom
	room.timing_scale = 0.01
	var dialogue := room.get_node("CinematicDialogue") as CinematicDialogue
	dialogue.characters_per_second = 500.0
	root.add_child(room)
	room.get_node("HUD/Fade").modulate.a = 0.0
	dialogue.show_bark("We have become more efficient, yet the leader is still alive.", "Company Representative", room.get_node("Suit/DialogueAnchor"), 10.0)
	for frame in 5:
		await process_frame
	_save("briefing-room-proportions.png")
	room.queue_free()
	await process_frame


func _capture_scope() -> void:
	var scope := (load("res://scenes/Day 3/day3_scope_scene.tscn") as PackedScene).instantiate() as Day3ScopeScene
	scope.play_intro_on_ready = false
	scope.auto_advance_to_finale = false
	root.add_child(scope)
	scope.get_node("ScopeUI/Fade").modulate.a = 0.0
	await process_frame
	await process_frame
	_save("peace-leader-scope.png")
	scope.queue_free()
	await process_frame


func _capture_tv() -> void:
	var finale := (load("res://scenes/Day 3/day3_finale.tscn") as PackedScene).instantiate() as Day3Finale
	finale.play_on_ready = false
	finale.instant_mode = true
	root.add_child(finale)
	await process_frame
	finale.image.texture = load(Day3Finale.CG["tv_backdrop"])
	finale.image.modulate.a = 1.0
	finale.tv_broadcast.visible = true
	finale.tv_broadcast.modulate.a = 1.0
	finale.tv_broadcast.set_talking(true)
	await process_frame
	await process_frame
	_save("apartment-tv-broadcast.png")
	finale.queue_free()
	await process_frame


func _save(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename)
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save " + path)
