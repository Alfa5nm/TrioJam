extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const WORLD_LINES := [
	"MC|[ …I should have stayed oblivious of this incident. Ignorance is bliss, some would say ]",
	"MC|[ Hm…?]",
	"REP|Today, we are proud to introduce a new era of agricultural development.",
	"REP|No seeds, No inconvenience!",
	"Civilian Customer|It does taste good, My kids always complain about the seeds.",
	"Company Representative|This program will modernize our farms and strengthen the national food supply.",
	"Farmers|LIES!",
	"Farmers|They want us to use only their seeds. We can’t even use our seeds, and we cannot plant again without paying them",
	"Opposition Volunteer|And when the farmers resist against this foolishness, they call it opposition violence.",
	"Company Representative|Please do not allow a small group of political agitators to distract from today’s celebration.",
	"MC|[...I should probably record this…]",
	"MC|( I think my job here is done. I need to run to the Broastcast Room…)",
]
const CAPTURE_LINES := [
	"seedless_protest|Opposition Volunteer|We are farmers! Customers cannot eat what we cannot afford to grow!",
	"seedless_protest|Crowd|OUR LAND! OUR SEEDS!",
	"seedless_protest|Soldier|Remain behind the barrier!",
	"seedless_protest|Soldier|Step back!",
	"seedless_arrest|Soldier|You are under arrest for disrupting an authorized public event.",
	"seedless_arrest|Opposition Volunteer|This is not a public event!",
	"seedless_arrest|Soldier|Do not resist! Fires will be shot for resisting.",
	"seedless_arrest|Opposition|This country is doomed if this continues.",
	"seedless_customer|Civilian|These fruits aren’t that bad though….",
	"seedless_customer|Civilian|It IS convenient…",
]

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 loads with the Seedless recording encounter")
	if packed == null:
		quit(1)
		return
	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 6:
		await process_frame

	var rally := level.get_node("Day1SeedlessRally") as Day1SeedlessRally
	var capture := level.get_node("Day1SeedlessCameraCapture") as Day1SeedlessCameraCapture
	var dialogue := level.get_node("CinematicDialogue") as CinematicDialogue
	var player := level.get_node("Player") as Player
	var camera := level.get_node("HorizontalCamera") as Day1HorizontalCamera
	var broadcast_exit := level.get_node("BroadcastRoomExit") as Day1BroadcastRoomExit
	var trigger := rally.get_node("Trigger") as Area2D
	var customers := rally.get_node("CustomerQueue").get_children()

	_check(trigger.position.distance_to(Vector2(-760, -120)) < 1.0, "invisible rally trigger sits on the player’s route")
	_check(customers.size() >= 2, "the authored civilians form the Seedless customer queue")
	_check(customers.all(func(node: Node) -> bool:
		return node is Sprite2D and (node as Sprite2D).texture != null
	), "customer queue uses supplied transparent NPC artwork")
	_check(rally.get_node_or_null("CampaignPlacard") == null, "generated campaign placard no longer obscures the supplied rally artwork")
	_check(not broadcast_exit.is_armed and broadcast_exit.position.distance_to(Vector2(8790, 470)) < 1.0, "Broadcast Room door remains inactive before recording")

	var world_lines: Array[String] = []
	var capture_lines: Array[String] = []
	var frame_paths: Array[String] = []
	rally.dialogue_beat_started.connect(func(speaker: String, text: String) -> void:
		world_lines.append(speaker + "|" + text)
	)
	capture.line_started.connect(func(speaker: String, text: String, phase: StringName) -> void:
		capture_lines.append(str(phase) + "|" + speaker + "|" + text)
	)
	capture.frame_captured.connect(func(_index: int) -> void:
		frame_paths.append(capture.frame_image.texture.resource_path)
	)

	rally.cinematic_timing_scale = 0.01
	dialogue.instant_mode = true
	dialogue.timing_scale = 0.01
	capture.instant_mode = true
	capture.timing_scale = 0.01
	var previous_target := camera.target
	dialogue.is_presenting = true
	rally.start_sequence()
	_check(rally.has_triggered and not player.controls_enabled, "entering the rally consumes the trigger and locks movement")
	await process_frame
	_check(world_lines.is_empty(), "rally waits for any overlapping ambient bubble to finish")
	dialogue.is_presenting = false
	await rally.sequence_finished

	_check(world_lines == WORLD_LINES, "all name-free world dialogue beats play in exact submitted order")
	_check(capture_lines == CAPTURE_LINES, "all camera captions preserve the exact submitted wording")
	_check(frame_paths.size() == 3, "camera records exactly three Seedless frames")
	if frame_paths.size() == 3:
		_check(frame_paths[0].ends_with("seedless-protest-recording.png"), "frame one uses the supplied protest recording")
		_check(frame_paths[1].ends_with("seedless-arrest-recording.png"), "frame two uses the supplied arrest recording")
		_check(frame_paths[2].ends_with("seedless-happy-customer-recording.png"), "frame three uses the supplied happy-customer recording")
	_check(not capture.active and not capture.overlay.visible, "Seedless camera overlay closes after the third recording")
	_check(player.controls_enabled and not player.animated_sprite.flip_h, "player control returns with the MC facing the Broadcast Room")
	_check(camera.target == previous_target, "gameplay camera target is restored after recording")
	_check(broadcast_exit.is_armed and not broadcast_exit.has_transitioned, "Broadcast Room exit arms only after the recording")
	_check(broadcast_exit.destination_scene == "res://scenes/gameplay/broadcast_interface.tscn", "exit targets the existing Broadcast Room interface")
	_check(not level.get_node("Day1CameraCapture").active, "checkpoint camera overlay remains independent")

	dialogue._apply_speaker_style("REP")
	_check(dialogue.line.get_theme_color(&"font_color").b > 0.9, "representative world bubbles use cyan styling")
	dialogue._apply_speaker_style("Farmers")
	var farmer_color := dialogue.line.get_theme_color(&"font_color")
	_check(farmer_color.r > 0.9 and farmer_color.g > 0.6 and farmer_color.b < 0.5, "farmers and opposition use amber world bubbles")
	capture._apply_caption_style("Soldier", &"seedless_arrest")
	capture._apply_caption_slot(&"right")
	_check(capture.caption_panel.anchor_left >= 0.479 and capture.caption.get_theme_color(&"font_color").r > 0.9, "arresting Soldier receives a red right-side caption")
	capture._apply_caption_style("Civilian", &"seedless_customer")
	capture._apply_caption_slot(&"center")
	_check(capture.caption_panel.anchor_left > 0.1 and capture.caption_panel.anchor_right < 0.9 and capture.caption.get_theme_color(&"font_color").is_equal_approx(Color.WHITE), "happy customer receives a centered white caption")

	rally.start_sequence()
	await process_frame
	_check(world_lines.size() == WORLD_LINES.size(), "rally cannot replay during the same scene visit")

	level.queue_free()
	for _frame in 3:
		await process_frame
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
