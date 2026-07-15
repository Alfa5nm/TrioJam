extends SceneTree

var failures := 0


func _init() -> void:
	print("SMOKE_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/main/main.tscn") as PackedScene
	_check(packed_scene != null, "main scene loads")
	if packed_scene == null:
		quit(1)
		return

	var level := packed_scene.instantiate()
	root.add_child(level)
	for _frame in 60:
		await physics_frame

	var player := level.get_node_or_null("Player") as Player
	_check(player != null, "player exists")
	if player != null:
		_check(player.is_on_floor(), "player settles on the ground")
		_check(player.global_position.y < player.fall_limit, "player remains inside the level")
		print("PLAYER_POSITION=", player.global_position, " ON_FLOOR=", player.is_on_floor())
		player.global_position.y = player.fall_limit + 20.0
		await physics_frame
		await physics_frame
		_check(player.global_position.distance_to(Vector2(130.0, 555.0)) < 25.0, "falling returns player to checkpoint")

	var reports := get_nodes_in_group("report_points")
	_check(reports.size() == 2, "two report points are available")
	var gate := level.get_node_or_null("Level/NewsroomGate") as NewsroomGate
	_check(gate != null, "newsroom gate exists")
	var completion := level.get_node_or_null("HUD/Completion") as PanelContainer
	_check(completion != null, "completion UI exists")

	var interact_event := InputEventAction.new()
	interact_event.action = &"interact"
	interact_event.pressed = true
	if player != null and reports.size() == 2 and gate != null and completion != null:
		for report: ReportPoint in reports:
			report._on_body_entered(player)
			report._unhandled_input(interact_event)
		_check(level.get("_reports_collected") == 2, "both reports update level progress")
		_check(gate.get("_unlocked") == true, "collecting both reports unlocks newsroom")
		gate._on_body_entered(player)
		gate._unhandled_input(interact_event)
		_check(completion.visible, "entering newsroom completes the loop")

	level.queue_free()
	await process_frame
	if failures == 0:
		print("SMOKE_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
