extends SceneTree

var failures := 0
var session: Node
var original_profile_path := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY2_STORY_TEST_START")
	session = root.get_node("GameSession")
	original_profile_path = session.profile_path
	session.profile_path = "user://day2_story_smoke_test.cfg"
	session.day1_seedless_route = &"truthful"
	session.broadcast_context = &"day2_story"
	await _check_world_scene()
	await _check_news_presenter()
	_check_route_persistence()
	session.profile_path = original_profile_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day2_story_smoke_test.cfg"))
	if failures == 0:
		print("DAY2_STORY_TEST_PASS")
	quit(failures)


func _check_world_scene() -> void:
	var packed := load("res://scenes/Day 2/day2_peace_rally.tscn") as PackedScene
	_check(packed != null, "Day 2 rally scene loads")
	var rally := packed.instantiate() as Day2PeaceRallyController
	rally.timing_scale = 0.001
	var overlay := rally.get_node("Day2CinematicOverlay") as Day2CinematicOverlay
	overlay.instant_mode = true
	overlay.timing_scale = 0.001
	var dialogue := rally.get_node("CinematicDialogue") as CinematicDialogue
	dialogue.instant_mode = true
	dialogue.timing_scale = 0.001
	var opening_lines: Array[String] = []
	var world_bubble_visibility: Array[bool] = []
	var overlay_control_visibility: Array[bool] = []
	var overlay_caption_visibility: Array[bool] = []
	var warning_caption_colors: Dictionary = {}
	var frame_ids: Array[StringName] = []
	var signal_counts := {"reveal": 0, "armed": 0, "aftermath": 0}
	rally.soldier_reveal_started.connect(func(): signal_counts["reveal"] += 1)
	rally.bomb_armed.connect(func(): signal_counts["armed"] += 1)
	rally.aftermath_staged.connect(func(): signal_counts["aftermath"] += 1)
	dialogue.line_started.connect(func(text: String):
		opening_lines.append(text)
		world_bubble_visibility.append(dialogue.visible and dialogue.get_node("Dialogue").visible)
	)
	overlay.frame_started.connect(func(frame_id: StringName):
		frame_ids.append(frame_id)
		overlay_control_visibility.append(overlay.visible and overlay.get_node("Root").visible and overlay.get_node("Root/Image").visible)
	)
	overlay.line_started.connect(func(_speaker: StringName, _text: String):
		overlay_caption_visibility.append(overlay.visible and overlay.get_node("Root/Caption").visible)
		if _text.begins_with("The beeping") or _text.begins_with("Wait"):
			warning_caption_colors[_text] = (overlay.get_node("Root/Caption/Margin/Text") as Label).get_theme_color(&"font_color")
	)
	root.add_child(rally)
	for _frame in range(45):
		await physics_frame
	_check(rally.get_node("Player") is Player, "playable MC is present")
	_check(rally.get_node("Collision/Ground").collision_layer == 2, "Day 2 ground uses the shared player's physics layer")
	_check(rally.player.is_on_floor(), "player settles on the Day 2 pavement instead of falling through the world")
	_check(rally.player.global_position.y < rally.player.fall_limit, "player remains above the fall boundary")
	_check(not opening_lines.is_empty(), "route-dependent opening dialogue becomes visible at scene start")
	_check(world_bubble_visibility.has(true), "world dialogue canvas and its presentation root are visible while a bark plays")
	_check(dialogue.visible, "CinematicDialogue canvas remains visible in-tree while its internal root is idle")
	_check(overlay.visible, "Day2CinematicOverlay canvas remains visible in-tree while its internal root is idle")
	_check(rally.get_node("HorizontalCamera") is Day1HorizontalCamera, "horizontal camera follows the player")
	_check(rally.get_node("World/NormalBackground").visible, "peaceful rally background starts visible")
	_check(not rally.get_node("World/AftermathBackground").visible, "aftermath is initially hidden")
	_check(not rally.get_node("NPCs/BlockadeCrowd").visible, "containment civilians are hidden before the blast")
	_check(not rally.get_node("Triggers/Containment").monitoring, "containment exchange is inactive before the blast")
	_check(rally.get_node("Collision/LeftDebris/Shape").disabled, "left retreat blocker is inactive before the blast")
	_check(rally.get_node("Audio/Explosion").bus == &"SFX", "explosion is routed through SFX")
	_check(is_equal_approx(rally.get_node("Audio/Explosion").volume_db, 0.0), "explosion impact is raised to full SFX level")
	_check(rally.get_node("Audio/RallyAmbience").bus == &"Ambience", "rally crowd is routed through Ambience")
	_check(is_equal_approx(rally.get_node("Audio/RallyAmbience").volume_db, -10.0), "supplied rally crowd is balanced beneath dialogue")
	_check(is_equal_approx(rally.get_node("Audio/PanicAmbience").volume_db, -9.0), "panic ambience is clearly audible after the blast")
	_check(is_equal_approx(rally.get_node("Audio/AftermathRumble").volume_db, -13.0), "aftermath rumble has stronger presence")
	_check(rally.get_node("Particles/DaylightMotes") is GPUParticles2D, "pre-blast leaves and motes are staged")
	_check(rally.get_node("Lighting/StageOccluder") is LightOccluder2D, "stage lighting has an authored occluder")
	var frames := 0
	while rally.state != Day2PeaceRallyController.State.FREE_ROAM and frames < 120:
		await process_frame
		frames += 1
	_check(rally.state == Day2PeaceRallyController.State.FREE_ROAM, "route-dependent fruit opening returns movement")
	rally.start_rally_sequence()
	frames = 0
	while rally.state != Day2PeaceRallyController.State.ESCAPE and frames < 360:
		await process_frame
		frames += 1
	_check(rally.state == Day2PeaceRallyController.State.ESCAPE, "camera rally, suspicion, and explosion reach playable escape")
	_check(frame_ids == [&"peace_leader_opening", &"suspicious_worker", &"peace_leader_warning"], "pre-blast CG frames play in authored order")
	_check(signal_counts["reveal"] == 1 and signal_counts["armed"] == 1 and signal_counts["aftermath"] == 1, "soldier reveal, arming, and aftermath signals each fire once")
	var warning_yellow := Color(1.0, 0.82, 0.24, 1.0)
	_check(warning_caption_colors.size() == 2 and warning_caption_colors.values().all(func(color: Color): return color.is_equal_approx(warning_yellow)), "beeping and Wait captions use the authored yellow warning color")
	_check(rally._bomb_warning_boost_db >= 10.0 and rally.get_node("Audio/BombBeep").volume_db >= -1.1, "bomb beep gains an audible warning boost before detonation")
	_check(not rally.get_node("NPCs/BombPlantingSoldier").visible, "planting pose is removed at detonation")
	_check(not overlay_control_visibility.has(false) and not overlay_caption_visibility.has(false), "CG image and dynamic caption controls are visible while frames play")
	_check(not rally.get_node("World/NormalBackground").visible, "detonation hides the peaceful background")
	_check(rally.get_node("World/AftermathBackground").visible, "detonation reveals the supplied damaged background")
	_check(rally.get_node("Particles/Smoke").emitting and rally.get_node("Particles/Embers").emitting, "blast starts smoke and ember layers")
	_check(not rally.get_node("Collision/LeftDebris/Shape").disabled, "blast blocks retreat to the left")
	_check(rally.get_node("Triggers/Containment").monitoring, "approaching the soldiers arms the containment exchange")
	_check(rally.get_node("NPCs/BlockadeCrowd").visible, "persistent civilians face the soldier line after the blast")
	_check(rally.get_node("NPCs/BlockadeCrowd").get_child_count() >= 4, "the right-side containment bottleneck has a readable civilian group")
	var blockade_crowd := rally.get_node("NPCs/BlockadeCrowd")
	var expected_default_poses := {
		"CivilianSpeaker": "r1c3-occupation-protester-b.png",
		"Mother": "r2c4-gossiping-gal-b.png",
		"StrugglingCivilian": "r4c1-anti-seedless-protester-a.png",
		"CivilianRear": "r2c3-gossiping-gal-a.png",
	}
	for civilian_name: String in expected_default_poses:
		var civilian := blockade_crowd.get_node(civilian_name) as Sprite2D
		_check(civilian != null, "%s uses a standing Sprite2D instead of a recoil animation" % civilian_name)
		if civilian != null:
			_check(civilian.texture.resource_path.ends_with(expected_default_poses[civilian_name]), "%s uses its original default NPC pose" % civilian_name)
	_check((blockade_crowd.get_node("CivilianSpeaker") as Sprite2D).scale.x > 0.0, "civilian speaker faces the soldiers")
	_check((blockade_crowd.get_node("Mother") as Sprite2D).scale.x < 0.0, "mother is flipped to face the soldiers")
	_check((blockade_crowd.get_node("StrugglingCivilian") as Sprite2D).scale.x > 0.0, "struggling civilian faces the soldiers")
	_check((blockade_crowd.get_node("CivilianRear") as Sprite2D).scale.x > 0.0, "rear civilian faces the soldiers")
	_check(not rally.get_node("NPCs/PeaceLeader").visible and not rally.get_node("NPCs/SuspiciousWorker").visible, "blast removes the leader and suspicious worker before aftermath")
	_check(not rally.get_node("NPCs/ForegroundPodium").visible, "normal-stage podium crop cannot leak over the aftermath")
	_check(rally.get_node("NPCs/AftermathActors").visible, "casualties and crouched leader appear only in the aftermath")
	_check(rally.get_node("NPCs/AftermathActors/CrouchedLeader").visible, "injured Peace Leader remains visible near the burned podium")
	for injured_name in ["InjuredA", "InjuredB"]:
		var injured := rally.get_node("NPCs/AftermathActors/" + injured_name) as AnimatedSprite2D
		_check(injured.sprite_frames.get_frame_count(&"injured") == 2, "%s uses a restrained two-frame injury loop" % injured_name)
		var injury_frame_a := injured.sprite_frames.get_frame_texture(&"injured", 0)
		var injury_frame_b := injured.sprite_frames.get_frame_texture(&"injured", 1)
		_check(injury_frame_a.get_size() == injury_frame_b.get_size(), "%s animation cells keep a fixed apparent scale" % injured_name)
	_check(rally.get_node("DialogueAnchors/Leader").global_position.y < rally.get_node("NPCs/AftermathActors/CrouchedLeader").global_position.y, "leader bark anchor sits above the crouched leader")
	_check(rally.get_node("Particles/Ash").emitting, "aftermath adds drifting ash beneath dialogue")
	var dispersal_actors := rally.get_node("NPCs/PanicCrowd").find_children("*", "Day2DispersalActor", true, false)
	for actor in dispersal_actors:
		var opaque_bottom: float = actor.position.y + (374.0 - 192.0) * absf(actor.scale.y)
		_check(opaque_bottom >= 574.0 and opaque_bottom <= 592.0, "%s keeps its visible feet on the pavement" % actor.name)
		var authored_scale: Vector2 = actor.scale
		actor.animation = &"run"
		actor.frame = 0
		actor._apply_frame_alignment()
		_check(actor.scale.is_equal_approx(authored_scale), "%s keeps a constant scale on run frame 1" % actor.name)
		actor.frame = 1
		actor._apply_frame_alignment()
		_check(actor.scale.is_equal_approx(authored_scale), "%s keeps a constant scale on run frame 2" % actor.name)
	_check(dispersal_actors.size() >= 5, "five distinct animated dispersal identities plus restrained crowd duplicates are staged")
	var unique_strips := {}
	for actor_node in dispersal_actors:
		var actor := actor_node as Day2DispersalActor
		unique_strips[actor.strip.resource_path] = true
		_check(actor.sprite_frames.get_frame_count(&"startled") == 1 and actor.sprite_frames.get_frame_count(&"run") == 2, actor.name + " has exactly three stepped animation frames")
	_check(unique_strips.size() == 5, "all five approved NPC identities remain readable in the dispersal crowd")
	var stopped_at_soldiers := 0
	for actor_node in dispersal_actors:
		if (actor_node as Day2DispersalActor).barrier_x > 0.0:
			stopped_at_soldiers += 1
			_check((actor_node as Day2DispersalActor).default_pose != null, "%s has a default standing pose for the soldier barrier" % actor_node.name)
			_check((actor_node as Day2DispersalActor).sprite_frames.has_animation(&"blocked"), "%s can settle into its standing pose at containment" % actor_node.name)
	_check(stopped_at_soldiers >= 4, "most right-running civilians stop at the soldier containment line")
	_check(rally.get_node("NPCs/PeaceLeader").texture.resource_path.ends_with("peace-leader.png"), "dedicated Peace Leader sprite replaces the Seedless representative")
	_check(rally.get_node("NPCs/PeaceLeader").z_index < rally.get_node("NPCs/ForegroundPodium").z_index, "Peace Leader is depth-occluded behind the foreground podium")
	var camera := rally.get_node("HorizontalCamera") as Day1HorizontalCamera
	var blockade_focus := rally.get_node("Focus/Blockade") as Node2D
	var street_camera_y := rally.player.global_position.y + rally._previous_camera_offset.y
	await rally._focus_on_street(blockade_focus)
	var blockade_camera_y := blockade_focus.global_position.y + camera.framing_offset.y
	_check(is_equal_approx(blockade_camera_y, street_camera_y), "blockade focus pans horizontally without lifting the camera off street height")
	await rally._focus_injured_leader()
	_check(camera.target == rally.get_node("NPCs/AftermathActors/CrouchedLeader") and camera.framing_offset.is_equal_approx(Vector2(0.0, -130.0)), "post-fight camera pans down to frame the crouched Peace Leader")
	await rally._focus_on_street(blockade_focus)
	rally._start_blockade()
	frames = 0
	while rally.state != Day2PeaceRallyController.State.EXIT and frames < 360:
		await process_frame
		frames += 1
	_check(rally.state == Day2PeaceRallyController.State.EXIT, "blockade sequence reaches rescue and restores side-scroller exit")
	var aftermath_lines := [
		"There’s been an explosion!",
		"The area is under security containment!",
		"My child can’t breathe!",
		"Step back!",
		"Are you serious?! There’s people fucking dying here! Let us out!",
		"I understand but the culprit might be here!",
		"(Ain’t no fucking way this is actually real.)",
	]
	var aftermath_cursor := 0
	for spoken_line in opening_lines:
		if aftermath_cursor < aftermath_lines.size() and spoken_line == aftermath_lines[aftermath_cursor]:
			aftermath_cursor += 1
	_check(aftermath_cursor == aftermath_lines.size(), "containment and MC confrontation lines play in exact authored order")
	_check(rally.get_node("NPCs/PanicCrowd/SoldierA").position.x > 2860.0, "the civilian struggle physically opens the soldier line")
	_check(rally.get_node("NPCs/BlockadeCrowd/StrugglingCivilian").position.x < 2775.0, "the struggling civilian visibly recoils from the push")
	_check(rally.player.animated_sprite.flip_h, "MC faces left toward the Peace Leader after the fight")
	_check(camera.offset.is_equal_approx(Vector2.ZERO), "fight camera shake settles cleanly before the leader speaks")
	_check(rally.get_node("Collision/EastBlockade/Shape").disabled, "the eastern passage opens after the confrontation")
	_check(frame_ids == [&"peace_leader_opening", &"suspicious_worker", &"peace_leader_warning", &"rescue"], "all supplied CG frames play in exact order through rescue")
	_validate_generated_assets()
	_validate_aftermath_assets()
	rally.queue_free()
	await process_frame


