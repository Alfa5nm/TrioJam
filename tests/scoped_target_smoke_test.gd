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
	_check(scene.auto_advance_to_broadcast, "correct target is wired directly to the Broadcast Interface")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "16:9 gameplay is preserved in resized windows")
	scene.auto_advance_to_broadcast = false
	scene.cinematic_timing_scale = 0.01
	scene.get_node("CinematicDialogue").instant_mode = true
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
	var instructions := scene.get_node("ScopeUI/Instructions") as Label
	_check(instructions.get_global_rect().end.x <= 1280.0, "scope instructions remain inside the 16:9 safe frame")
	_check(scene.wind.playing, "rooftop wind continues through the scope scene")
	_check(scene.tension.playing, "tension ambience loops during scoped aiming")
	_check(scene.sniper_shot.stream != null and scene.glass_shatter.stream != null, "shot and glass impact cues are assigned")
	_check(scene.off_target_error.stream != null, "off-target error cue is assigned")
	_check(not scene.has_node("ScopeUI/Feedback"), "obsolete bottom scope subtitle is removed")
	_check(not scene.has_node("ScopeUI/Shots"), "scoped view omits the unnecessary shot counter")
	_check(scene.has_node("ScopeUI/Vignette") and scene.get_node("ScopeUI/Vignette").material is ShaderMaterial, "scoped view includes the cinematic edge vignette")
	var foreground := scene.get_node("ForegroundArchitecture") as Sprite2D
	var desks := scene.get_node("DeskOccluders") as Sprite2D
	var glass := scene.get_node("GlassTint") as Node2D
	_check(foreground != null and foreground.texture != null, "office foreground architecture is decomposed into its own layer")
	_check(desks != null and desks.texture != null, "desk fronts are isolated from the background plate")
	_check(desks.z_index > scene.typist_actor.z_index, "desk fronts occlude seated workers without baked furniture")
	_check(foreground.z_index > scene.target_actor.z_index, "balcony and desk fronts occlude occupants")
	_check(glass != null and glass.z_index > scene.typist_actor.z_index, "office occupants render behind the glass treatment")
	_check(scene.typist_actor.position == Vector2(180, 388), "typist is registered to the left chair and keyboard")
	_check(scene.clerk_actor.position == Vector2(500, 388), "clerk is registered to the center chair and desk")
	_check(scene.target_actor.position == Vector2(1100, 445), "target stands full-height inside the open balcony rail")

	_check(not scene.attempt_shot_at(Vector2(180, 390)), "typist is rejected as a non-target")
	_check(not scene.attempt_shot_at(Vector2(500, 390)), "clerk is rejected as a non-target")
	_check(not scene.attempt_shot_at(Vector2(760, 390)), "copier employee is rejected as a non-target")
	_check(wrong_responses.size() == 3, "wrong-target feedback fires for each office worker")
	_check(wrong_responses == ["No, not this one.", "ARGGH... not this one either.", "Not the one I want dead today."], "wrong occupants receive the revised three-line rejection cycle")
	_check(scene.off_target_error.playing, "wrong occupant plays the off-target error cue")
	_check(not scene.resolved, "wrong targets do not resolve the scene")
	var errors_before_empty := scene.off_target_error.get_playback_position()
	_check(not scene.attempt_shot_at(Vector2(20, 690)), "empty space does not resolve the scene")
	_check(scene.dialogue.line.text == "Not the one I want dead today.", "empty-space clicks add no dialogue outside the revised script")
	_check(scene.wrong_shots == 3, "empty-space clicks do not count as wrong occupants")
	_check(scene.off_target_error.get_playback_position() >= errors_before_empty, "empty-space click does not restart the error cue")

	_check(scene.attempt_shot_at(Vector2(1100, 420)), "balcony official resolves as the correct target")
	_check(scene.resolved, "correct shot locks the scope sequence")
	_check(scene.last_shot_subject == &"target", "correct subject id is recorded")
	_check(target_signal_count == 1, "target confirmation signal fires once")
	_check(scene.reticle.confirmed, "correct-shot confirmation remains visible through the reticle")
	_check(scene.shots_taken == 5 and scene.wrong_shots == 3, "shot accounting distinguishes empty space from failed identifications")
	await scene.resolution_sequence_finished
	_check(scene.dialogue.line.text == "I’m doing the right thing.", "correct target resolves with the revised commitment line")
	_check(scene.sniper_shot.playing, "sniper report is synchronized after the commitment line")
	_check(scene.glass_shatter.playing, "glass impact follows the rifle report")
	_check(scene.fade.modulate.a > 0.95, "correct shot resolves to black before the desk transition")

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
