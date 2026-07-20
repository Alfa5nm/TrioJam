extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 loads with the occupation standoff")
	if packed == null:
		quit(1)
		return
	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 5:
		await process_frame

	var crowd := level.get_node_or_null("Day1ProtestCrowd") as Day1OccupationStandoff
	_check(crowd != null and crowd.position.distance_to(Vector2(2746, 563)) < 1.0, "standoff occupies the polished street alignment")
	var protesters: Array[Sprite2D] = []
	var soldiers: Array[Sprite2D] = []
	if crowd != null:
		for child in crowd.get_node("Protesters").get_children():
			protesters.append(child as Sprite2D)
		for child in crowd.get_node("Soldiers").get_children():
			soldiers.append(child as Sprite2D)
	_check(protesters.size() == 9, "nine occupation protesters form a crowd")
	_check(protesters.all(func(sprite: Sprite2D) -> bool:
		return sprite != null and not sprite.flip_h and sprite.texture.resource_path.contains("occupation-protester")
	), "every protester uses the supplied occupation sprites and faces right")
	_check(protesters.any(func(sprite: Sprite2D) -> bool: return sprite.position.y > -80.0), "part of the crowd stands forward on the street")
	_check(protesters.any(func(sprite: Sprite2D) -> bool: return sprite.position.y <= -80.0), "part of the crowd remains on the pavement")
	_check(soldiers.size() == 2, "two soldiers guard the right side of the standoff")
	_check(soldiers.all(func(sprite: Sprite2D) -> bool:
		return sprite != null and sprite.flip_h and sprite.texture.resource_path.contains("guard")
	), "both supplied soldiers face left toward the crowd")
	var ambience := crowd.get_node_or_null("CrowdAmbience") as AudioStreamPlayer2D if crowd != null else null
	_check(ambience != null and ambience.stream != null and ambience.playing, "angry mob ambience loops at the standoff")
	_check(ambience != null and ambience.bus == &"Ambience", "mob sound uses the Ambience bus")

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
