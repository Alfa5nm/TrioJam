extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 loads with street atmosphere")
	if packed == null:
		quit(1)
		return
	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 5:
		await process_frame

	var player := level.get_node_or_null("Player") as Player
	_check(player != null and player.footstep_stream != null and player.footstep_stream_alt_a != null and player.footstep_stream_alt_b != null, "three pavement footstep variants are assigned")
	_check(player != null and player.footstep_stream.resource_path.contains("day1-pavement") and player.footstep_player.bus == &"SFX", "Day 1 footsteps use the pavement set on SFX")

	var atmosphere := level.get_node_or_null("Day1StreetAtmosphere") as Day1StreetAtmosphere
	var wind := atmosphere.get_node_or_null("Wind") as AudioStreamPlayer if atmosphere != null else null
	var birds := atmosphere.get_node_or_null("Birds") as AudioStreamPlayer if atmosphere != null else null
	_check(wind != null and birds != null and wind.playing and birds.playing, "wind and distant birds start with the street")
	_check(wind != null and birds != null and wind.bus == &"Ambience" and birds.bus == &"Ambience", "street layers use the Ambience bus")
	atmosphere.duck_for_cutscene()
	_check(atmosphere.is_ducked, "street ambience ducks for the camera sequence")
	atmosphere.restore_after_cutscene()
	_check(not atmosphere.is_ducked, "street ambience restores after the camera sequence")

	var leaves := level.find_children("LeafDrift*", "CPUParticles2D", true, false)
	var dust := level.find_children("DustMotes*", "CPUParticles2D", true, false)
	_check(leaves.size() == 4 and leaves.all(func(node: Node) -> bool:
		var particles := node as CPUParticles2D
		return particles != null and particles.emitting and particles.amount <= 12 and particles.emission_rect_extents.x <= 245.0
	), "four restrained, bounded leaf zones decorate visible trees")
	_check(dust.size() == 2 and dust.all(func(node: Node) -> bool:
		var particles := node as CPUParticles2D
		return particles != null and particles.emitting and particles.amount <= 14 and particles.emission_rect_extents.x <= 270.0
	), "two restrained, bounded dust-mote zones decorate the street")

	level.queue_free()
	for _frame in 3:
		await process_frame
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
