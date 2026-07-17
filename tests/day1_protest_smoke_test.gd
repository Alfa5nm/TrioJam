extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const PREVIEW_PATH := "res://tests/artifacts/day1_protest_preview.png"
const DISPERSAL_PREVIEW_PATH := "res://tests/artifacts/day1_protest_dispersal_preview.png"

var failures := 0


func _initialize() -> void:
	print("DAY1_PROTEST_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 scene loads with the protest crowd")
	if packed == null:
		quit(1)
		return

	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 8:
		await process_frame

	var crowd := level.get_node_or_null("Day1ProtestCrowd") as ProtestCrowd
	var player := level.get_node_or_null("Player") as Player
	_check(crowd != null, "protest crowd is instanced at the Day 1 stage")
	_check(player != null, "player is available for scale and camera checks")

	var actor_sprites: Array[Sprite2D] = []
	if crowd != null:
		for node in crowd.find_children("*", "Sprite2D", true, false):
			var sprite := node as Sprite2D
			if sprite != null and sprite.hframes == 4:
				actor_sprites.append(sprite)
	_check(actor_sprites.size() == 9, "crowd contains nine independently phased actors")
	_check(actor_sprites.all(func(sprite: Sprite2D) -> bool:
		return sprite.texture != null and sprite.texture.get_width() == 2048 and sprite.texture.get_height() == 512
	), "all protest strips use normalized 512 px frames")

	var starting_frame := actor_sprites[0].frame if not actor_sprites.is_empty() else -1
	for _frame in 24:
		await physics_frame
	_check(not actor_sprites.is_empty() and actor_sprites[0].frame != starting_frame, "chant animation advances")

	var ambience := crowd.get_node_or_null("CrowdAmbience") as AudioStreamPlayer2D if crowd != null else null
	_check(ambience != null and ambience.stream != null, "spatial angry-crowd ambience is assigned")
	_check(ambience != null and ambience.playing, "crowd ambience loops while the protest scene is active")
	_check(ambience != null and ambience.bus == &"Ambience", "crowd recording is routed through the Ambience bus")

	var camera := level.get_node_or_null("HorizontalCamera") as Day1HorizontalCamera
	if camera != null and crowd != null:
		camera.position_smoothing_enabled = false
		camera.target = crowd
		camera.framing_offset = Vector2(0, -213)
		camera.global_position = crowd.global_position + camera.framing_offset
	for _frame in 8:
		await process_frame
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		var image := root.get_viewport().get_texture().get_image()
		_check(image.save_png(ProjectSettings.globalize_path(PREVIEW_PATH)) == OK, "protest preview saves")

	crowd.auto_disperse_on_player_approach = false
	var start_positions: Array[Vector2] = []
	for sprite in actor_sprites:
		start_positions.append(sprite.position)
	crowd.disperse(crowd.global_position)
	_check(crowd.state == ProtestCrowd.State.DISPERSING, "dispersal enters the panic state")
	_check(actor_sprites.all(func(sprite: Sprite2D) -> bool:
		return sprite.texture.resource_path.contains("panic-v1")
	), "all actors swap to their matched panic sheets")
	for _frame in 72:
		await physics_frame
	_check(actor_sprites[0].position.x < start_positions[0].x, "left-side actors flee horizontally left")
	_check(actor_sprites[-1].position.x > start_positions[-1].x, "right-side actors flee horizontally right")
	_check(actor_sprites[0].position.y > start_positions[0].y, "escape routes also move south toward the foreground")
	_check(actor_sprites.any(func(sprite: Sprite2D) -> bool: return sprite.frame >= 2), "panic transitions into the repeating run cycle")
	if DisplayServer.get_name() != "headless":
		var dispersal_image := root.get_viewport().get_texture().get_image()
		_check(dispersal_image.save_png(ProjectSettings.globalize_path(DISPERSAL_PREVIEW_PATH)) == OK, "dispersal preview saves")

	crowd.horizontal_flee_speed = 1500.0
	crowd.south_flee_speed = 420.0
	crowd.fade_start_distance = 300.0
	crowd.despawn_distance = 460.0
	for _frame in 90:
		await physics_frame
		if crowd.state == ProtestCrowd.State.DISPERSED:
			break
	_check(crowd.state == ProtestCrowd.State.DISPERSED, "crowd finishes dispersing and leaves the scene")
	_check(not ambience.playing, "crowd ambience fades and stops after dispersal")

	crowd.reset_crowd()
	_check(crowd.state == ProtestCrowd.State.CHANTING, "crowd can be reset for retries and checkpoints")
	_check(actor_sprites.all(func(sprite: Sprite2D) -> bool: return sprite.visible), "reset restores every protester")
	crowd.auto_disperse_on_player_approach = true
	player.global_position = crowd.global_position + Vector2(-crowd.trigger_radius + 10.0, 0.0)
	for _frame in 3:
		await physics_frame
	_check(crowd.state == ProtestCrowd.State.DISPERSING, "player proximity triggers the dispersal mechanic")

	level.queue_free()
	actor_sprites.clear()
	ambience = null
	crowd = null
	player = null
	camera = null
	level = null
	packed = null
	for _frame in 3:
		await process_frame
	if failures == 0:
		print("DAY1_PROTEST_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
