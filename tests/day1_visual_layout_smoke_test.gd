extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const ARTIFACT_DIR := "res://tests/artifacts"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 visual-layout scene loads")
	if packed == null:
		quit(1)
		return
	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 8:
		await process_frame

	var rally := level.get_node("Day1SeedlessRally") as Day1SeedlessRally
	var camera := level.get_node("HorizontalCamera") as Day1HorizontalCamera
	var capture := level.get_node("Day1CameraCapture") as Day1CameraCapture
	var seedless_capture := level.get_node("Day1SeedlessCameraCapture") as Day1SeedlessCameraCapture
	var dialogue := level.get_node("CinematicDialogue") as CinematicDialogue
	var encounter := level.get_node("CheckpointConfrontation") as Day1CheckpointEncounter
	var broadcast_exit := level.get_node("BroadcastRoomExit") as Day1BroadcastRoomExit
	var representative := rally.get_node("Stage/Representative") as Sprite2D
	_check(representative.position.distance_to(Vector2(5, -280)) < 1.0 and rally.get_node_or_null("Stage/PodiumForeground") == null, "representative aligns cleanly with the supplied stage artwork")
	capture._apply_caption_style("Soldier", &"frame_1")
	_check(capture.caption_panel.anchor_right <= 0.521 and capture.caption.get_theme_color(&"font_color").r > 0.9, "Soldier comic panel occupies the red left slot")
	capture._apply_caption_style("Civilian", &"frame_2")
	_check(capture.caption_panel.anchor_left >= 0.479 and capture.caption.get_theme_color(&"font_color").is_equal_approx(Color.WHITE), "Civilian comic panel occupies the white right slot")
	seedless_capture._apply_caption_style("Soldier", &"seedless_arrest")
	seedless_capture._apply_caption_slot(&"right")
	_check(seedless_capture.caption_panel.anchor_left >= 0.479 and seedless_capture.caption.get_theme_color(&"font_color").r > 0.9, "Seedless arrest panel places the red Soldier caption on the illustrated right")
	seedless_capture._apply_caption_style("Civilian", &"seedless_customer")
	seedless_capture._apply_caption_slot(&"center")
	_check(seedless_capture.caption_panel.anchor_left > 0.1 and seedless_capture.caption_panel.anchor_right < 0.9, "Seedless customer panel centers its white caption")

	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
		camera.position_smoothing_enabled = false
		camera.target = rally
		camera.framing_offset = Vector2(0, -213)
		for _frame in 5:
			await process_frame
		_save_view("day1_seedless_rally_preview.png")

		camera.target = rally.get_node("CameraFocus/Customers")
		for _frame in 5:
			await process_frame
		_save_view("day1_seedless_customer_queue_preview.png")

		camera.target = broadcast_exit
		camera.framing_offset = Vector2(0, -150)
		for _frame in 5:
			await process_frame
		_save_view("day1_broadcast_room_exit_preview.png")

		seedless_capture.overlay.visible = true
		seedless_capture.frame_image.visible = true
		seedless_capture.blackout.visible = false
		seedless_capture.camera_chrome.visible = true
		seedless_capture.caption_panel.visible = true
		seedless_capture.frame_image.texture = preload("res://assets/art/Day1 Scene 1/camera-cutscene/seedless/seedless-protest-recording.png")
		seedless_capture.caption.text = "We are farmers! Customers cannot eat what we cannot afford to grow!"
		seedless_capture.caption.visible_characters = -1
		seedless_capture._apply_caption_style("Opposition Volunteer", &"seedless_protest")
		seedless_capture._apply_caption_slot(&"left")
		for _frame in 3:
			await process_frame
		_save_view("day1_seedless_protest_capture_preview.png")

		seedless_capture.frame_image.texture = preload("res://assets/art/Day1 Scene 1/camera-cutscene/seedless/seedless-arrest-recording.png")
		seedless_capture.caption.text = "Do not resist! Fires will be shot for resisting."
		seedless_capture._apply_caption_style("Soldier", &"seedless_arrest")
		seedless_capture._apply_caption_slot(&"right")
		for _frame in 3:
			await process_frame
		_save_view("day1_seedless_arrest_capture_preview.png")

		seedless_capture.frame_image.texture = preload("res://assets/art/Day1 Scene 1/camera-cutscene/seedless/seedless-happy-customer-recording.png")
		seedless_capture.caption.text = "It IS convenient…"
		seedless_capture._apply_caption_style("Civilian", &"seedless_customer")
		seedless_capture._apply_caption_slot(&"center")
		for _frame in 3:
			await process_frame
		_save_view("day1_seedless_customer_capture_preview.png")
		seedless_capture.overlay.visible = false

		capture.overlay.visible = true
		capture.frame_image.visible = true
		capture.blackout.visible = false
		capture.camera_chrome.visible = true
		capture.caption_panel.visible = true
		capture.frame_image.texture = preload("res://assets/art/Day1 Scene 1/camera-cutscene/frame-1-soldier-hit.png")
		capture.caption.text = "You are under arrest for unlawful assembly and public disruption."
		capture.caption.visible_characters = -1
		capture._apply_caption_style("Soldier", &"frame_1")
		for _frame in 3:
			await process_frame
		_save_view("day1_soldier_caption_preview.png")

		capture.frame_image.texture = preload("res://assets/art/Day1 Scene 1/camera-cutscene/frame-2-civilian-shove.png")
		capture.caption.text = "Don’t hit me! I didn’t do anything wrong!"
		capture._apply_caption_style("Civilian", &"frame_2")
		for _frame in 3:
			await process_frame
		_save_view("day1_civilian_caption_preview.png")

		capture.overlay.visible = false
		camera.target = encounter
		camera.framing_offset = Vector2(0, -213)
		for _frame in 4:
			await process_frame
		_preview_world_bubble(dialogue, "Soldier", "Lower the sign. This demonstration is unauthorized.", encounter.soldier_dialogue_anchor)
		await process_frame
		_save_view("day1_soldier_world_bubble_preview.png")
		_preview_world_bubble(dialogue, "Civilian", "I’m standing on the side of the road.", encounter.civilian_dialogue_anchor)
		await process_frame
		_save_view("day1_civilian_world_bubble_preview.png")
		dialogue.hide_immediately()

	level.queue_free()
	for _frame in 3:
		await process_frame
	quit(failures)


func _save_view(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(ARTIFACT_DIR + "/" + filename))
	_check(error == OK, filename + " saves")


func _preview_world_bubble(dialogue: CinematicDialogue, speaker_name: String, text: String, anchor: Node2D) -> void:
	dialogue._configure_ambient_bark(speaker_name, text, null)
	dialogue._speaker = anchor
	dialogue._uses_screen_anchor = false
	dialogue._uses_parallax_anchor = true
	dialogue._parallax_anchor_initialized = false
	dialogue.is_presenting = true
	dialogue.dialogue.visible = true
	dialogue.bubble.modulate.a = 1.0
	dialogue.bubble.scale = Vector2.ONE
	dialogue.line.text = text
	dialogue.line.visible_characters = -1
	dialogue._place_bubble()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
