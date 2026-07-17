extends SceneTree

var failures := 0


func _init() -> void:
	print("DAY0_FLOW_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	var transition := root.get_node_or_null("SceneTransition")
	_check(session != null, "GameSession autoload is available")
	_check(transition != null, "SceneTransition autoload is available")
	if session == null or transition == null:
		quit(1)
		return

	session.profile_path = "user://day0_test_profile.cfg"
	session.settings_path = "user://day0_test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.profile_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.settings_path))
	session.player_name = "MC"
	session.checkpoint = ""

	_check(session.validate_player_name("Ana-Maria"), "hyphenated name is accepted")
	_check(session.validate_player_name("O'Neil"), "apostrophe name is accepted")
	_check(session.validate_player_name("  Jane Doe  "), "surrounding whitespace is trimmed")
	_check(not session.validate_player_name("123"), "name requires at least one letter")
	_check(not session.validate_player_name("ElevenCharsX"), "name is limited to ten characters")
	session.begin_day_zero()
	_check(session.player_name == "MC" and session.checkpoint == "scene0", "New Game starts Day Zero without asking for a name")
	session.player_name = "MC"
	session.checkpoint = ""
	session.load_profile()
	_check(session.player_name == "MC" and session.continue_scene_path().ends_with("main.tscn"), "unnamed Day Zero Continue checkpoint persists")
	session.master_volume = 0.72
	session.sfx_volume = 0.61
	session.ambience_volume = 0.53
	session.ui_volume = 0.84
	session.fullscreen = false
	session.resolution = Vector2i(1600, 900)
	session.save_settings()
	session.master_volume = 1.0
	session.resolution = Vector2i(1280, 720)
	session.load_settings()
	_check(is_equal_approx(session.master_volume, 0.72) and is_equal_approx(session.ui_volume, 0.84), "volume settings persist independently")
	_check(session.resolution == Vector2i(1600, 900), "selected 16:9 resolution persists")

	var menu_scene := load("res://scenes/menu/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(menu.get_node("Title").text == "Now. Todays' News.", "main-menu title punctuation is exact")
	_check(not menu.continue_button.disabled, "Continue enables for a saved Day 0 checkpoint")
	_check(not menu.has_node("NamePanel"), "main menu no longer contains the naming system")
	_check(not menu.has_node("Prologue"), "removed opening narration is absent from the menu")
	menu.queue_free()
	await process_frame

	var broadcast_scene := load("res://scenes/gameplay/broadcast_interface.tscn") as PackedScene
	var broadcast := broadcast_scene.instantiate() as BroadcastInterface
	broadcast.instant_mode = true
	broadcast.use_news_broadcast_scene = false
	root.add_child(broadcast)
	await process_frame
	_check(broadcast._playback_active, "Government interrogation now begins inside the Broadcast Interface")
	_check(broadcast.speaker_portrait.visible, "Broadcast interrogation opens with the Government Man portrait")
	for _index in range(3):
		broadcast.continue_button.pressed.emit()
	_check(broadcast._awaiting_name, "Broadcast interrogation pauses for naming after the identification request")
	_check(broadcast.name_input.max_length == 10, "embedded Broadcast name field enforces ten characters")
	broadcast.name_input.text = "Jane Doe"
	broadcast._confirm_name()
	_check(session.player_name == "Jane Doe", "Broadcast interrogation stores the normalized player name")
	_check(broadcast.dialogue_label.text == "Jane Doe.", "entered name becomes the MC's spoken response inside Broadcast")
	_check(broadcast.report.characters[1].display_name == "Jane Doe", "Broadcast roster updates to the entered name")
	_check(broadcast.blip.bus == &"UI", "Broadcast interrogation blip uses the UI bus")
	_check(not ResourceLoader.exists("res://scenes/narrative/interrogation_placeholder.tscn"), "standalone interrogation scene is retired")
	session.checkpoint = "interrogation"
	_check(session.continue_scene_path().ends_with("broadcast_interface.tscn"), "legacy interrogation saves resume inside Broadcast")
	broadcast.queue_free()
	await process_frame

	_check(transition.door_open.stream.get_length() > 1.45 and transition.door_open.stream.get_length() < 1.56, "door-opening cue is trimmed to about 1.5 seconds")
	_check(transition.door_close.stream.get_length() < 4.1, "door-closing silent tail is removed")
	_check(transition.door_open.bus == &"SFX" and transition.door_close.bus == &"SFX", "persistent door cues use the SFX bus")
	_check(AudioServer.get_bus_index(&"Ambience") >= 0 and AudioServer.get_bus_index(&"UI") >= 0, "Master, SFX, Ambience, and UI buses are loaded")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "16:9 keep letterboxing remains enabled")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.profile_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.settings_path))
	if failures == 0:
		print("DAY0_FLOW_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