func _check_news_presenter() -> void:
	session.broadcast_context = &"day2"
	session.day2_bombing_route = &"propaganda"
	var packed := load("res://scenes/gameplay/news_broadcast.tscn") as PackedScene
	var news := packed.instantiate() as NewsBroadcast
	news.instant_mode = true
	news.auto_advance_to_epilogue = false
	root.add_child(news)
	await process_frame
	await process_frame
	_check(news._is_day2_context, "animated presenter recognizes Day 2 context")
	_check(news._lines.has("Authorities have linked today's deadly rally explosion to violent Opposition activity."), "presenter reads the selected Day 2 propaganda report")
	_check(news._line_report_ids.has(&"day2_bombing"), "presenter metadata identifies the Day 2 report")
	_check(news._line_frames.has(0) and news._line_frames.has(1) and news._line_frames.has(2), "selected report drives all three televised frames")
	news.queue_free()
	await process_frame


func _check_route_persistence() -> void:
	session.set_day2_report_route(&"truthful")
	var cfg := ConfigFile.new()
	cfg.load(session.profile_path)
	_check(cfg.get_value("story", "day2_bombing_route", "") == "truthful", "Day 2 report route is saved for Continue and Day 3")


func _validate_generated_assets() -> void:
	var identities := [
		"r1c3-occupation-protester-b",
		"r2c3-gossiping-gal-a",
		"r2c4-gossiping-gal-b",
		"r4c1-anti-seedless-protester-a",
		"r4c4-anti-seedless-protester-d",
	]
	for identity in identities:
		for frame_index in range(1, 4):
			var path := "res://assets/art/Day 2 Side Scroll/npcs/dispersal/%s/frame-%d.png" % [identity, frame_index]
			var texture := load(path) as Texture2D
			var image := texture.get_image() if texture != null else null
			_check(image != null and image.get_size() == Vector2i(384, 384), "%s frame %d is a valid 384x384 alpha sprite" % [identity, frame_index])
			if image != null:
				_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(383, 383).a == 0.0, "%s frame %d has transparent corners" % [identity, frame_index])
		var strip_texture := load("res://assets/art/Day 2 Side Scroll/npcs/dispersal/%s/strip.png" % identity) as Texture2D
		var strip := strip_texture.get_image() if strip_texture != null else null
		_check(strip != null and strip.get_size() == Vector2i(1152, 384), identity + " runtime strip is 1152x384")


func _validate_aftermath_assets() -> void:
	var paths := [
		"res://assets/art/Day 2 Side Scroll/npcs/aftermath/leader/injured-leader-strip.png",
		"res://assets/art/Day 2 Side Scroll/npcs/aftermath/bomb-soldier/bomb-soldier-strip.png",
		"res://assets/art/Day 2 Side Scroll/npcs/aftermath/casualties/deceased-a.png",
		"res://assets/art/Day 2 Side Scroll/npcs/aftermath/casualties/deceased-b.png",
		"res://assets/art/Day 2 Side Scroll/npcs/aftermath/casualties/injured-a.png",
		"res://assets/art/Day 2 Side Scroll/npcs/aftermath/casualties/injured-b.png",
	]
	for path in paths:
		var texture := load(path) as Texture2D
		_check(texture != null, path.get_file() + " imports as a texture")
		if texture != null:
			var expected := Vector2(768, 384) if path.ends_with("strip.png") else Vector2(384, 384)
			_check(texture.get_size() == expected, path.get_file() + " has the authored fixed-cell dimensions")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
