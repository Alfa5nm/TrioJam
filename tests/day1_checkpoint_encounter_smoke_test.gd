extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const EXPECTED_BEATS := [
	"Soldier|You there. Lower the sign. You are participating in an unauthorized public demonstration",
	"Civilian|Huh? I-I’m standing on the side of the road. I’m not blocking anyone.",
	"Soldier|Do you have a permit?",
	"Civilian|I don’t need a permit to protest peacefully.",
	"Soldier|That is not what I asked. Lower. The. Sign.",
	"Civilian|…",
	"Civilian|…No.",
	"MC|(...Something tells me this is going to escalate. I’ll get my camera out.)",
]
const EXPECTED_CAMERA_LINES := [
	"frame_1|Civilian|What the hell–?! Why are you hitting me?!",
	"frame_1|Soldier|You are under arrest for unlawful assembly, public disruption and possession of prohibited political material.",
	"frame_1|Civilian|What…?! No no no! You can’t do that! I’m alone! There is no assembly!",
	"frame_1|Soldier|Your belongings will be confiscated as evidence.",
	"frame_1|Civilian|GIVE. THAT BACK!!",
	"frame_2|Civilian|Don’t hit me! I didn’t do anything wrong!",
	"frame_2|Soldier|Oh don’t you dare hit me with your filthy hands! You attacked a member of the national security force!",
	"frame_2|Civilian|I was defending myself!",
	"frame_3|Civilian|AH–!",
	"mc_black|MC|Oh my fucking god—",
	"aftermath|Bystander|He killed him!",
	"aftermath|Bystander|Someone call for help!",
	"aftermath|Bystander|Murderer!",
	"mc_black|MC|(Shit shit shit… This isn’t good.)",
	"mc_black|MC|(But if I help them, I’m doomed, so is she. I… can’t risk my life here.)",
	"mc_black|MC|(I need to get the fuck out of here.)",
]

var failures := 0


