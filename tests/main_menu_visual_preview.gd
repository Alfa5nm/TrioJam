extends SceneTree

const SHOOT_OUTPUT := "res://test_artifacts/main-menu/main-menu-shoot-ending.png"
const NOT_SHOOT_OUTPUT := "res://test_artifacts/main-menu/main-menu-not-shoot-ending.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_artifacts/main-menu"))
	var packed := load("res://scenes/menu/main_menu.tscn") as PackedScene
	if packed == null:
		push_error("Could not load the main menu scene")
		quit(1)
		return
	var session := root.get_node("GameSession")
	var original_context: StringName = session.broadcast_context
	var original_resolution: StringName = session.day3_resolution
	var original_completed_route: StringName = session.last_completed_day3_route
	session.broadcast_context = &"day3_complete"
	session.day3_resolution = &"shoot"
	session.last_completed_day3_route = &"shoot"
	var menu := packed.instantiate() as MainMenu
	root.add_child(menu)
	for frame in 12:
		await process_frame
	var screenshot := root.get_viewport().get_texture().get_image()
	if screenshot == null:
		push_error("Main-menu viewport did not produce an image")
		quit(1)
		return
	if screenshot.save_png(ProjectSettings.globalize_path(SHOOT_OUTPUT)) != OK:
		push_error("Could not save the SHOOT-ending menu preview")
		quit(1)
		return
	menu.queue_free()
	await process_frame
	session.last_completed_day3_route = &"not_shoot"
	var not_shoot_menu := packed.instantiate() as MainMenu
	root.add_child(not_shoot_menu)
	for frame in 12:
		await process_frame
	var not_shoot_screenshot := root.get_viewport().get_texture().get_image()
	if not_shoot_screenshot == null or not_shoot_screenshot.save_png(ProjectSettings.globalize_path(NOT_SHOOT_OUTPUT)) != OK:
		push_error("Could not save the NOT SHOOT-ending menu preview")
		quit(1)
		return
	not_shoot_menu.queue_free()
	session.broadcast_context = original_context
	session.day3_resolution = original_resolution
	session.last_completed_day3_route = original_completed_route
	await process_frame
	var finale := (load("res://scenes/Day 3/day3_finale.tscn") as PackedScene).instantiate() as Day3Finale
	finale.play_on_ready = false
	root.add_child(finale)
	await process_frame
	finale.credits.visible = true
	finale.credits_text.text = "Oroboros Route\n\nAND NOW, TODAY'S NEWS\n\nDesign and Lead Artist — Tasnuva (Raye)\n\nAudio Design, Level Design, Side-Scroll Technical Lead, E2E Polish — Farid\n\nBroadcast UI Interface Mechanics and Routing Mechanics — Akib"
	finale.credits_text.position.y = 295.0
	finale.credits_hint.modulate.a = 1.0
	for frame in 4:
		await process_frame
	var credits_image := root.get_viewport().get_texture().get_image()
	if credits_image == null or credits_image.save_png(ProjectSettings.globalize_path("res://test_artifacts/main-menu/ending-credits-title-screen.png")) != OK:
		push_error("Could not save the ending-credits preview")
		quit(1)
		return
	print("MAIN_MENU_VISUAL_PREVIEW_PASS")
	quit()
