extends SceneTree

var failures := 0
var wrong_responses: Array[String] = []
var target_signal_count := 0


func _init() -> void:
	print("SCOPED_TARGET_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/gameplay/scoped_target_scene.tscn") as PackedScene
	_check(packed_scene != null, "scoped target scene loads")
	if packed_scene == null:
		quit(1)
		return

	var scene := packed_scene.instantiate() as ScopedTargetScene
	_check(scene.auto_advance_to_broadcast, "correct target is wired to the Broadcast Interface")
	scene.auto_advance_to_broadcast = false
	root.add_child(scene)
	for _frame in 8:
		await process_frame

	scene.wrong_target_shot.connect(func(_subject_id: StringName, response: String): wrong_responses.append(response))
	scene.target_confirmed.connect(func(): target_signal_count += 1)

	_check(scene.target_actor.sprite_frames.get_frame_count(&"target_idle") == 4, "balcony target has four smoking idle frames")
	_check(scene.typist_actor.sprite_frames.get_frame_count(&"typist_idle") == 4, "typist has four working idle frames")
	_check(scene.clerk_actor.sprite_frames.get_frame_count(&"clerk_idle") == 4, "clerk has four working idle frames")
	_check(scene.employee_actor.sprite_frames.get_frame_count(&"employee_idle") == 4, "copier employee has four working idle frames")
	_check(scene.scope_mask.material is ShaderMaterial, "scope uses a moving opacity mask")
	_check(scene.wind.playing, "rooftop wind continues through the scope scene")

	_check(not scene.attempt_shot_at(Vector2(190, 390)), "typist is rejected as a non-target")
	_check(not scene.attempt_shot_at(Vector2(475, 390)), "clerk is rejected as a non-target")
	_check(not scene.attempt_shot_at(Vector2(720, 390)), "copier employee is rejected as a non-target")
	_check(wrong_responses.size() == 3, "wrong-target feedback fires for each office worker")
	_check(wrong_responses[0] == "Not this one.", "first wrong-target response is clear")
	_check(wrong_responses[1].contains("not this one either"), "second wrong-target response escalates")
	_check(wrong_responses[2].contains("want dead today"), "third wrong-target response uses the authored internal monologue")
	_check(not scene.resolved, "wrong targets do not resolve the scene")

	_check(scene.attempt_shot_at(Vector2(1025, 390)), "balcony official resolves as the correct target")
	_check(scene.resolved, "correct shot locks the scope sequence")
	_check(scene.last_shot_subject == &"target", "correct subject id is recorded")
	_check(target_signal_count == 1, "target confirmation signal fires once")
	_check(scene.feedback.text == "TARGET CONFIRMED", "correct-shot feedback is visible")
	_check(scene.shots_taken == 4 and scene.wrong_shots == 3, "shot accounting preserves failed identifications")

	scene.queue_free()
	for _frame in 4:
		await process_frame
	if failures == 0:
		print("SCOPED_TARGET_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
