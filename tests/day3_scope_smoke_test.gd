extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY3_SCOPE_TEST_START")
	var session := root.get_node("GameSession")
	var old_profile: String = session.profile_path
	session.profile_path = "user://day3_scope_smoke_test.cfg"
	var packed := load("res://scenes/Day 3/day3_scope_scene.tscn") as PackedScene
	_check(packed != null, "Day 3 scope scene loads")
	var scope := packed.instantiate() as Day3ScopeScene
	scope.auto_advance_to_finale = false
	scope.play_intro_on_ready = false
	scope.cinematic_timing_scale = 0.01
	root.add_child(scope)
	await process_frame
	_check(scope.get_node("TargetImage").texture == load("res://assets/art/Day3/peace-leader-podium.png"), "scope targets the supplied Peace Leader podium scene")
	_check(not scope.attempt_shot_at(Vector2(100, 100)), "off-target pistol shot is rejected")
	_check(scope.attempt_shot_at(Vector2(640, 340)), "Peace Leader target accepts the determined shot")
	var frames := 0
	while not scope.resolved and frames < 60:
		await process_frame
		frames += 1
	_check(scope.resolved, "scope resolves after the target is confirmed")
	scope.queue_free()
	await process_frame
	session.profile_path = old_profile
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day3_scope_smoke_test.cfg"))
	if failures == 0:
		print("DAY3_SCOPE_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