func _initialize() -> void:
	print("DAY1_CHECKPOINT_ENCOUNTER_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 scene loads with the checkpoint confrontation")
	if packed == null:
		quit(1)
		return

	var level := packed.instantiate()
	var dialogue := level.get_node("CinematicDialogue") as CinematicDialogue
	var camera_capture := level.get_node("Day1CameraCapture") as Day1CameraCapture
	var encounter := level.get_node("CheckpointConfrontation") as Day1CheckpointEncounter
	dialogue.instant_mode = true
	dialogue.timing_scale = 0.01
	camera_capture.instant_mode = true
	camera_capture.timing_scale = 0.01
	encounter.cinematic_timing_scale = 0.01
	var beats: Array[String] = []
	var camera_lines: Array[String] = []
	var chaotic_active_at_capture_start := [false]
	encounter.dialogue_beat_started.connect(func(speaker_name: String, text: String):
		beats.append(speaker_name + "|" + text)
	)
	camera_capture.line_started.connect(func(speaker_name: String, text: String, phase: StringName):
		camera_lines.append(String(phase) + "|" + speaker_name + "|" + text)
	)
	camera_capture.capture_started.connect(func():
		var director := root.get_node_or_null("MusicDirector")
		chaotic_active_at_capture_start[0] = director != null and director.current_cue() == &"chaotic_music"
	)
	root.add_child(level)
	for _frame in 5:
		await physics_frame

	var player := level.get_node("Player") as Player
	var camera := level.get_node("HorizontalCamera") as Day1HorizontalCamera
	var smoking_encounter := level.get_node("SmokingCivilianEncounter") as AmbientBarkTrigger
	var gossip := level.get_node("ProduceStallGossip") as Day1GossipConversation
	var escape_spawn := level.get_node("PostEventSpawn") as Node2D
	var escape_barrier := level.get_node("PostEventRouteBarricade") as Node2D
	var barrier_shape := escape_barrier.get_node("StaticBody2D/CollisionShape2D") as CollisionShape2D
	_check(encounter.position.distance_to(Vector2(3300.0, 607.0)) < 1.0, "confrontation is staged in the marked street section")
	_check(encounter.soldier.texture.resource_path.ends_with("checkpoint-soldier.png"), "soldier uses the new supplied checkpoint sprite")
	_check(encounter.civilian.texture.resource_path.ends_with("checkpoint-boy.png"), "civilian uses the new supplied boy sprite")
	_check(_has_transparent_corner(encounter.soldier.texture) and _has_transparent_corner(encounter.civilian.texture), "both split sprites have true transparency")
	_check(smoking_encounter.placeholder_visual.visible and smoking_encounter.visual_texture.resource_path.ends_with("smoking-civilian.png"), "supplied smoking civilian is visible at the earlier bark")
	_check(_has_transparent_corner(smoking_encounter.visual_texture), "smoking civilian remains on a transparent canvas")
	_check(_has_authored_dark_detail(smoking_encounter.visual_texture), "smoking civilian retains authored dark linework")

	_check(encounter.trigger.monitoring and encounter.trigger.collision_mask == 1 and not encounter.trigger_shape.disabled, "invisible player trigger is armed")
	encounter._on_trigger_body_entered(player)
	for _frame in 3:
		await physics_frame
	_check(encounter.has_triggered, "entering the invisible left-side zone starts the cutscene")
	_check(not player.controls_enabled, "player movement locks during the scripted exchange")
	_check(camera.target == encounter, "camera reframes the confrontation while dialogue plays")

	var wait_frames := 0
	while beats.size() < EXPECTED_BEATS.size() and wait_frames < 240:
		await process_frame
		wait_frames += 1
	_check(beats == EXPECTED_BEATS, "all eight dialogue beats play in the requested order")
	_check(encounter.soldier.position.x >= 21.9, "soldier visibly moves closer before the final demand")

	wait_frames = 0
	while (camera_capture.captured_frames < 3 or not player.controls_enabled) and wait_frames < 360:
		await process_frame
		wait_frames += 1
	_check(camera_capture.captured_frames == 3, "camera overlay presents all three authored frames")
	_check(camera_capture.previews.all(func(preview: TextureRect) -> bool: return preview.texture != null), "the frame record contains two illustrations and the black gunshot frame")
	_check(camera_capture.previews[0].texture.resource_path.ends_with("frame-1-soldier-hit.png") and camera_capture.previews[1].texture.resource_path.ends_with("frame-2-civilian-shove.png"), "camera frames use the two supplied illustrations instead of gameplay screenshots")
	_check(camera_lines == EXPECTED_CAMERA_LINES, "comic captions, aftermath cries, and black-screen MC lines play in order")
	_check(camera_capture.caption.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "comic dialogue wraps in the bottom caption panel")
	_check(camera_capture.characters_per_second <= 24.0 and camera_capture.punctuation_pause >= 0.12, "camera captions use the slower readable typewriter pace")
	camera_capture._apply_caption_style("Soldier", &"frame_1")
	var soldier_caption_color := camera_capture.caption.get_theme_color(&"font_color")
	var soldier_caption_left := camera_capture.caption_panel.anchor_right <= 0.52
	camera_capture._apply_caption_style("Civilian", &"frame_1")
	var civilian_caption_color := camera_capture.caption.get_theme_color(&"font_color")
	var civilian_caption_right := camera_capture.caption_panel.anchor_left >= 0.479
	_check(soldier_caption_color.r > 0.9 and soldier_caption_color.g < 0.4 and soldier_caption_left, "Soldier captions are red and positioned on the left")
	_check(civilian_caption_color.is_equal_approx(Color.WHITE) and civilian_caption_right, "Civilian captions are white and positioned on the right")
	dialogue._configure_ambient_bark("Soldier", "Test", null)
	var soldier_bubble_color := dialogue.line.get_theme_color(&"font_color")
	dialogue._configure_ambient_bark("Civilian", "Test", null)
	var civilian_bubble_color := dialogue.line.get_theme_color(&"font_color")
	_check(dialogue.characters_per_second <= 24.0 and soldier_bubble_color.r > 0.9 and soldier_bubble_color.g < 0.4, "world Soldier bubbles are slower and red")
	_check(civilian_bubble_color.is_equal_approx(Color.WHITE), "world Civilian bubbles remain white")
	dialogue._configure_standard_line()
	_check(camera_capture.gunshot.stream != null and camera_capture.camera_click.stream != null and camera_capture.scuffle.stream != null and camera_capture.running.stream != null and camera_capture.body_fall.stream != null and camera_capture.breathing.stream != null, "requested camera, struggle, gunshot, body fall, escape, and breathing sounds are assigned")
	_check(camera_capture.running.stream.resource_path.ends_with("running-on-concrete.mp3"), "Day 1 cutscene escape uses the supplied concrete-running cue")
	_check(camera_capture.body_fall.stream.resource_path.ends_with("body-fall.mp3"), "Day 1 civilian collapse uses the supplied body-fall cue")
	_check(camera_capture.blip.stream != null and camera_capture.blip.bus == &"UI" and camera_capture.tense.bus == &"Ambience", "generated blip and tense background audio use the correct buses")
	var music_director := root.get_node_or_null("MusicDirector")
	_check(chaotic_active_at_capture_start[0], "chaotic score starts with the camera draw")
	_check(music_director != null and music_director.current_cue().is_empty() and not music_director.active_player().playing, "chaotic score finishes with the cutscene before street dialogue resumes")
	_check(not camera_capture.tense.playing and camera_capture.crowd.volume_db <= -14.0, "redundant ambience stays beneath the chaotic score")
	_check(camera_capture.gunshot.volume_db <= -3.0 and camera_capture.scuffle.volume_db <= -12.0, "essential impacts remain readable without overpowering the score")
	_check(encounter.aftermath_staged and encounter.get_node("Aftermath").visible and encounter.get_node("Aftermath/Blood").visible, "camera exit reveals the crowd and blood aftermath")
	_check(encounter.escape_staged and player.global_position.distance_to(escape_spawn.global_position) < 1.0, "black-screen escape respawns the player at the grain depot")
	_check(escape_barrier.visible and not barrier_shape.disabled, "post-event barricade visibly and physically closes the route behind the player")
	_check(gossip.visible and gossip.is_armed, "post-event gossip appears and arms after the shooting")
	_check(not camera_capture.overlay.visible and not camera_capture.active, "camera overlay and black screen close after the escape")
	_check(player.controls_enabled, "player control returns after camera capture")
	_check(camera.target == player, "horizontal camera returns to following the player")

	var beat_count := beats.size()
	encounter.start_sequence()
	await process_frame
	_check(beats.size() == beat_count, "the confrontation cannot replay during the same scene visit")

	level.queue_free()
	for _frame in 3:
		await process_frame
	if failures == 0:
		print("DAY1_CHECKPOINT_ENCOUNTER_TEST_PASS")
	quit(failures)


func _has_transparent_corner(texture: Texture2D) -> bool:
	var image := texture.get_image()
	return image != null and image.get_pixel(0, 0).a < 0.01


func _has_authored_dark_detail(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null:
		return false
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.8 and maxf(color.r, maxf(color.g, color.b)) < 0.12:
				return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
