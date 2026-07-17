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
	_check(rooftop.auto_advance_to_scope, "rooftop plan is wired to the scoped target scene")
	rooftop.auto_advance_to_scope = false
	rooftop.get_node("CinematicDialogue").instant_mode = true
	rooftop.get_node("CinematicDialogue").timing_scale = 0.01
	root.add_child(rooftop)
	for _frame in 90:
		await physics_frame

	var player := rooftop.get_node("Player") as Player
	var camera := rooftop.get_node("CinematicCamera") as CinematicCamera
	var frames := player.animated_sprite.sprite_frames
	var audio_cues: Array[String] = []
	var observed_walk_frames: Array[int] = []
	var observed_execute_frames: Array[int] = []
	player.animated_sprite.frame_changed.connect(func():
		if player.animated_sprite.animation == &"walk" and player.animated_sprite.frame not in observed_walk_frames:
			observed_walk_frames.append(player.animated_sprite.frame)
		elif player.animated_sprite.animation == &"execute" and player.animated_sprite.frame not in observed_execute_frames:
			observed_execute_frames.append(player.animated_sprite.frame)
	)
	player.foley_cue_played.connect(func(cue: StringName, animation_frame: int):
		audio_cues.append("%s:%d" % [cue, animation_frame])
	)
	_check(player.is_on_floor(), "player enters through the left rooftop door")
	_check(is_equal_approx(player.move_speed, 260.0), "rooftop traversal uses the faster 260 px/s movement")
	_check(camera.target_zoom == Vector2(1.22, 1.22) and camera.zoom.distance_to(camera.target_zoom) < 0.01, "rooftop camera eases into the closer 1.22x character focus")
	var rooftop_lit_plate := rooftop.get_node("Background").texture as CanvasTexture
	_check(rooftop_lit_plate != null and rooftop_lit_plate.normal_texture != null, "rooftop plate carries a generated 2D normal texture")
	_check(is_equal_approx(player.presentation_scale, 1.15), "rooftop character receives the larger presentation scale")
	_check(player.visual.scale.x > 1.14, "larger presentation scale is applied without changing collision")
	_check(frames.get_frame_count(&"idle") == 6, "idle loop uses six registered frames")
	_check(frames.get_frame_count(&"walk") == 6, "walk loop uses six registered frames")
	_check(frames.get_frame_count(&"execute") == 8, "execute action uses eight sequential frames")
	var walk_regions: Array[Vector2] = []
	for frame_index in frames.get_frame_count(&"walk"):
		var walk_texture := frames.get_frame_texture(&"walk", frame_index) as AtlasTexture
		if walk_texture != null:
			walk_regions.append(walk_texture.region.position)
	_check(walk_regions.size() == 6 and walk_regions[0] != walk_regions[1], "walk uses renderer-safe atlas frames instead of runtime texture wrappers")
	var aim_texture := frames.get_frame_texture(&"aim", 0) as AtlasTexture
	_check(aim_texture != null and aim_texture.region.size == Vector2(512, 512), "sniper frames use a wide unclipped canvas")
	_check(aim_texture != null and aim_texture.atlas.get_width() == 4096, "execute sheet contains all eight sniper poses")
	var execute_image := aim_texture.atlas.get_image()
	for frame_index in 8:
		var frame_image := execute_image.get_region(Rect2i(frame_index * 512, 0, 512, 512))
		var used := frame_image.get_used_rect()
		_check(abs(used.size.y - 310) <= 2, "execute frame %d matches locomotion body height" % (frame_index + 1))
		_check(abs(used.end.y - 472) <= 2, "execute frame %d preserves the foot baseline" % (frame_index + 1))
	_check(player.footstep_stream != null, "rooftop concrete footstep is assigned")
	_check(player.footstep_stream_alt_a != null and player.footstep_stream_alt_b != null, "rooftop footsteps rotate through three samples")
	_check(rooftop.get_node("Audio/Wind").playing, "rooftop wind ambience loops")
	_check(rooftop.get_node("Audio/Birds").playing, "positional rooftop birds loop")
	var sheltered_wind_db: float = rooftop.get_node("Audio/Wind").volume_db
	var background := rooftop.get_node("Background") as Sprite2D
	var background_origin := Vector2.ZERO

	Input.action_press(&"move_right")
	for _frame in 275:
		await physics_frame
	Input.action_release(&"move_right")
	_check(observed_walk_frames.size() >= 5, "walk visibly advances through distinct atlas frames")
	_check(player.global_position.x > 1040.0, "player reaches the dirty footprints on the right")
	_check(rooftop.execute_available, "footprint zone enables Execute Plan")
	_check(rooftop.get_node("HUD/PlanPrompt").visible, "Execute Plan prompt is visible")
	var footstep_count := audio_cues.count("footstep:0")
	_check(footstep_count >= 4 and footstep_count <= 12, "footsteps remain restrained at the faster traversal speed")
	_check("footstep:3" not in audio_cues, "secondary walk frames no longer over-trigger footsteps")
	_check(rooftop.get_node("Audio/Wind").volume_db > sheltered_wind_db + 4.0, "wind grows from sheltered door to exposed roof")
	_check(background.position != background_origin, "rooftop camera movement produces subtle plate parallax")
	_check((background.position - background_origin).abs().x <= 8.01, "rooftop parallax stays within the zoom crop margin")

	rooftop.execute_plan()
	for _frame in 220:
		await physics_frame
	_check(rooftop.plan_executed, "Execute Plan locks after activation")
	_check(not player.controls_enabled, "player movement locks during the plan animation")
	_check(player.animated_sprite.animation == &"aim", "bag draw resolves into the final aim pose")
	_check("bag_search:1" in audio_cues, "bag search starts on execute frame one")
	_check("rifle_assembly:3" in audio_cues, "rifle assembly starts on execute frame three")
	_check(observed_execute_frames.size() >= 7, "bag handling and rifle draw visibly advance through the full sequence")
	_check(not rooftop.get_node("HUD/Completion").visible, "cinematic dialogue replaces the redundant completion card")
	_check(rooftop.get_node("CinematicDialogue").line.text == "Should I do it?", "rooftop plan ends on the authored doubt line")
	_check(rooftop.get_node("CinematicDialogue").speaker_offset.y <= -290.0, "rooftop dialogue clears the character's head")

	rooftop.queue_free()
	for _frame in 4:
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
