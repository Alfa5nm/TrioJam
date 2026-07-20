extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 loads with the Seedless rally")
	if packed == null:
		quit(1)
		return
	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 5:
		await process_frame

	var rally := level.get_node_or_null("Day1SeedlessRally") as Day1SeedlessRally
	_check(rally != null and rally.position.distance_to(Vector2(6130, 607)) < 1.0, "rally is centered on the Seedless stage")
	var left := rally.get_node("LeftProtesters").get_children() if rally != null else []
	var right := rally.get_node("RightProtesters").get_children() if rally != null else []
	_check(left.size() == 6 and right.size() == 6, "six protesters occupy each side of the stage")
	_check(left.all(func(node: Node) -> bool:
		var sprite := node as Sprite2D
		return sprite != null and sprite.texture.resource_path.contains("anti-seedless-protester")
	), "left group uses only supplied anti-Seedless sprites")
	_check(right.all(func(node: Node) -> bool:
		var sprite := node as Sprite2D
		return sprite != null and sprite.texture.resource_path.contains("anti-seedless-protester")
	), "right group uses only supplied anti-Seedless sprites")
	_check(not (left[0] as Sprite2D).flip_h and not (left[1] as Sprite2D).flip_h and (left[2] as Sprite2D).flip_h, "left group is normalized to face right")
	_check(not (right[0] as Sprite2D).flip_h and (right[1] as Sprite2D).flip_h and not (right[2] as Sprite2D).flip_h, "right group is normalized to face left")
	_check(left.all(func(node: Node) -> bool:
		var sprite := node as Sprite2D
		return not (sprite.texture.resource_path.contains("protester-b") and sprite.flip_h)
	), "left-side sign slogans are never mirrored")
	_check(right.all(func(node: Node) -> bool:
		var sprite := node as Sprite2D
		return not (sprite.texture.resource_path.contains("protester-c") and sprite.flip_h)
	), "right-side sign slogans are never mirrored")
	var left_guard := rally.get_node("Stage/LeftGuard") as Sprite2D
	var right_guard := rally.get_node("Stage/RightGuard") as Sprite2D
	var representative := rally.get_node("Stage/Representative") as Sprite2D
	_check(not left_guard.flip_h and right_guard.flip_h, "stage guards face inward toward the representative")
	_check(representative.texture.resource_path.contains("seedless-campaign-representative"), "supplied representative stands at the podium")
	_check(representative.position.distance_to(Vector2(5, -280)) < 1.0, "representative is aligned with the supplied stage artwork")
	_check(rally.get_node_or_null("Stage/PodiumForeground") == null and rally.get_node_or_null("CampaignPlacard") == null, "generated podium overlays do not obscure the supplied environment art")
	var ambience := rally.get_node("CrowdAmbience") as AudioStreamPlayer2D
	_check(ambience.stream != null and ambience.playing and ambience.bus == &"Ambience", "localized rally protest ambience is active")

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
