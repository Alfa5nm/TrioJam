extends SceneTree

var failures := 0


func _init() -> void:
	print("ROOFTOP_PLAN_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/rooftop/rooftop.tscn") as PackedScene
	_check(packed_scene != null, "rooftop scene loads")
	if packed_scene == null:
		quit(1)
		return

	var rooftop := packed_scene.instantiate()
	root.add_child(rooftop)
	for _frame in 90:
		await physics_frame

	var player := rooftop.get_node("Player") as Player
	var frames := player.animated_sprite.sprite_frames
	_check(player.is_on_floor(), "player enters through the left rooftop door")
	_check(frames.get_frame_count(&"idle") == 6, "idle loop uses six registered frames")
	_check(frames.get_frame_count(&"walk") == 6, "walk loop uses six registered frames")
	_check(frames.get_frame_count(&"execute") == 8, "execute action uses eight sequential frames")
	var aim_texture := frames.get_frame_texture(&"aim", 0) as AtlasTexture
	_check(aim_texture != null and aim_texture.region.size == Vector2(512, 512), "sniper frames use a wide unclipped canvas")
	_check(aim_texture != null and aim_texture.atlas.get_width() == 4096, "execute sheet contains all eight sniper poses")

	Input.action_press(&"move_right")
	for _frame in 365:
		await physics_frame
	Input.action_release(&"move_right")
	_check(player.global_position.x > 1040.0, "player reaches the dirty footprints on the right")
	_check(rooftop.execute_available, "footprint zone enables Execute Plan")
	_check(rooftop.get_node("HUD/PlanPrompt").visible, "Execute Plan prompt is visible")

	rooftop.execute_plan()
	for _frame in 130:
		await physics_frame
	_check(rooftop.plan_executed, "Execute Plan locks after activation")
	_check(not player.controls_enabled, "player movement locks during the plan animation")
	_check(player.animated_sprite.animation == &"aim", "bag draw resolves into the final aim pose")
	_check(rooftop.get_node("HUD/Completion").visible, "plan completion beat appears")

	rooftop.queue_free()
	await process_frame
	if failures == 0:
		print("ROOFTOP_PLAN_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
