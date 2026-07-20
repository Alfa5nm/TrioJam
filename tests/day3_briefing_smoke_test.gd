extends SceneTree

var failures := 0
var observed_lines: Array[String] = []
var cg_visible_by_line := {}
var cg_texture_by_line := {}
var bubble_x_by_line := {}
var bark_color_by_line := {}
var bark_border_by_line := {}
var cg_placement_by_line := {}
var cg_color_by_line := {}
var cg_style_by_line := {}
var cg_position_by_line := {}
var approached := false
var retreated := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY3_BRIEFING_TEST_START")
	var session := root.get_node("GameSession")
	var old_profile: String = session.profile_path
	session.profile_path = "user://day3_briefing_smoke_test.cfg"
	var packed := load("res://scenes/Day 3/day3_briefing_room.tscn") as PackedScene
	var room := packed.instantiate() as Day3BriefingRoom
	room.timing_scale = 0.01
	var opening_player_x: float = room.get_node("Player").position.x
	room.approach_finished.connect(func(): approached = true)
	room.retreat_finished.connect(func(): retreated = true)
	room.cg_line_started.connect(func(speaker: String, text: String, placement: StringName):
		observed_lines.append(text)
		cg_visible_by_line[text] = room.cg_overlay.visible
		cg_texture_by_line[text] = room.cg_image.texture
		cg_placement_by_line[text] = placement
		var label: RichTextLabel = room.cg_top_text if placement == &"top" else room.cg_bottom_text
		var panel: PanelContainer = room.cg_top_panel if placement == &"top" else room.cg_bottom_panel
		cg_color_by_line[text] = label.get_theme_color("default_color")
		cg_style_by_line[text] = panel.get_theme_stylebox(&"panel")
		cg_position_by_line[text] = panel.position
	)
	var dialogue := room.get_node("CinematicDialogue") as CinematicDialogue
	dialogue.instant_mode = true
	dialogue.timing_scale = 0.01
	dialogue.line_started.connect(func(text: String):
		observed_lines.append(text)
		cg_visible_by_line[text] = room.cg_overlay.visible
		cg_texture_by_line[text] = room.cg_image.texture
		bubble_x_by_line[text] = dialogue.bubble.position.x
		bark_color_by_line[text] = dialogue.line.get_theme_color(&"font_color")
		var panel_style := dialogue.panel.get_theme_stylebox(&"panel") as StyleBoxFlat
		if panel_style:
			bark_border_by_line[text] = panel_style.border_color
	)
	root.add_child(room)
	var frames := 0
	while not room._second_conversation_ready and frames < 300:
		await process_frame
		frames += 1
	_check(room._second_conversation_ready, "opening briefing reaches the first Normal mode section")
	_check(approached, "MC automatically walks from the entrance to the briefing table")
	_check(retreated, "MC performs the authored physical retreat")
	_check(room.player.controls_enabled, "side-scrolling control returns after the briefcase panic beat")
	_check(not room.cg_overlay.visible, "gun-case CG closes before the physical retreat")
	_check(room.player.position.x > opening_player_x + 250.0, "MC reaches the table before the briefing starts")
	_check(room.player.position.x <= room.approach_target.position.x - 48.0, "MC physically steps backward during the heartbeat beat")
	_check(not room.player.animated_sprite.flip_h, "MC remains facing the suited representative while retreating")
	var gun_case := load("res://assets/art/Day3/briefcase-gun.png")
	for cg_line in [
		"…What is this?",
		"…It’s a call to action",
		". . .No fucking way. You’re telling me to kill?!",
		"Now. Which side are you on?",
		"If you're not with us, you're against us. The higher-ups  don't like the odds of which side you’re taking.",
	]:
		_check(cg_visible_by_line.get(cg_line, false), "gun-case CG remains visible for: " + cg_line)
		_check(cg_texture_by_line.get(cg_line) == gun_case, "gun-case art remains active for: " + cg_line)
	_check(cg_placement_by_line.get("…What is this?") == &"bottom", "MC gun-case dialogue is positioned at the bottom")
	_check(cg_placement_by_line.get("…It’s a call to action") == &"top", "government gun-case dialogue is positioned at the top")
	var government_cg_color: Color = cg_color_by_line.get("…It’s a call to action", Color.WHITE)
	_check(government_cg_color.r > 0.9 and government_cg_color.g < 0.5, "government CG dialogue is red")
	_check(cg_style_by_line.get("Now. Which side are you on?") is StyleBoxEmpty, "earlier briefcase CG remains boxless")
	room._play_second_exchange()
	frames = 0
	while not room._exit_armed and frames < 300:
		await process_frame
		frames += 1
	_check(room._exit_armed, "second exchange arms the required room exit")
	_check(room.player.controls_enabled, "Normal mode returns before leaving the room")
	_check(not cg_visible_by_line.get("Y-You want me to kill the leader?!", true), "the follow-up exchange begins in normal side-scroll mode")
	_check(not cg_visible_by_line.get("With your expertise, it shouldn’t be so difficult.", true), "the expertise line remains in normal side-scroll mode")
	_check(not cg_visible_by_line.get("Don’t fret. You will be safe. Getting out of the country afterwards will be easy money. Your contributions will be remembered, for good or for the worse.", true), "the escape offer remains in normal side-scroll mode")
	var stressed_cg := load("res://assets/art/Day3/mc-stressing.png")
	for stress_line in [
		"Why the Peace Leader? He rejected violence.",
		"That is not for you to be concerned about. Please take the gun, and do fulfil your final duty.",
		"(Calling me complicit, and pushing another murder on my hands… I shouldn’t have shot the first guy. Fuck fuck fuck, everything is leading upto this path… )",
		"…Give me a minute Let me decide, it's my own life.",
		"You don’t have time. Go now, or we will decide for you.",
	]:
		_check(cg_visible_by_line.get(stress_line, false), "stressed-MC CG remains visible for: " + stress_line)
		_check(cg_texture_by_line.get(stress_line) == stressed_cg, "stressed-MC art remains active for: " + stress_line)
	_check(cg_placement_by_line.get("Why the Peace Leader? He rejected violence.") == &"bottom", "stressed-CG MC dialogue stays in the lower comic panel")
	_check(cg_placement_by_line.get("That is not for you to be concerned about. Please take the gun, and do fulfil your final duty.") == &"top", "stressed-CG government dialogue stays in the upper comic panel")
	var stressed_government_line := "That is not for you to be concerned about. Please take the gun, and do fulfil your final duty."
	var stressed_mc_line := "Why the Peace Leader? He rejected violence."
	_check(cg_style_by_line.get(stressed_government_line) is StyleBoxFlat, "stressed-CG government dialogue uses a framed dialogue box")
	_check(cg_style_by_line.get(stressed_mc_line) is StyleBoxFlat, "stressed-CG MC dialogue uses a framed dialogue box")
	var government_position: Vector2 = cg_position_by_line.get(stressed_government_line, Vector2.ZERO)
	var mc_position: Vector2 = cg_position_by_line.get(stressed_mc_line, Vector2.ZERO)
	_check(government_position.x > 500.0 and government_position.y < 80.0, "stressed-CG government box sits toward the upper-right")
	_check(mc_position.x < 100.0 and mc_position.y > 450.0, "stressed-CG MC box sits toward the lower-left")
	_check(observed_lines.has("We have become more efficient, yet the leader is still alive."), "briefing preserves the Suit opening line")
	var regular_government_line := "We have become more efficient, yet the leader is still alive."
	var regular_government_color: Color = bark_color_by_line.get(regular_government_line, Color.WHITE)
	var regular_government_border: Color = bark_border_by_line.get(regular_government_line, Color.WHITE)
	_check(regular_government_color.r > 0.9 and regular_government_color.g < 0.5, "regular Government Man dialogue text is red")
	_check(regular_government_border.r > 0.9 and regular_government_border.g < 0.5, "regular Government Man dialogue border is red")
	_check(observed_lines.has(". . .No fucking way. You’re telling me to kill?!"), "briefing preserves the authored panic line")
	_check(observed_lines.has("You don’t have time. Go now, or we will decide for you."), "briefing preserves the final ultimatum")
	_check(room.get_node("Suit").scale.x < 0.0, "representative placeholder faces the player")
	_check(absf(room.get_node("Suit").scale.x) >= 0.89, "representative placeholder is scaled to the room proportions")
	_check(room.player.presentation_scale >= 1.4, "MC is scaled to the room proportions")
	_check(dialogue.bark_width >= 540.0 and dialogue.bark_characters_per_line >= 44.0, "Day 3 uses wider readable world bubbles")
	_check(room.cg_top_panel.get_theme_stylebox(&"panel") is StyleBoxFlat and room.cg_bottom_panel.get_theme_stylebox(&"panel") is StyleBoxFlat, "stressed briefing CG retains its speaker-specific dialogue boxes")
	_check(room.cg_top_text.get_theme_constant(&"outline_size") >= 4 and room.cg_bottom_text.get_theme_constant(&"outline_size") >= 4, "briefing CG dialogue retains a readable outline")
	room._layout_cg_panel(room.cg_bottom_panel, room.cg_bottom_text, "A deliberately long stressed-MC line that must remain readable without returning to a dialogue box.", &"bottom")
	_check(room.cg_bottom_panel.size.x >= 680.0 and room.cg_bottom_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "stressed-MC dialogue box wraps safely in its lower-left slot")
	_check(room.get_node("Audio/HVAC").bus == &"Ambience", "briefing HVAC is routed through Ambience")
	_check(room.get_node("Audio/Fluorescent").bus == &"Electrical", "fluorescent hum is routed through Electrical")
	_check(room.get_node_or_null("TableLightOccluder") is LightOccluder2D and room.get_node_or_null("DoorLightOccluder") is LightOccluder2D, "briefing room lights cast against table and doorway occluders")
	_check((room.get_node("Dust") as CPUParticles2D).amount >= 48 and room.get_node_or_null("DoorMotes") is CPUParticles2D, "briefing room has layered atmospheric particles")
	_check((room.get_node("Audio/Heartbeat") as AudioStreamPlayer).stream.resource_path.ends_with("heartbeat-realistic.wav"), "briefing uses the licensed realistic heartbeat")
	dialogue.instant_mode = false
	room.timing_scale = 1.0
	var skip_test_text := "This cutscene line should complete immediately when the player skips its typewriter animation."
	room._show_cg_dialogue("MC", skip_test_text, &"bottom", 0.05)
	await process_frame
	var skip_event := InputEventAction.new()
	skip_event.action = &"interact"
	skip_event.pressed = true
	room._input(skip_event)
	_check(room.cg_bottom_text.visible_characters == -1, "E or Space completes the active cutscene dialogue line")
	_check(room._cg_dialogue_active, "completing a line does not skip the remaining autoplay hold")
	frames = 0
	while room._cg_dialogue_active and frames < 30:
		await process_frame
		frames += 1
	_check(not room._cg_dialogue_active, "cutscene dialogue continues autoplay after a skipped typewriter reveal")
	room.queue_free()
	await process_frame
	session.profile_path = old_profile
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day3_briefing_smoke_test.cfg"))
	if failures == 0:
		print("DAY3_BRIEFING_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
