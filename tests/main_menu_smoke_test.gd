extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node("GameSession")
	var original_context: StringName = session.broadcast_context
	var original_resolution: StringName = session.day3_resolution
	var original_completed_route: StringName = session.last_completed_day3_route
	session.broadcast_context = &"day3_complete"
	session.day3_resolution = &"shoot"
	session.last_completed_day3_route = &"shoot"
	var packed := load("res://scenes/menu/main_menu.tscn") as PackedScene
	_check(packed != null, "main menu scene loads")
	if packed == null:
		quit(1)
		return
	var menu := packed.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(menu.has_node("BackdropParallax/Image"), "parallax artwork layer exists")
	_check((menu.get_node("BackdropParallax/Image") as TextureRect).texture.resource_path.ends_with("main-menu-shoot-ending.png"), "completed SHOOT route selects the supplied bad-ending backdrop")
	_check(menu.has_node("TitleLogo"), "supplied title treatment exists")
	_check(menu.has_node("CRT"), "full-screen CRT pass exists")
	_check(menu.get_node("CRT").material is ShaderMaterial, "CRT pass has a shader")
	_check(menu.get_node("Title").text == "Now. Todays' News.", "legacy title contract remains compatible")
	for button_name in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var button := menu.get_node("Menu/" + button_name) as Button
		_check(button != null and button.custom_minimum_size == Vector2(370, 56), button_name + " uses the editorial menu proportions")
	_check(menu.get_node("Audio/Navigate").bus == &"UI", "menu interaction sound uses the UI bus")
	session.broadcast_context = &"day3"
	session.day3_resolution = &""
	menu._apply_completed_route_backdrop()
	_check((menu.get_node("BackdropParallax/Image") as TextureRect).texture.resource_path.ends_with("main-menu-shoot-ending.png"), "completed ending backdrop persists when a new playthrough begins")
	menu.queue_free()
	await process_frame
	session.last_completed_day3_route = &"not_shoot"
	var normal_menu := packed.instantiate() as MainMenu
	root.add_child(normal_menu)
	await process_frame
	_check((normal_menu.get_node("BackdropParallax/Image") as TextureRect).texture.resource_path.ends_with("main-menu-not-shoot-ending.png"), "completed NOT SHOOT route selects the supplied good-ending backdrop")
	normal_menu.queue_free()
	await process_frame
	session.last_completed_day3_route = &""
	var fresh_menu := packed.instantiate() as MainMenu
	root.add_child(fresh_menu)
	await process_frame
	_check((fresh_menu.get_node("BackdropParallax/Image") as TextureRect).texture.resource_path.ends_with("Untitled509_20260719170240.png"), "a profile without a completed finale uses the original menu backdrop")
	fresh_menu.queue_free()
	session.broadcast_context = original_context
	session.day3_resolution = original_resolution
	session.last_completed_day3_route = original_completed_route
	print("MAIN_MENU_SMOKE_%s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
