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
	root.add_child(level)
	for _frame in 90:
		await physics_frame

	var player := level.get_node("Player") as Player
	var lower_surface := level.get_node("Line2DFloorToMidflightCollider/StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	var upper_surface := level.get_node("Line2DFloorToMidflightCollider2/StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	var lower_highlight := level.get_node("StairHighlights/LowerRoute") as Node2D
	var upper_highlight := level.get_node("StairHighlights/UpperRoute") as Node2D
	var foreground_railing := level.get_node("railing") as Sprite2D
	var top_stair_railing := level.get_node("TopStairRailing") as Sprite2D

	_check(player.is_on_floor(), "player settles on the lower floor")
	_check(not lower_surface.disabled, "lower staircase starts active")
	_check(upper_surface.disabled, "top staircase starts inactive")
	_check(lower_highlight.modulate.a > upper_highlight.modulate.a, "lower staircase starts highlighted")
	_check(foreground_railing.z_index > player.z_index, "foreground railing renders over the player")
	_check(top_stair_railing.z_index > player.z_index, "top stair fascia renders over the player")

	Input.action_press(&"move_right")
	for _frame in 320:
		await physics_frame
	Input.action_release(&"move_right")
	await physics_frame
	_check(level.upper_route_active, "right landing activates the upper route")
	_check(lower_surface.disabled, "lower staircase collision switches off")
	_check(not upper_surface.disabled, "top staircase collision switches on")
	_check(player.global_position.x > 900.0, "player reaches the middle landing")
	_check(player.global_position.y < 430.0, "lower staircase carries the player upward")

	for _frame in 45:
		await process_frame
	_check(upper_highlight.modulate.a > lower_highlight.modulate.a, "highlight transfers to the top staircase")

	Input.action_press(&"move_left")
	for _frame in 300:
		await physics_frame
	Input.action_release(&"move_left")
	_check(player.global_position.x < 620.0, "player reverses onto the top staircase")
	_check(player.global_position.y < 260.0, "player reaches the upper landing")
	Input.action_press(&"move_left")
	for _frame in 24:
		await physics_frame
	Input.action_release(&"move_left")
	_check(level.get_node("HUD/DoorPrompt").visible, "top door offers the rooftop transition")

	player.global_position.y = player.fall_limit + 20.0
	await physics_frame
	await physics_frame
	_check(not level.upper_route_active, "fall recovery resets the staircase phase")
	_check(not lower_surface.disabled and upper_surface.disabled, "fall recovery restores the lower route")
	_check(player.global_position.distance_to(Vector2(259.0, 462.0)) < 40.0, "fall recovery returns the player to the entrance")

	level.queue_free()
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
