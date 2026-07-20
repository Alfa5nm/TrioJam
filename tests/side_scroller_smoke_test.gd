extends SceneTree

var failures := 0


func _init() -> void:
	print("ROOFTOP_STAIRWELL_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/main/main.tscn") as PackedScene
	_check(packed_scene != null, "rebuilt rooftop scene loads")
	if packed_scene == null:
		quit(1)
		return

	var level := packed_scene.instantiate()
	var intro_lines: Array[String] = []
	var intro_dialogue := level.get_node("CinematicDialogue") as CinematicDialogue
	intro_dialogue.instant_mode = true
	intro_dialogue.line_started.connect(func(text: String) -> void: intro_lines.append(text))
	root.add_child(level)
	for _frame in 90:
		await physics_frame

	var player := level.get_node("Player") as Player
	var camera := level.get_node("CinematicCamera") as CinematicCamera
	_check(_action_has_key(&"move_left", KEY_A) and _action_has_key(&"move_left", KEY_LEFT), "move left accepts A and the Left arrow")
	_check(_action_has_key(&"move_right", KEY_D) and _action_has_key(&"move_right", KEY_RIGHT), "move right accepts D and the Right arrow")
	_check(_action_has_key(&"interact", KEY_E) and _action_has_key(&"interact", KEY_SPACE), "confirm and interaction accept E and Space")
	_check(_action_has_key(&"jump", KEY_W) and not _action_has_key(&"jump", KEY_SPACE), "jump retains W without conflicting with Space confirm")
	_check(level.get_node("HUD/DoorPrompt/Label").text == "E / SPACE  ENTER ROOFTOP", "Day Zero prompt advertises both confirm keys")
	_check(intro_lines == ["…", "…I can’t even remember the last time I felt the autonomy of my own actions.", "This… feels good."], "Day Zero stairwell intro uses the revised script in exact order")
	var player_screen_position := level.get_viewport().get_canvas_transform() * player.global_position
	var dialogue_bubble_bottom := intro_dialogue.bubble.position.y + intro_dialogue.bubble.size.y
	_check(player_screen_position.y - dialogue_bubble_bottom >= 240.0, "Day Zero dialogue bubble clears the MC's head with comfortable spacing")
	_check(level.get_node("MoodGrade") is CanvasModulate, "stairwell receives the dull Day Zero grade")
	_check(level.get_node("CinematicDialogue").chapter_title.text.is_empty(), "Scene0 no longer contains a DAY ZERO chapter card")
	_check(is_equal_approx(player.move_speed, 260.0), "stairwell traversal uses the faster 260 px/s movement")
	_check(camera.target_zoom == Vector2(1.22, 1.22) and camera.zoom.distance_to(camera.target_zoom) < 0.01, "stairwell camera eases into the closer 1.22x character focus")
	_check(level.has_node("SpectrumLightFlicker") and level.get_node("WarmLandingLight").shadow_enabled, "stairwell uses audio-reactive lighting and soft 2D shadows")
	var lit_background := level.get_node("Layer01BackgroundShell").texture as CanvasTexture
	_check(lit_background != null and lit_background.normal_texture != null, "stairwell environment carries generated 2D normal textures")
	_check(level.has_node("LandingLightBeam") and level.get_node("LandingLightBeam").material is ShaderMaterial, "landing fixture includes a soft additive light-volume treatment")
	_check(level.get_node("CinematicDialogue/Blip").stream != null, "Day Zero dialogue has a restrained text blip")
	var dialogue_line := level.get_node("CinematicDialogue/Dialogue/Bubble/Panel/Margin/Line") as Label
	var dialogue_panel := level.get_node("CinematicDialogue/Dialogue/Bubble/Panel") as PanelContainer
	var dialogue_style := dialogue_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(dialogue_line.get_theme_font(&"font").resource_path.ends_with("Newsreader.ttf"), "character dialogue uses the newsletter font")
	_check(dialogue_line.get_theme_color(&"font_color") == Color.WHITE, "character dialogue is pure white")
	_check(dialogue_style.bg_color.is_equal_approx(Color(0.0431373, 0.113725, 0.301961, 0.96)), "character dialogue uses the navy backdrop")
	_check(dialogue_style.border_color.is_equal_approx(Color(0.133333, 0.839216, 1.0, 0.96)), "character dialogue uses the neon-blue outline")
	_check(level.get_node("CinematicDialogue/Dialogue/Bubble").size.x <= 440.0, "dialogue uses a compact hovering character bubble")
	_check(player.animated_sprite.scale.x >= 0.6, "character scale matches the stairwell architecture")
	_check(player.footstep_stream != null, "stairwell concrete footstep is assigned")
	_check(player.footstep_stream_alt_a != null and player.footstep_stream_alt_b != null, "stairwell footsteps rotate through three samples")
	var overall_ambience := level.get_node("Audio/RoomTone") as AudioStreamPlayer
	_check(overall_ambience.playing, "eerie overall ambience starts with the scene")
	_check(overall_ambience.stream.resource_path.ends_with("alex_jauk-eerie-atmosphere-ambience-372558.mp3"), "Day Zero uses the supplied eerie ambience track")
	_check(overall_ambience.stream is AudioStreamMP3 and (overall_ambience.stream as AudioStreamMP3).loop, "eerie overall ambience loops continuously")
	_check(level.get_node("Audio/Electrical").playing, "electrical ambience loops from the landing fixture")
	_check(level.get_node("Audio/Electrical").bus == &"Electrical", "electrical fixture is routed through the analyzed flicker bus")
	var lower_room_tone_db: float = overall_ambience.volume_db
	var lower_surface := level.get_node("Line2DFloorToMidflightCollider/StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	var upper_surface := level.get_node("Line2DFloorToMidflightCollider2/StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	var lower_highlight := level.get_node("StairHighlights/LowerRoute") as Node2D
	var upper_highlight := level.get_node("StairHighlights/UpperRoute") as Node2D
	var foreground_railing := level.get_node("railing") as Sprite2D
	var upper_landing_railing := level.get_node("UpperLandingFrontRail") as Sprite2D
	var upper_flight_railing := level.get_node("UpperFlightForegroundRail") as Sprite2D
	var upper_flight_fascia := level.get_node("UpperFlightFascia") as Sprite2D
	var background_shell := level.get_node("Layer01BackgroundShell") as Sprite2D
	var background_origin := Vector2(642.0, 360.75)

	_check(player.is_on_floor(), "player settles on the lower floor")
	_check(not lower_surface.disabled, "lower staircase starts active")
	_check(upper_surface.disabled, "top staircase starts inactive")
	_check(lower_highlight.modulate.a > upper_highlight.modulate.a, "lower staircase starts highlighted")
	_check(foreground_railing.z_index > player.z_index, "foreground railing renders over the player")
	_check(upper_landing_railing.z_index > player.z_index, "top-door landing rail renders over the player's lower body")
	_check(upper_flight_railing.z_index > player.z_index, "upper-flight staircase railing renders in front of the player")
	_check(upper_flight_fascia.z_index < player.z_index, "upper-flight fascia renders behind the player")
	_check(level.get_node("StairHighlights").z_index < player.z_index, "route highlights never tint the player")

	Input.action_press(&"move_right")
	var lower_traversal_frames := 0
	while lower_traversal_frames < 245 and not (level.upper_route_active and player.global_position.x > 1080.0):
		await physics_frame
		lower_traversal_frames += 1
	_check(is_equal_approx(player.animated_sprite.speed_scale, 260.0 / 165.0), "walk animation cadence scales with the faster traversal")
	Input.action_release(&"move_right")
	await physics_frame
	_check(level.upper_route_active, "right landing activates the upper route")
	_check(lower_surface.disabled, "lower staircase collision switches off")
	_check(not upper_surface.disabled, "top staircase collision switches on")
	_check(player.global_position.x > 900.0, "player reaches the middle landing")
	_check(player.global_position.y < 430.0, "lower staircase carries the player upward")
	_check(background_shell.position != background_origin, "camera movement produces restrained background parallax")
	_check((background_shell.position - background_origin).abs().x <= 10.01, "stairwell parallax remains inside its authored horizontal margin")

	for _frame in 45:
		await process_frame
	_check(upper_highlight.modulate.a > lower_highlight.modulate.a, "highlight transfers to the top staircase")

	Input.action_press(&"move_left")
	var upper_traversal_frames := 0
	while upper_traversal_frames < 230 and not (player.global_position.x < 620.0 and player.global_position.y < 260.0):
		await physics_frame
		upper_traversal_frames += 1
	Input.action_release(&"move_left")
	_check(player.global_position.x < 620.0, "player reverses onto the top staircase")
	_check(player.global_position.y < 260.0, "player reaches the upper landing")
	_check(level.get_node("Audio/RoomTone").volume_db < lower_room_tone_db - 2.0, "room tone recedes toward the electrical landing")
	Input.action_press(&"move_left")
	var door_approach_frames := 0
	while door_approach_frames < 90 and not level.get_node("HUD/DoorPrompt").visible:
		await physics_frame
		door_approach_frames += 1
	Input.action_release(&"move_left")
	_check(level.get_node("HUD/DoorPrompt").visible, "top door offers the rooftop transition")
	player.animated_sprite.play(&"walk")
	player.velocity.x = player.move_speed
	player.play_door_interaction()
	await physics_frame
	_check(player.animated_sprite.animation == &"interact" and not player.controls_enabled, "door interaction overrides and locks the walk animation")
	_check(is_zero_approx(player.velocity.x) and not player.footstep_dust.emitting, "door interaction immediately stops locomotion effects")

	player.controls_enabled = true
	player.global_position.y = player.fall_limit + 20.0
	await physics_frame
	await physics_frame
	_check(not level.upper_route_active, "fall recovery resets the staircase phase")
	_check(not lower_surface.disabled and upper_surface.disabled, "fall recovery restores the lower route")
	_check(player.global_position.distance_to(level._spawn_position) < 40.0, "fall recovery returns the player to the recorded entrance spawn")

	level.queue_free()
	for _frame in 4:
		await process_frame
	if failures == 0:
		print("ROOFTOP_STAIRWELL_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _action_has_key(action: StringName, expected_keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null and (key_event.physical_keycode == expected_keycode or key_event.keycode == expected_keycode):
			return true
	return false
