extends SceneTree

var failures := 0


func _init() -> void:
	print("STAIRWELL_SMOKE_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/main/main.tscn") as PackedScene
	_check(packed_scene != null, "stairwell scene loads")
	if packed_scene == null:
		quit(1)
		return

	var level := packed_scene.instantiate()
	root.add_child(level)
	for _frame in 60:
		await physics_frame

	var player := level.get_node_or_null("Player") as Player
	_check(player != null, "animated player exists")
	if player != null:
		_check(player.is_on_floor(), "player settles on lower stairwell floor")
		_check(player.animated_sprite.sprite_frames.has_animation(&"walk"), "walk animation is configured")
		_check(player.animated_sprite.sprite_frames.get_frame_count(&"walk") == 4, "walk cycle has four frames")
		player.global_position.y = player.fall_limit + 20.0
		await physics_frame
		await physics_frame
		_check(player.global_position.distance_to(Vector2(116.0, 602.0)) < 30.0, "fall recovery returns to scene entrance")
		Input.action_press(&"move_right")
		for _frame in 315:
			await physics_frame
		Input.action_release(&"move_right")
		_check(player.global_position.x > 850.0, "player traverses horizontally through the stairwell")
		_check(player.global_position.y < 520.0, "slope collision carries player upward on the stairs")

	var camera := level.get_node_or_null("CinematicCamera") as CinematicCamera
	_check(camera != null, "cinematic follow camera exists")
	_check(camera != null and camera.zoom.x > 1.0, "camera uses a cinematic cropped zoom")
	_check(level.get_node_or_null("Environment/Background") is Sprite2D, "generated environment plate is loaded")
	_check(level.get_node_or_null("Environment/WarmPractical") is PointLight2D, "warm practical light exists")
	_check(level.get_node_or_null("Environment/EmergencyGlow") is PointLight2D, "emergency light exists")
	_check(level.get_node_or_null("Environment/Dust") is GPUParticles2D, "ambient dust particles exist")
	_check(level.get_node_or_null("Foreground/MainRail") is Line2D, "foreground parallax railing exists")

	var interactions := get_nodes_in_group("stairwell_interactions")
	_check(interactions.size() == 3, "three contextual interactions are available")
	var hose := level.get_node_or_null("HoseCabinet") as StairwellInteraction
	var right_exit := level.get_node_or_null("RightExit") as StairwellInteraction
	var message := level.get_node_or_null("HUD/Message") as PanelContainer
	var completion := level.get_node_or_null("HUD/Completion") as Control
	var interact_event := InputEventAction.new()
	interact_event.action = &"interact"
	interact_event.pressed = true
	if player != null and hose != null and right_exit != null and message != null and completion != null:
		hose._on_body_entered(player)
		hose._unhandled_input(interact_event)
		_check(message.visible, "fire-hose inspection displays narrative UI")
		hose._on_body_exited(player)
		right_exit._on_body_entered(player)
		right_exit._unhandled_input(interact_event)
		_check(completion.visible, "right door completes the first-scene loop")
		_check(not player.controls_enabled, "completion hands control to the cinematic beat")

	level.queue_free()
	await process_frame
	if failures == 0:
		print("STAIRWELL_SMOKE_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
